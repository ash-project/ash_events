# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EventLogs.EventLogStateMachine do
  @moduledoc false
  use Ash.Resource,
    domain: AshEvents.EventLogs,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.EventLog]

  postgres do
    table "events_state_machine"
    repo AshEvents.TestRepo
  end

  event_log do
    primary_key_type Ash.Type.UUIDv7
    clear_records_for_replay AshEvents.EventLogs.ClearRecordsStateMachine
    persist_actor_primary_key :user_id, AshEvents.Accounts.User

    persist_actor_primary_key :system_actor, AshEvents.EventLogs.SystemActor,
      attribute_type: :string
  end

  actions do
    defaults [:read]
  end
end
