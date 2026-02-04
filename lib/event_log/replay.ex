# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
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

  defp prepare_replay_input(event, resource, action_name) do
    changed_attributes = Map.get(event, :changed_attributes, %{})
    replay_strategy = get_replay_strategy(resource, action_name)
    action = Ash.Resource.Info.action(resource, action_name)

    raw_input =
      case replay_strategy do
        :as_arguments ->
          Map.merge(event.data, changed_attributes)

        :force_change ->
          event.data
      end

    # replay_overrides may route events to resources with different schemas
    filter_input_for_action(raw_input, resource, action)
  end

  defp filter_input_for_action(input, resource, action) do
    accepted_attr_names = MapSet.new(action.accept)
    argument_names = action.arguments |> Enum.map(& &1.name) |> MapSet.new()
    valid_keys = MapSet.union(accepted_attr_names, argument_names)

    resource_attr_names =
      resource |> Ash.Resource.Info.attributes() |> Enum.map(& &1.name) |> MapSet.new()

    all_known_names = MapSet.union(resource_attr_names, argument_names)

    Map.filter(input, fn {key, _value} ->
      key_atom =
        cond do
          is_atom(key) ->
            key

          is_binary(key) ->
            try do
              atom = String.to_existing_atom(key)
              if MapSet.member?(all_known_names, atom), do: atom, else: nil
            rescue
              ArgumentError -> nil
            end

          true ->
            nil
        end

      key_atom != nil and MapSet.member?(valid_keys, key_atom)
    end)
  end

  defp prepare_replay_context(event, resource) do
    changed_attributes = Map.get(event, :changed_attributes, %{})

    # Backward compatibility: older/manual events may not have primary key in changed_attributes
    [primary_key] = Ash.Resource.Info.primary_key(resource)
    pk_string_key = to_string(primary_key)

    changed_attributes =
      if Map.has_key?(changed_attributes, primary_key) or
           Map.has_key?(changed_attributes, pk_string_key) do
        changed_attributes
      else
        Map.put(changed_attributes, pk_string_key, event.record_id)
      end

    %{
      ash_events_replay?: true,
      changed_attributes: changed_attributes
    }
  end

  defp get_record_if_exists(resource, record_id, opts) do
    case Ash.get(resource, record_id, opts) do
      {:ok, record} -> {:ok, record}
      {:error, _} -> {:error, :not_found}
    end
  end

  defp replay_as_create(event, resource, action, opts) do
    action_name = if is_atom(action), do: action, else: action.name

    input = prepare_replay_input(event, resource, action_name)
    context = prepare_replay_context(event, resource)
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
    context = prepare_replay_context(event, resource)
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
        context = prepare_replay_context(event, resource)
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
        context = prepare_replay_context(event, resource)
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
