# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Accounts.SoftDeletableUser do
  @moduledoc false
  use Ash.Resource,
    domain: AshEvents.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events]

  postgres do
    table "soft_deletable_users"
    repo AshEvents.TestRepo
  end

  events do
    event_log AshEvents.EventLogs.EventLog
    create_timestamp :created_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read]

    create :create do
      accept [:id, :email, :name, :created_at, :updated_at, :archived_at]
    end

    update :update do
      require_atomic? false
      accept [:name]
    end

    destroy :archive do
      require_atomic? false
      soft? true
      change set_attribute(:archived_at, &DateTime.utc_now/0)
    end

    read :get_by_id do
      get_by [:id]
    end
  end

  attributes do
    uuid_primary_key :id do
      writable? true
    end

    create_timestamp :created_at do
      public? true
      allow_nil? false
      writable? true
    end

    update_timestamp :updated_at do
      public? true
      allow_nil? false
      writable? true
    end

    attribute :email, :string do
      public? true
      allow_nil? false
    end

    attribute :name, :string do
      public? true
      allow_nil? true
    end

    attribute :archived_at, :utc_datetime_usec do
      public? true
      allow_nil? true
      writable? true
    end
  end

  identities do
    identity :unique_email, [:email]
  end
end
