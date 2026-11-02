# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Accounts.TrackedSubscriptionNoRecordedAt do
  @moduledoc """
  A temporal resource without `recorded_at`, tracked by AshEvents into
  `AshEvents.EventLogs.EventLogTemporal`.
  """
  use Ash.Resource,
    domain: AshEvents.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events]

  postgres do
    table "tracked_subscriptions_no_recorded_at"
    repo AshEvents.TestRepo
  end

  temporal do
    strategy :context
    attribute :valid_at
  end

  events do
    event_log AshEvents.EventLogs.EventLogTemporal
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:plan]
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:plan]
    end
  end

  attributes do
    uuid_primary_key :id do
      writable? true
    end

    attribute :plan, :string do
      public? true
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
