# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Accounts.Credential do
  @moduledoc false
  use Ash.Resource,
    domain: AshEvents.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events]

  postgres do
    table "credentials"
    repo AshEvents.TestRepo
  end

  events do
    event_log AshEvents.EventLogs.EventLogNoSensitiveChanges
  end

  actions do
    defaults [:read]

    create :create do
      accept [:name, :api_key]
      change set_attribute(:secret, &Ash.UUID.generate/0)
    end

    update :rotate_secret do
      require_atomic? false
      change set_attribute(:secret, &Ash.UUID.generate/0)
    end
  end

  attributes do
    uuid_primary_key :id do
      writable? true
    end

    attribute :name, :string do
      public? true
      allow_nil? false
    end

    attribute :api_key, :string do
      public? true
      sensitive? true
    end

    attribute :secret, :string do
      public? true
      sensitive? true
    end
  end
end
