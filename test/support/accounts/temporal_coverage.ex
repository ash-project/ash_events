# SPDX-FileCopyrightText: 2023 ash-project contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Accounts.TemporalCoverage do
  @moduledoc """
  Test resource for temporal `as_of` capture and replay (ash_events#103).

  A temporal resource: every version is a row valid for a period of
  `valid_at`. A replay of its events must rebuild the periods exactly —
  including the split points of updates and the truncation instants of
  destroys — which is only possible when the replay re-invokes the actions
  at their ORIGINAL `as_of`.
  """
  use Ash.Resource,
    domain: AshEvents.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events]

  postgres do
    table "temporal_coverages"
    repo AshEvents.TestRepo
  end

  temporal do
    strategy :context
    attribute :valid_at
  end

  events do
    event_log AshEvents.EventLogs.EventLog
  end

  attributes do
    uuid_primary_key :id
    attribute :plan, :string, allow_nil?: false, public?: true
  end

  actions do
    defaults [:read]

    create :create do
      accept [:plan]
    end

    update :update do
      accept [:plan]
    end

    destroy :destroy do
    end
  end
end
