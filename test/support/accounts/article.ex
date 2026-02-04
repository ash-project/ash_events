# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Accounts.Article do
  @moduledoc """
  Test resource for destroy action wrapper testing.

  Supports both hard deletes and soft deletes to test the full
  DestroyActionWrapper functionality.
  """
  use Ash.Resource,
    domain: AshEvents.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events]

  postgres do
    table "articles"
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
      accept [:id, :created_at, :updated_at, :title, :body]
    end

    update :update do
      require_atomic? false
      accept [:title, :body, :updated_at]
    end

    update :archive do
      require_atomic? false
      description "Archive an article (reversible soft delete)"
      accept []
      change set_attribute(:archived_at, &DateTime.utc_now/0)
    end

    update :unarchive do
      require_atomic? false
      description "Unarchive an article"
      accept []
      validate attribute_does_not_equal(:archived_at, nil), message: "Article is not archived"
      change set_attribute(:archived_at, nil)
    end

    destroy :destroy do
      require_atomic? false
      primary? true
      description "Hard delete an article"
      accept []
    end

    destroy :soft_destroy do
      require_atomic? false
      soft? true
      description "Soft delete an article (sets deleted_at)"
      accept []
      change set_attribute(:deleted_at, &DateTime.utc_now/0)
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

    attribute :title, :string do
      public? true
      allow_nil? false
    end

    attribute :body, :string do
      public? true
      allow_nil? true
    end

    attribute :archived_at, :utc_datetime_usec do
      public? true
      allow_nil? true
    end

    attribute :deleted_at, :utc_datetime_usec do
      public? true
      allow_nil? true
    end
  end
end
