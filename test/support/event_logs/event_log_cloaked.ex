defmodule AshEvents.EventLogs.EventLogCloaked do
  @moduledoc false
  use Ash.Resource,
    domain: AshEvents.EventLogs,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.EventLog]

  postgres do
    table "events_cloaked"
    repo AshEvents.TestRepo
  end

  event_log do
    clear_records_for_replay AshEvents.EventLogs.ClearRecordsCloaked
    persist_actor_primary_key :user_id, AshEvents.Accounts.User

    persist_actor_primary_key :system_actor, AshEvents.EventLogs.SystemActor,
      attribute_type: :string

    cloak_vault AshEvents.Vault
  end

  replay_overrides do
    replay_override AshEvents.Accounts.User, :create do
      versions([1])
      route_to AshEvents.Accounts.User, :create_v1
      route_to AshEvents.Accounts.RoutedUser, :routed_create
    end
  end

  actions do
    defaults [:read]
  end
end
