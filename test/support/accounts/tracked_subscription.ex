# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Accounts.TrackedSubscription do
  @moduledoc """
  A temporal resource with `recorded_at`, tracked by AshEvents into
  `AshEvents.EventLogs.EventLogTemporal`.
  """
  use Ash.Resource,
    domain: AshEvents.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events]

  postgres do
    table "tracked_subscriptions"
    repo AshEvents.TestRepo
  end

  temporal do
    strategy :context
    attribute :valid_at
    recorded_at :recorded_at
  end

  events do
    event_log AshEvents.EventLogs.EventLogTemporal
    # Replay sets recorded_at under both strategies.
    replay_non_input_attribute_changes update_with_safe_change: :as_arguments
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:plan]
    end

    create :create_upsert do
      upsert? true
      accept [:id, :plan]
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:plan]
    end

    update :update_with_safe_change do
      require_atomic? false
      accept [:plan]
      change AshEvents.Accounts.TrackedSubscription.UpcasePlan
      validate string_length(:plan, min: 1)
    end

    update :update_with_unsafe_change do
      require_atomic? false
      accept [:plan]
      change AshEvents.Accounts.TrackedSubscription.UnsafeChange
    end

    destroy :destroy do
      primary? true
      require_atomic? false
    end

    destroy :archive do
      soft? true
      require_atomic? false
      change set_attribute(:archived_at, &DateTime.utc_now/0)
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

    attribute :archived_at, :utc_datetime_usec do
      public? true
      allow_nil? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
