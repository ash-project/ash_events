# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Accounts.TemporalSubscription do
  @moduledoc """
  A plain Ash temporal resource, not tracked by AshEvents. It pins down how Ash
  temporal writes populate the period, the timestamps and `recorded_at` on
  PostgreSQL, before AshEvents is involved.
  """
  use Ash.Resource,
    domain: AshEvents.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "temporal_subscriptions"
    repo AshEvents.TestRepo
  end

  temporal do
    strategy :context
    attribute :valid_at
    recorded_at :recorded_at
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:plan]
    end

    update :update do
      primary? true
      accept [:plan]
    end

    update :update_non_atomic do
      require_atomic? false
      accept [:plan]
    end

    destroy :destroy do
      primary? true
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :plan, :string do
      public? true
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
