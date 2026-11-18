# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EventLogs.EventLogNoSensitiveChanges do
  @moduledoc false
  use Ash.Resource,
    domain: AshEvents.EventLogs,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.EventLog]

  postgres do
    table "events_no_sensitive_changes"
    repo AshEvents.TestRepo
  end

  event_log do
    clear_records_for_replay AshEvents.EventLogs.ClearRecordsNoSensitiveChanges
    store_sensitive_changed_attributes? false

    persist_actor_primary_key :system_actor, AshEvents.EventLogs.SystemActor,
      attribute_type: :string
  end

  actions do
    defaults [:read]
  end
end
