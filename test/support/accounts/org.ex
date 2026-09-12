# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Accounts.Org do
  @moduledoc false
  use Ash.Resource,
    domain: AshEvents.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events]

  postgres do
    table "orgs"
    repo AshEvents.TestRepo
  end

  events do
    event_log AshEvents.EventLogs.EventLog

    ignore_actions [
      :create_ignored,
      :update_ignored,
      :destroy_ignored,
      :create_ignored_with_before_action_validation
    ]

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read]

    create :create do
      accept [:id, :created_at, :updated_at, :name, :secret_hash]

      validate string_length(:name, min: 2, max: 100)
    end

    update :update do
      accept [:name, :updated_at]

      validate string_length(:name, min: 2, max: 100)
    end

    create :create_ignored do
      accept [:id, :created_at, :updated_at, :name]
    end

    update :update_ignored do
      accept [:name]
    end

    destroy :destroy_ignored do
      accept []
    end

    update :reactivate do
      require_atomic? false
      argument :justification, :string, allow_nil?: false, constraints: [allow_empty?: true]
      validate attribute_equals(:active, false), message: "Organization is already active"
    end

    # `active` defaults to true and is only flipped from a before_action hook, so
    # the validation below passes only if `before_action?: true` actually delays
    # it. These two actions are identical apart from event tracking, and must
    # behave identically.
    create :create_with_before_action_validation do
      accept [:id, :created_at, :updated_at, :name]

      change AshEvents.Accounts.Org.DeactivateInBeforeAction

      validate attribute_equals(:active, false),
        message: "validation ran before the before_action hook",
        before_action?: true
    end

    create :create_ignored_with_before_action_validation do
      accept [:id, :created_at, :updated_at, :name]

      change AshEvents.Accounts.Org.DeactivateInBeforeAction

      validate attribute_equals(:active, false),
        message: "validation ran before the before_action hook",
        before_action?: true
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
      public? true
      allow_nil? false
    end

    attribute :active, :boolean do
      public? true
      allow_nil? false
      default true
    end

    attribute :secret_hash, :binary do
      public? true
      allow_nil? true
    end
  end
end
