defmodule AshEvents.Test.Events.EventLogCloaked do
  @moduledoc false
  use Ash.Resource,
    domain: AshEvents.Test.Events,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.EventLog]

  postgres do
    table "events_cloaked"
    repo AshEvents.TestRepo
  end

  event_log do
    clear_records_for_replay AshEvents.Test.Events.ClearRecords
    persist_actor_primary_key :user_id, AshEvents.Test.Accounts.User

    persist_actor_primary_key :system_actor, AshEvents.Test.Events.SystemActor,
      attribute_type: :string

    cloak_vault(AshEvents.Test.Vault)
  end

  replay_overrides do
    replay_override AshEvents.Test.Accounts.User, :create do
      versions([1])
      route_to AshEvents.Test.Accounts.User, :create_v1
      route_to AshEvents.Test.Accounts.RoutedUser, :routed_create
    end
  end

  actions do
    defaults [:read]
  end
end
