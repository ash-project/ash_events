defmodule AshEvents.EventResource.Actions.Replay do
  require Ash.Query
  require Logger

  defp create!(resource, action, input, opts) do
    resource
    |> Ash.Changeset.for_create(action, input, opts)
    |> Ash.create!(opts)

    :ok
  end

  defp update!(resource, id, action, input, event_id, opts) do
    case Ash.get(resource, id, opts) do
      {:ok, record} ->
        record
        |> Ash.Changeset.for_update(action, input |> Map.drop([:id]), opts)
        |> Ash.update!(opts)

        :ok

      _ ->
        Logger.warning("Record #{id} not found when processing update event #{event_id}")
    end
  end

  defp destroy!(resource, id, action, event_id, opts) do
    case Ash.get(resource, id, opts) do
      {:ok, record} ->
        record
        |> Ash.Changeset.for_destroy(action, %{}, opts)
        |> Ash.destroy!(opts)

        :ok

      _ ->
        Logger.warning("Record #{id} not found when processing destroy event #{event_id}")
    end
  end

  defp handle_action(:create, resource, action, input, _record_id, _event_id, opts) do
    create!(resource, action, input, opts)
  end

  defp handle_action(:update, resource, action, input, record_id, event_id, opts) do
    update!(resource, record_id, action, input, event_id, opts)
  end

  defp handle_action(:destroy, resource, action, _input, record_id, event_id, opts) do
    destroy!(resource, record_id, action, event_id, opts)
  end

  def run(input, run_opts, ctx) do
    opts = Ash.Context.to_opts(ctx)

    overrides = run_opts[:overrides]

    last_event_id = input.arguments[:last_event_id]

    if last_event_id do
      input.resource
      |> Ash.Query.filter(id <= ^last_event_id)
    else
      input.resource
    end
    |> Ash.stream!(opts)
    |> Stream.map(fn event ->
      input = Map.put(event.data, :id, event.record_id)

      override =
        Enum.find(overrides, fn
          %{event_resource: resource, event_action: action, versions: versions} ->
            event.ash_events_resource == resource and
              event.ash_events_action == action and
              event.version in versions
        end)

      if override do
        Enum.each(override.route_to, fn route_to ->
          handle_action(
            event.ash_events_action_type,
            route_to.resource,
            route_to.action,
            input,
            event.record_id,
            event.id,
            opts
          )
        end)
      else
        handle_action(
          event.ash_events_action_type,
          event.ash_events_resource,
          event.ash_events_action,
          input,
          event.record_id,
          event.id,
          opts
        )
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
