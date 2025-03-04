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
    belongs_to_actor :user, AshEvents.Test.Accounts.User
  end

  replay_overrides do
    replay_override AshEvents.Test.Accounts.User, :create_ash_events_impl, "1." do
      route_to AshEvents.Test.Accounts.User, :create_v1
    end
  end

  actions do
    defaults [:read]
  end
end
