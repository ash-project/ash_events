# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Accounts.Comment do
  @moduledoc false
  use Ash.Resource,
    domain: AshEvents.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events]

  postgres do
    table "comments"
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
      primary? true
      accept [:id, :created_at, :updated_at, :body]
      argument :user_id, :uuid, allow_nil?: false

      change manage_relationship(:user_id, :user, type: :append)
    end

    create :create_from_parent do
      accept [:body]
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:body, :updated_at]
    end

    destroy :destroy do
      primary? true
      require_atomic? false
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

    attribute :body, :string do
      public? true
      allow_nil? false
    end
  end

  relationships do
    belongs_to :user, AshEvents.Accounts.User do
      allow_nil? false
    end
  end
end
