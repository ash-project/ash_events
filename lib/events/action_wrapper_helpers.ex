# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Events.ActionWrapperHelpers do
  @moduledoc """
  Helper functions used by the action wrappers.
  """

  defp should_store_sensitive_attribute?(attribute_name, resource, event_log_resource) do
    cloaked? = AshEvents.EventLog.Info.cloaked?(event_log_resource)
    store_list = AshEvents.Events.Info.events_store_sensitive_attributes!(resource)

    cloaked? or Enum.member?(store_list, attribute_name)
  end

  def dump_value(nil, _attribute), do: {nil, nil}

  def dump_value(values, %{type: {:array, attr_type}} = attribute) do
    item_constraints = attribute.constraints[:items]

    {dumped_values, encoding} =
      Enum.map_reduce(values, nil, fn value, _acc ->
        if attr_type == Ash.Type.Binary and is_binary(value) do
          {Base.encode64(value), "base64"}
        else
          {:ok, dumped_value} = Ash.Type.dump_to_embedded(attr_type, value, item_constraints)
          {dumped_value, nil}
        end
      end)

    {dumped_values, encoding}
  end

  def dump_value(value, attribute) do
    if attribute.type == Ash.Type.Binary and is_binary(value) do
      {Base.encode64(value), "base64"}
    else
      {:ok, dumped_value} =
        Ash.Type.dump_to_embedded(attribute.type, value, attribute.constraints)

      {dumped_value, nil}
    end
  end

  def get_occurred_at(changeset, timestamp_attr) do
    case Ash.Changeset.get_attribute(changeset, timestamp_attr) do
      nil ->
        DateTime.utc_now()

      timestamp ->
        timestamp
    end
  end

  defp cast_and_dump_value(value, attr_or_arg) do
    case Ash.Type.cast_input(attr_or_arg.type, value, attr_or_arg.constraints) do
      {:ok, cast_value} ->
        dump_value(cast_value, attr_or_arg)

      {:error, _} ->
        dump_value(value, attr_or_arg)
    end
  end

  def create_event!(changeset, original_params, occurred_at, module_opts, opts) do
    pg_repo = AshPostgres.DataLayer.Info.repo(changeset.resource)

    if pg_repo do
      lock_key =
        module_opts[:advisory_lock_key_generator].generate_key!(
          changeset,
          module_opts[:advisory_lock_key_default]
        )

      case Code.ensure_loaded(Ecto.Adapters.SQL) do
        {:module, _} ->
          if is_list(lock_key) do
            [key1, key2] = lock_key
            Ecto.Adapters.SQL.query(pg_repo, "SELECT pg_advisory_xact_lock($1, $2)", [key1, key2])
          else
            Ecto.Adapters.SQL.query(pg_repo, "SELECT pg_advisory_xact_lock($1)", [lock_key])
          end

        {:error, _} ->
          raise "Ecto.Adapters.SQL not available when trying to set advisory lock"
      end
    end

    event_log_resource = module_opts[:event_log]

    {params, data_field_encoders} =
      original_params
      |> Enum.reduce({%{}, %{}}, fn {key, value}, {params_acc, encoders_acc} ->
        key =
          if is_binary(key) do
            try do
              String.to_existing_atom(key)
            rescue
              ArgumentError -> nil
            end
          else
            key
          end

        cond do
          attr = Ash.Resource.Info.attribute(changeset.resource, key) ->
            if not attr.sensitive? or
                 should_store_sensitive_attribute?(key, changeset.resource, event_log_resource) do
              {dumped_value, encoding} = cast_and_dump_value(value, attr)

              new_encoders_acc =
                if encoding, do: Map.put(encoders_acc, key, encoding), else: encoders_acc

              {Map.put(params_acc, key, dumped_value), new_encoders_acc}
            else
              {Map.put(params_acc, key, nil), encoders_acc}
            end

          arg = Enum.find(changeset.action.arguments, &(&1.name == key)) ->
            if not arg.sensitive? or
                 should_store_sensitive_attribute?(key, changeset.resource, event_log_resource) do
              {dumped_value, encoding} = cast_and_dump_value(value, arg)

              new_encoders_acc =
                if encoding, do: Map.put(encoders_acc, key, encoding), else: encoders_acc

              {Map.put(params_acc, key, dumped_value), new_encoders_acc}
            else
              {Map.put(params_acc, key, nil), encoders_acc}
            end

          true ->
            {params_acc, encoders_acc}
        end
      end)

    [primary_key] = Ash.Resource.Info.primary_key(changeset.resource)
    persist_actor_primary_keys = AshEvents.EventLog.Info.event_log(event_log_resource)
    actor = opts[:actor]

    record_id =
      if changeset.action_type == :create do
        Map.get(changeset.attributes, primary_key)
      else
        Map.get(changeset.data, primary_key)
      end

    metadata = Map.get(changeset.context, :ash_events_metadata, %{})

    # Calculate changed attributes from the final changeset state
    original_params = Map.get(changeset.context, :original_params, %{})
    original_param_keys = MapSet.new(Map.keys(original_params))

    {changed_attributes, changed_attributes_field_encoders} =
      Enum.reduce(changeset.attributes, {%{}, %{}}, fn {attr_name, value},
                                                       {attrs_acc, encoders_acc} ->
        if MapSet.member?(original_param_keys, attr_name) or
             MapSet.member?(original_param_keys, to_string(attr_name)) do
          {attrs_acc, encoders_acc}
        else
          case Ash.Resource.Info.attribute(changeset.resource, attr_name) do
            nil ->
              {attrs_acc, encoders_acc}

            attr ->
              if not attr.sensitive? or
                   should_store_sensitive_attribute?(
                     attr_name,
                     changeset.resource,
                     event_log_resource
                   ) do
                {dumped_value, encoding} = dump_value(value, attr)

                new_encoders_acc =
                  if encoding, do: Map.put(encoders_acc, attr_name, encoding), else: encoders_acc

                {Map.put(attrs_acc, attr_name, dumped_value), new_encoders_acc}
              else
                {Map.put(attrs_acc, attr_name, nil), encoders_acc}
              end
          end
        end
      end)

    event_params =
      %{
        data: params,
        record_id: record_id,
        resource: changeset.resource,
        action: module_opts[:action],
        action_type: changeset.action_type,
        metadata: metadata,
        version: module_opts[:version],
        occurred_at: occurred_at,
        changed_attributes: changed_attributes,
        data_field_encoders: data_field_encoders,
        changed_attributes_field_encoders: changed_attributes_field_encoders
      }

    event_params =
      Enum.reduce(persist_actor_primary_keys, event_params, fn persist_actor_primary_key, input ->
        if is_struct(actor) and actor.__struct__ == persist_actor_primary_key.destination do
          primary_key = Map.get(actor, hd(Ash.Resource.Info.primary_key(actor.__struct__)))
          Map.put(input, persist_actor_primary_key.name, primary_key)
        else
          input
        end
      end)

    has_atomics? = not Enum.empty?(changeset.atomics)

    event_log_resource
    |> Ash.Changeset.for_create(:create, event_params, opts ++ [authorize?: false])
    |> then(fn cs ->
      if has_atomics? do
        Ash.Changeset.add_error(
          cs,
          Ash.Error.Changes.InvalidChanges.exception(
            message: "atomic changes are not compatible with ash_events"
          )
        )
      else
        cs
      end
    end)
    |> Ash.create!(authorize?: false, return_notifications?: true)
  end
end
