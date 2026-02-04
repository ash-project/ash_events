# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Accounts.UserNonWritableId do
  @moduledoc """
  Test resource with a non-writable UUID primary key that is NOT accepted by the create action.
  This matches the common pattern where IDs are auto-generated and not user-provided.
  """
  use Ash.Resource,
    domain: AshEvents.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events]

  postgres do
    table "users_non_writable_id"
    repo AshEvents.TestRepo
  end

  events do
    event_log AshEvents.EventLogs.EventLog
  end

  actions do
    defaults [:read]

    create :create do
      accept [:email, :name]
    end

    update :update do
      accept [:name]
    end

    destroy :destroy do
      require_atomic? false
    end

    read :get_by_id do
      get_by [:id]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :string do
      public? true
      allow_nil? false
    end

    attribute :name, :string do
      public? true
      allow_nil? false
    end
  end
end
