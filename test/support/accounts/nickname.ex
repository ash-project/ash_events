# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Accounts.Nickname do
  @moduledoc false
  # A tracked resource whose only identity is partial (a unique index with a `where`), so
  # an upsert against it needs the identity's `where` in its `ON CONFLICT` target.
  use Ash.Resource,
    domain: AshEvents.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events]

  postgres do
    table "nicknames"
    repo AshEvents.TestRepo

    identity_wheres_to_sql unique_active_name: "archived = false"
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
      accept [:name, :archived]
      upsert_fields [:updated_at]
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

    attribute :archived, :boolean do
      public? true
      allow_nil? false
      default false
    end
  end

  identities do
    identity :unique_active_name, [:name], where: expr(archived == false)
  end
end
