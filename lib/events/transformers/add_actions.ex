defmodule AshEvents.EventResource.Transformers.AddActions do
  @moduledoc false
  use Spark.Dsl.Transformer

  @add_destroy? Application.compile_env(:ash_events, :add_event_resource_destroy?) || false

  def transform(dsl) do
    {:ok, extra_create_accepts} = AshEvents.EventResource.Info.event_resource_create_accept(dsl)

    replay_overrides = AshEvents.EventResource.Info.replay_overrides(dsl)

    dsl
    |> Ash.Resource.Builder.add_action(:create, :create,
      accept:
        Enum.uniq(
          [
            :version,
            :data,
            :metadata,
            :record_id,
            :ash_events_resource,
            :ash_events_action,
            :ash_events_action_type
          ] ++ extra_create_accepts
        )
    )
    |> Ash.Resource.Builder.add_action(:action, :replay,
      arguments: [
        %Ash.Resource.Actions.Argument{
          name: :last_event_id,
          allow_nil?: true,
          type: :integer,
          description: "Replay events up to and including this event id."
        }
      ],
      run: {AshEvents.EventResource.Actions.Replay, [overrides: replay_overrides]}
    )
    |> then(fn result ->
      if @add_destroy? do
        result
        |> Ash.Resource.Builder.add_action(:destroy, :destroy, primary?: true)
      else
        result
      end
    end)
  end
end
