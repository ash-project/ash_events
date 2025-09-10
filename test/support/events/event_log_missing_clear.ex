defmodule AshEvents.Test.Events.EventLogMissingClear do
  @moduledoc false
  use Ash.Resource,
    domain: AshEvents.Test.Events,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.EventLog]

  postgres do
    table "events"
    repo AshEvents.TestRepo
  end

  event_log do
    persist_actor_primary_key :user_id, AshEvents.Accounts.User

    persist_actor_primary_key :system_actor, AshEvents.Test.Events.SystemActor,
      attribute_type: :string
  end

  replay_overrides do
    replay_override AshEvents.Accounts.User, :create do
      versions [1]
      route_to AshEvents.Accounts.User, :create_v1
    end
  end

  actions do
    defaults [:read]
  end
end
