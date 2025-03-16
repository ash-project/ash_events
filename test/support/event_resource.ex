defmodule AshEvents.Test.Events.EventResource do
  use Ash.Resource,
    domain: AshEvents.Test.Events,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.EventResource]

  postgres do
    table "events"
    repo AshEvents.TestRepo
  end

  event_resource do
    clear_records_for_replay AshEvents.Test.ClearRecords
    persist_actor_id :user_id, AshEvents.Test.Accounts.User
    persist_actor_id :system_actor, AshEvents.Test.Events.SystemActor, attribute_type: :string
  end

  replay_overrides do
    replay_override AshEvents.Test.Accounts.User, :create_ash_events_impl do
      versions([1])
      route_to AshEvents.Test.Accounts.User, :create_v1
    end
  end

  actions do
    defaults [:read]
  end
end
