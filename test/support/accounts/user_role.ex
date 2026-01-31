# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Accounts.UserRole do
  @moduledoc false
  use Ash.Resource,
    domain: AshEvents.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events]

  events do
    event_log AshEvents.EventLogs.EventLog
    create_timestamp :created_at
    update_timestamp :updated_at
  end

  postgres do
    table "user_roles"
    repo AshEvents.TestRepo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:id, :created_at, :updated_at, :name]
      argument :user_id, :uuid, allow_nil?: false

      change manage_relationship(:user_id, :user, type: :append)
    end

    # Upsert action - if user already has a role, update it
    create :create_or_update do
      accept [:id, :created_at, :updated_at, :name, :user_id]
      upsert? true
      upsert_identity :unique_for_user
      upsert_fields [:name, :updated_at]
    end

    # Replay action for rerouted upsert
    # Tests upsert with relationship-based identity
    create :create_or_update_replay do
      upsert? true
      upsert_identity :unique_for_user
      upsert_fields [:name]
      accept [:id, :name, :user_id]
      skip_unknown_inputs [:*]
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:created_at, :updated_at, :name]
    end

    destroy :destroy do
      require_atomic? false
      primary? true
      accept []
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

    attribute :name, :string do
      allow_nil? false
      public? true
    end
  end

  relationships do
    belongs_to :user, AshEvents.Accounts.User do
      allow_nil? false
    end
  end

  identities do
    identity :unique_for_user, [:user_id]
  end
end
