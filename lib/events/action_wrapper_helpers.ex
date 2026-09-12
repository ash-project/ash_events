# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Events.ActionWrapperHelpers do
  @moduledoc """
  Helper functions used by the action wrappers.
  """

  @doc """
  Reverses `dump_to_embedded` for a single attribute value.

  Used during replay to convert stored values (e.g., base64-encoded binaries)
  back to their original types before passing them as action input.
  """
  def cast_from_embedded(nil, _attribute), do: nil

  def cast_from_embedded(value, attribute) do
    if embedded_type?(attribute.type) do
      # Embedded resources are stored as partial maps and should be passed
      # through as-is — cast_input handles them correctly during replay.
      value
    else
      case Ash.Type.cast_from_embedded(attribute.type, value, attribute.constraints) do
        {:ok, restored} -> restored
        _ -> value
      end
    end
  end

  defp embedded_type?({:array, type}), do: embedded_type?(type)

  defp embedded_type?(type) do
    type = Ash.Type.get_type(type)
    is_atom(type) and type.embedded?()
  end

  def dump_value(nil, _attribute), do: nil

  def dump_value(values, %{type: {:array, attr_type}} = attribute) do
    item_constraints = attribute.constraints[:items]

    # This is a work around for a bug in Ash.Type.dump_to_embedded/3
    Enum.map(values, fn value ->
      {:ok, dumped_value} = Ash.Type.dump_to_embedded(attr_type, value, item_constraints)
      dumped_value
    end)
  end

  def dump_value(value, attribute) do
    {:ok, dumped_value} = Ash.Type.dump_to_embedded(attribute.type, value, attribute.constraints)
    dumped_value
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
      {:ok, cast_value} -> dump_value(cast_value, attr_or_arg)
      {:error, _} -> dump_value(value, attr_or_arg)
    end
  end

  @doc """
  Writes the event for `changeset` and returns the notifications it produced.

  The event is created with `return_notifications?: true`, which makes Ash hand
  the notifications back instead of dispatching them. Callers must therefore
  pass them on to Ash in the shape their action type expects, or notifiers on
  the event log resource never fire.
  """
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
          # `query!` so a failed lock acquisition (deadlock victim, lock_timeout)
          # surfaces with its real error code. Discarding the result leaves the
          # transaction aborted and the event insert below fails with a
          # misleading 25P02 instead.
          if is_list(lock_key) do
            [key1, key2] = lock_key

            Ecto.Adapters.SQL.query!(pg_repo, "SELECT pg_advisory_xact_lock($1, $2)", [key1, key2])
          else
            Ecto.Adapters.SQL.query!(pg_repo, "SELECT pg_advisory_xact_lock($1)", [lock_key])
          end

        {:error, _} ->
          raise "Ecto.Adapters.SQL not available when trying to set advisory lock"
      end
    end

    event_log_resource = module_opts[:event_log]

    params =
      original_params
      |> Enum.reduce(%{}, fn {key, value}, acc ->
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
            if not attr.sensitive? or AshEvents.EventLog.Info.cloaked?(event_log_resource) do
              Map.put(acc, key, cast_and_dump_value(value, attr))
            else
              Map.put(acc, key, nil)
            end

          arg = Enum.find(changeset.action.arguments, &(&1.name == key)) ->
            if not arg.sensitive? or AshEvents.EventLog.Info.cloaked?(event_log_resource) do
              Map.put(acc, key, cast_and_dump_value(value, arg))
            else
              Map.put(acc, key, nil)
            end

          true ->
            acc
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

    # belongs_to FK attributes must always be captured in changed_attributes,
    # even when their name matches an original param key (e.g., argument :user_id
    # and FK attribute :user_id). During replay, managed relationships are skipped
    # entirely, so the FK must come from changed_attributes.
    belongs_to_fk_attrs =
      changeset.resource
      |> Ash.Resource.Info.relationships()
      |> Enum.filter(&(&1.type == :belongs_to))
      |> Enum.map(& &1.source_attribute)
      |> MapSet.new()

    changed_attributes =
      Enum.reduce(changeset.attributes, %{}, fn {attr_name, value}, acc ->
        is_belongs_to_fk = MapSet.member?(belongs_to_fk_attrs, attr_name)

        if not is_belongs_to_fk and
             (MapSet.member?(original_param_keys, attr_name) or
                MapSet.member?(original_param_keys, to_string(attr_name))) do
          acc
        else
          case Ash.Resource.Info.attribute(changeset.resource, attr_name) do
            nil -> acc
            attr -> Map.put(acc, attr_name, dump_value(value, attr))
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
        changed_attributes: changed_attributes
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
        Ash.Changeset.add_error(cs, atomics_error())
      else
        cs
      end
    end)
    |> Ash.create!(authorize?: false, return_notifications?: true)
    |> then(fn {_event, notifications} -> notifications end)
  end

  @doc """
  Wraps `notifications` in the shape the enclosing action pipeline expects.

  Ash is not consistent here, so the shape cannot be hardcoded:

    * the single-record create/update pipelines require
      `%{notifications: [...]}` (see `validate_manual_action_return_result!/3`
      in `Ash.Actions.Create`/`Ash.Actions.Update`), while
    * the bulk pipelines hand the third element of `{:ok, record, _}` straight
      to `Ash.Actions.Helpers.Bulk.store_notification/3`, which treats anything
      that is not a list as a single notification.

  A changeset built by a bulk action carries a `:bulk_create`/`:bulk_update`/
  `:bulk_destroy` context key, which is what tells the two apart.

  Hard destroys do not use this: their single-record pipeline cannot carry
  notifications at all. See `destroy_result/3` in
  `AshEvents.DestroyActionWrapper`.
  """
  def notifications_result(changeset, record, notifications) do
    if bulk_changeset?(changeset) do
      {:ok, record, notifications}
    else
      {:ok, record, %{notifications: notifications}}
    end
  end

  @doc """
  Whether `changeset` was built by a bulk action.

  Bulk actions tag their changesets with a `:bulk_create`/`:bulk_update`/
  `:bulk_destroy` context key, which is the only way to tell which of Ash's two
  incompatible manual-action result shapes the caller wants.
  """
  def bulk_changeset?(%{context: context}) do
    Enum.any?([:bulk_create, :bulk_update, :bulk_destroy], &Map.has_key?(context, &1))
  end

  @doc """
  The error returned when an event-tracked action carries atomic changes, which
  cannot be recorded in an event.
  """
  def atomics_error do
    Ash.Error.Changes.InvalidChanges.exception(
      message: "atomic changes are not compatible with ash_events"
    )
  end
end
