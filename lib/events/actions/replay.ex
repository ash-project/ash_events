defmodule AshEvents.EventResource.Actions.Replay do
  require Ash.Query

  def run(input, run_opts, ctx) do
    opts = Ash.Context.to_opts(ctx)

    overrides = run_opts[:overrides]

    input.resource
    |> Ash.stream!(opts)
    |> Stream.map(fn event ->
      input = Map.put(event.data, :id, event.entity_id)

      override =
        Enum.find(overrides, fn
          %{event_resource: resource, event_action: action, version_prefix: prefix} ->
            event.ash_events_resource == resource and
              event.ash_events_action == action and
              String.starts_with?(event.version, prefix)
        end)

      if override do
        Enum.each(override.route_to, fn route_to ->
          route_to.resource
          |> Ash.Changeset.for_create(route_to.action, input, opts)
          |> Ash.create!()
        end)
      else
        event.ash_events_resource
        |> Ash.Changeset.for_create(event.ash_events_action, input, opts)
        |> Ash.create!()
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
