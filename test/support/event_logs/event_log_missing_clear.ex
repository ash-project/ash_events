# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EventLogs.EventLogMissingClear do
  @moduledoc false
  use Ash.Resource,
    domain: AshEvents.EventLogs,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.EventLog]

  postgres do
    table "events"
    repo AshEvents.TestRepo
  end

  event_log do
    persist_actor_primary_key :user_id, AshEvents.Accounts.User

    persist_actor_primary_key :system_actor, AshEvents.EventLogs.SystemActor,
      attribute_type: :string

    public_fields([:id, :version])
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
