defmodule AshEvents.EventLog.Actions.Replay do
  @moduledoc """
  Action module used by the event log resource to replay events.
  """
  require Ash.Query
  require Logger

  # Helper function to safely check if a record exists
  defp get_record_if_exists(resource, record_id, opts) do
    case Ash.get(resource, record_id, opts) do
      {:ok, record} -> {:ok, record}
      {:error, _} -> {:error, :not_found}
    end
  end

  # Extract current create event replay logic into helper function
  defp replay_as_create(event, resource, action, opts) do
    create_timestamp = AshEvents.Events.Info.events_create_timestamp!(event.resource)
    update_timestamp = AshEvents.Events.Info.events_update_timestamp!(event.resource)

    input = Map.put(event.data, :id, event.record_id)

    input =
      if create_timestamp do
        Map.put(input, create_timestamp, event.occurred_at)
      else
        input
      end

    input =
      if update_timestamp do
        Map.put(input, update_timestamp, event.occurred_at)
      else
        input
      end

    resource
    |> Ash.Changeset.for_create(action, input, opts)
    |> Ash.create!()

    :ok
  end

  # Helper function to replay upsert events as updates when record already exists
  defp replay_upsert_as_update(event, resource, existing_record, opts) do
    # For upsert actions, we MUST have the auto-generated replay update action
    replay_action_name = :"ash_events_replay_#{event.action}_update"
    actions = Ash.Resource.Info.actions(resource)

    update_action =
      case Enum.find(actions, &(&1.name == replay_action_name and &1.type == :update)) do
        nil ->
          raise "Expected auto-generated replay update action #{replay_action_name} for upsert action #{event.action} on #{resource}, but it was not found. This indicates a bug in the AshEvents transformer."

        action ->
          action
      end

    update_timestamp = AshEvents.Events.Info.events_update_timestamp!(event.resource)

    input =
      if update_timestamp do
        Map.put(event.data, update_timestamp, event.occurred_at)
      else
        event.data
      end

    existing_record
    |> Ash.Changeset.for_update(update_action.name, input, opts)
    |> Ash.update!()

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
        update_timestamp = AshEvents.Events.Info.events_update_timestamp!(resource)

        input =
          if update_timestamp do
            Map.put(event.data, update_timestamp, event.occurred_at)
          else
            event.data
          end

        record
        |> Ash.Changeset.for_update(action, input, opts)
        |> Ash.update!()

        :ok

      _ ->
        Logger.warning(
          "Record #{event.record_id} not found when processing update event #{event.id}"
        )
    end
  end

  defp handle_action(%{action_type: :destroy} = event, resource, action, opts) do
    case Ash.get(resource, event.id, opts) do
      {:ok, record} ->
        record
        |> Ash.Changeset.for_destroy(action, %{}, opts)
        |> Ash.destroy!()

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
        do: Ash.Query.load(query, [:data, :metadata]),
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
