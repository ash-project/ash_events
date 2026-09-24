# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EventLogs.EventLogCloakedNoSensitiveInputs do
  @moduledoc false
  use Ash.Resource,
    domain: AshEvents.EventLogs,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.EventLog]

  postgres do
    table "events_cloaked_no_sensitive_inputs"
    repo AshEvents.TestRepo
  end

  event_log do
    clear_records_for_replay AshEvents.EventLogs.ClearRecordsCloakedNoSensitiveInputs
    persist_actor_primary_key :user_id, AshEvents.Accounts.User
    cloak_vault AshEvents.Vault
    store_sensitive_inputs? false
  end

  actions do
    defaults [:read]
  end
end
