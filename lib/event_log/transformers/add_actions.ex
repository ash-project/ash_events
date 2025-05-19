defmodule AshEvents.EventLog.Transformers.AddActions do
  @moduledoc false
  use Spark.Dsl.Transformer

  def transform(dsl) do
    replay_overrides = AshEvents.EventLog.Info.replay_overrides(dsl)
    primary_key = AshEvents.EventLog.Info.event_log_primary_key_type!(dsl)

    persist_actor_primary_keys =
      AshEvents.EventLog.Info.event_log(dsl)
      |> Enum.map(& &1.name)

    dsl
    |> Ash.Resource.Builder.add_action(:create, :create,
      accept:
        Enum.uniq(
          [
            :version,
            :data,
            :metadata,
            :record_id,
            :resource,
            :action,
            :action_type
          ] ++ persist_actor_primary_keys
        )
    )
    |> Ash.Resource.Builder.add_action(:action, :replay,
      arguments: [
        Ash.Resource.Builder.build_action_argument(:last_event_id, primary_key,
          allow_nil?: true,
          description: "Replay events up to and including this event id."
        ),
        Ash.Resource.Builder.build_action_argument(:point_in_time, :utc_datetime_usec,
          allow_nil?: true,
          description: "Replay events up to and including this point in time."
        )
      ],
      run: {AshEvents.EventLog.Actions.Replay, [overrides: replay_overrides]}
    )
  end
end
