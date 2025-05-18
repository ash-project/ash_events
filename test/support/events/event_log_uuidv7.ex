defmodule AshEvents.Test.Events.EventLogUuidV7 do
  @moduledoc false
  use Ash.Resource,
    domain: AshEvents.Test.Events,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.EventLog]

  postgres do
    table "events_uuidv7"
    repo AshEvents.TestRepo
  end

  event_log do
    primary_key_type Ash.Type.UUIDv7
    clear_records_for_replay AshEvents.Test.Events.ClearRecordsUuidV7
    persist_actor_primary_key :user_id, AshEvents.Test.Accounts.User

    persist_actor_primary_key :system_actor, AshEvents.Test.Events.SystemActor,
      attribute_type: :string
  end

  actions do
    defaults [:read]
  end
end
