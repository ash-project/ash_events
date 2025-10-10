# SPDX-FileCopyrightText: 2024 Torkild G. Kjevik
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EventLog.Actions.Replay do
  @moduledoc """
  Action module used by the event log resource to replay events.
  """
  require Ash.Query
  require Logger

  defp get_replay_strategy(resource, action_name) do
    replay_config = AshEvents.Events.Info.events_replay_non_input_attribute_changes!(resource)
    Keyword.get(replay_config, action_name, :force_change)
  end

  defp decode_values_with_encoders(data, encoders) when is_map(data) and is_map(encoders) do
    Enum.reduce(data, %{}, fn {key, value}, acc ->
      case Map.get(encoders, key) do
        "base64" when is_binary(value) ->
          case Base.decode64(value) do
            {:ok, decoded} -> Map.put(acc, key, decoded)
            :error -> raise "Invalid Base64 data for key #{key}"
          end

        "base64" when is_list(value) ->
          decoded_array =
            Enum.map(value, fn item ->
              case Base.decode64(item) do
                {:ok, decoded} -> decoded
                :error -> raise "Invalid Base64 data in array for key #{key}"
              end
            end)

          Map.put(acc, key, decoded_array)

        _ ->
          Map.put(acc, key, value)
      end
    end)
  end

  defp decode_values_with_encoders(data, _encoders), do: data

  defp prepare_replay_input(event, resource, action_name) do
    changed_attributes = Map.get(event, :changed_attributes, %{})
    replay_strategy = get_replay_strategy(resource, action_name)

    data_encoders = Map.get(event, :data_field_encoders, %{})
    changed_attributes_encoders = Map.get(event, :changed_attributes_field_encoders, %{})

    decoded_data = decode_values_with_encoders(event.data, data_encoders)

    decoded_changed_attributes =
      decode_values_with_encoders(changed_attributes, changed_attributes_encoders)

    case replay_strategy do
      :as_arguments ->
        Map.merge(decoded_data, decoded_changed_attributes)

      :force_change ->
        decoded_data
    end
  end

  defp prepare_replay_context(event) do
    changed_attributes = Map.get(event, :changed_attributes, %{})
    changed_attributes_encoders = Map.get(event, :changed_attributes_field_encoders, %{})

    # Decode the changed_attributes using encoding metadata
    decoded_changed_attributes =
      decode_values_with_encoders(changed_attributes, changed_attributes_encoders)

    %{
      ash_events_replay?: true,
      changed_attributes: decoded_changed_attributes
    }
  end

  defp get_record_if_exists(resource, record_id, opts) do
    case Ash.get(resource, record_id, opts) do
      {:ok, record} -> {:ok, record}
      {:error, _} -> {:error, :not_found}
    end
  end

  defp replay_as_create(event, resource, action, opts) do
    [primary_key] = Ash.Resource.Info.primary_key(resource)
    action_name = if is_atom(action), do: action, else: action.name

    input =
      prepare_replay_input(event, resource, action_name)
      |> Map.put(primary_key, event.record_id)

    context = prepare_replay_context(event)
    merged_context = Map.merge(opts[:context] || %{}, context)
    updated_opts = Keyword.put(opts, :context, merged_context)
    changeset = Ash.Changeset.for_create(resource, action, input, updated_opts)
    Ash.create!(changeset)

    :ok
  end

  defp replay_upsert_as_update(event, resource, existing_record, opts) do
    replay_action_name = String.to_existing_atom("ash_events_replay_#{event.action}_update")
    actions = Ash.Resource.Info.actions(resource)

    update_action =
      case Enum.find(actions, &(&1.name == replay_action_name and &1.type == :update)) do
        nil ->
          raise "Expected auto-generated replay update action #{replay_action_name} for upsert action #{event.action} on #{resource}, but it was not found. This indicates a bug in the AshEvents transformer."

        action ->
          action
      end

    input = prepare_replay_input(event, resource, event.action)
    context = prepare_replay_context(event)
    merged_context = Map.merge(opts[:context] || %{}, context)
    updated_opts = Keyword.put(opts, :context, merged_context)

    changeset = Ash.Changeset.for_update(existing_record, update_action.name, input, updated_opts)

    Ash.update!(changeset)

    :ok
  end

  defp handle_action(%{action_type: :create} = event, resource, action, opts) do
    action_struct = Ash.Resource.Info.action(resource, action)

    if action_struct.upsert? do
      case get_record_if_exists(resource, event.record_id, opts) do
        {:ok, existing_record} ->
          replay_upsert_as_update(event, resource, existing_record, opts)

        {:error, :not_found} ->
          replay_as_create(event, resource, action, opts)
      end
    else
      replay_as_create(event, resource, action_struct, opts)
    end
  end

  defp handle_action(%{action_type: :update} = event, resource, action, opts) do
    case Ash.get(resource, event.record_id, opts) do
      {:ok, record} ->
        input = prepare_replay_input(event, resource, action)
        context = prepare_replay_context(event)
        merged_context = Map.merge(opts[:context] || %{}, context)
        updated_opts = Keyword.put(opts, :context, merged_context)
        changeset = Ash.Changeset.for_update(record, action, input, updated_opts)
        Ash.update!(changeset)

        :ok

      _ ->
        Logger.warning(
          "Record #{event.record_id} not found when processing update event #{event.id}"
        )
    end
  end

  defp handle_action(%{action_type: :destroy} = event, resource, action, opts) do
    case Ash.get(resource, event.record_id, opts) do
      {:ok, record} ->
        context = prepare_replay_context(event)
        merged_context = Map.merge(opts[:context] || %{}, context)
        updated_opts = Keyword.put(opts, :context, merged_context)
        changeset = Ash.Changeset.for_destroy(record, action, %{}, updated_opts)
        Ash.destroy!(changeset)

        :ok

      _ ->
        Logger.warning(
          "Record #{event.record_id} not found when processing destroy event #{event.id}"
        )
    end
  end

  def run(input, run_opts, ctx) do
    opts =
      Ash.Context.to_opts(ctx,
        authorize?: false
      )

    ctx = Map.put(opts[:context] || %{}, :ash_events_replay?, true)
    opts = Keyword.replace(opts, :context, ctx)

    case AshEvents.EventLog.Info.event_log_clear_records_for_replay(input.resource) do
      {:ok, module} ->
        module.clear_records!(opts)

      :error ->
        raise "clear_records_for_replay must be specified on #{input.resource} when doing a replay."
    end

    cloak_vault =
      case AshEvents.EventLog.Info.event_log_cloak_vault(input.resource) do
        {:ok, vault} -> vault
        :error -> nil
      end

    overrides = run_opts[:overrides]
    point_in_time = input.arguments[:point_in_time]
    last_event_id = input.arguments[:last_event_id]

    cond do
      last_event_id != nil ->
        input.resource
        |> Ash.Query.filter(id <= ^last_event_id)

      point_in_time != nil ->
        input.resource
        |> Ash.Query.filter(occurred_at <= ^point_in_time)

      true ->
        input.resource
    end
    |> Ash.Query.sort(id: :asc)
    |> then(fn query ->
      if cloak_vault,
        do: Ash.Query.load(query, [:data, :metadata, :changed_attributes]),
        else: query
    end)
    |> Ash.stream!(opts)
    |> Stream.map(fn event ->
      override =
        Enum.find(overrides, fn
          %{event_resource: event_resource, event_action: event_action, versions: versions} ->
            event.resource == event_resource and
              event.action == event_action and
              event.version in versions
        end)

      if override do
        Enum.each(override.route_to, fn route_to ->
          handle_action(event, route_to.resource, route_to.action, opts)
        end)
      else
        handle_action(event, event.resource, event.action, opts)
      end
    end)
    |> Stream.take_while(fn
      :ok -> true
      _res -> false
    end)
    |> Enum.reduce_while(:ok, fn
      :ok, _acc -> {:cont, :ok}
      error, _acc -> {:halt, error}
    end)
  end
end
