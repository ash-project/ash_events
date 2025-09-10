defmodule AshEvents.EventLogs.EventLogUuidV7 do
  @moduledoc false
  use Ash.Resource,
    domain: AshEvents.EventLogs,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.EventLog]

  postgres do
    table "events_uuidv7"
    repo AshEvents.TestRepo
  end

  event_log do
    primary_key_type Ash.Type.UUIDv7
    clear_records_for_replay AshEvents.EventLogs.ClearRecordsUuidV7
    persist_actor_primary_key :user_id, AshEvents.Accounts.User

    persist_actor_primary_key :system_actor, AshEvents.EventLogs.SystemActor,
      attribute_type: :string
  end

  actions do
    defaults [:read]
  end
end
