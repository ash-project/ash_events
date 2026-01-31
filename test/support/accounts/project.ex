# SPDX-FileCopyrightText: 2024 Torkild G. Kjevik
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Accounts.Project do
  @moduledoc """
  Test resource with non-writable primary key and timestamps.

  This tests that replay correctly handles resources where:
  - uuid_primary_key has writable?: false (the default)
  - create_timestamp has writable?: false (the default)
  - update_timestamp has writable?: false (the default)
  - Actions do NOT accept :id, :created_at, or :updated_at

  The replay system must use force_change_attributes to set these
  auto-generated values during replay via the changed_attributes mechanism.
  """
  use Ash.Resource,
    domain: AshEvents.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events]

  postgres do
    table "projects"
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
      # Specifically NOT accepting :id, :created_at, :updated_at
      accept [:name, :description, :status]
    end

    # Upsert action for testing rerouted upsert replay with non-writable fields
    create :create_or_update do
      accept [:name, :description, :status]
      upsert? true
      upsert_identity :unique_name
      upsert_fields [:description, :status]
    end

    # Replay action for rerouted upsert
    # Must handle non-writable id/timestamps via force_change
    create :create_or_update_replay do
      upsert? true
      upsert_identity :unique_name
      upsert_fields [:description, :status]
      accept [:name, :description, :status]
      skip_unknown_inputs [:*]
    end

    update :update do
      # Specifically NOT accepting :created_at, :updated_at
      accept [:name, :description, :status]
      require_atomic? false
    end

    update :change_status do
      accept []
      require_atomic? false
      argument :new_status, :atom do
        allow_nil? false
        constraints one_of: [:draft, :active, :archived]
      end

      change set_attribute(:status, arg(:new_status))
    end

    destroy :destroy do
      require_atomic? false
    end
  end

  attributes do
    # Default uuid_primary_key - writable? defaults to false
    uuid_primary_key :id

    # Default timestamps - writable? defaults to false
    create_timestamp :created_at do
      public? true
      allow_nil? false
    end

    update_timestamp :updated_at do
      public? true
      allow_nil? false
    end

    attribute :name, :string do
      public? true
      allow_nil? false
    end

    attribute :description, :string do
      public? true
      allow_nil? true
    end

    attribute :status, :atom do
      public? true
      allow_nil? false
      default :draft
      constraints one_of: [:draft, :active, :archived]
    end
  end

  identities do
    identity :unique_name, [:name]
  end
end
