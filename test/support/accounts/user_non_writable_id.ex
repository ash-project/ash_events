# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Accounts.UserNonWritableId do
  @moduledoc """
  Test resource that exactly matches the reported issue scenario:
  - uuid_primary_key with writable?: false (the default)
  - create action that does NOT accept :id

  This tests that replay correctly uses force_change_attributes to set
  the auto-generated id during replay.
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
      # Specifically NOT accepting :id to match the user's scenario
      accept [:email, :name]
    end

    update :update do
      accept [:name]
    end

    destroy :destroy do
      require_atomic? false
    end
  end

  attributes do
    # Default uuid_primary_key without explicit writable? - defaults to false
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
