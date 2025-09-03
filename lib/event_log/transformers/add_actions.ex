defmodule AshEvents.EventLog.Transformers.AddActions do
  @moduledoc false
  use Spark.Dsl.Transformer

  def transform(dsl) do
    replay_overrides = AshEvents.EventLog.Info.replay_overrides(dsl)
    primary_key = AshEvents.EventLog.Info.event_log_primary_key_type!(dsl)

    persist_actor_primary_keys =
      AshEvents.EventLog.Info.event_log(dsl)
      |> Enum.map(& &1.name)

    cloak_vault =
      case AshEvents.EventLog.Info.event_log_cloak_vault(dsl) do
        :error -> nil
        {:ok, vault} -> vault
      end

    create_accepts =
      if cloak_vault do
        [
          :version,
          :record_id,
          :resource,
          :action,
          :action_type,
          :occurred_at
        ]
      else
        [
          :version,
          :data,
          :metadata,
          :record_id,
          :resource,
          :action,
          :action_type,
          :occurred_at
        ]
      end

    create_arguments =
      if cloak_vault do
        [
          Ash.Resource.Builder.build_action_argument(:metadata, :map,
            allow_nil?: false,
            default: %{},
            description: "Any relevant metadata you want to store with the event."
          ),
          Ash.Resource.Builder.build_action_argument(:data, :map,
            allow_nil?: false,
            default: %{},
            description: "This is where the action params (attrs & args) are stored."
          )
        ]
      else
        []
      end

    create_changes =
      if cloak_vault do
        [
          %Ash.Resource.Change{
            change: {AshEvents.EventLog.Changes.Encrypt, cloak_vault: cloak_vault},
            on: nil,
            only_when_valid?: false,
            description: nil,
            always_atomic?: false,
            where: []
          }
        ]
      else
        []
      end

    dsl
    |> Ash.Resource.Builder.add_action(:create, :create,
      accept: Enum.uniq(create_accepts ++ persist_actor_primary_keys),
      arguments: create_arguments,
      changes: create_changes
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
