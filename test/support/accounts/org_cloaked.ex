# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Accounts.OrgCloaked do
  @moduledoc false
  use Ash.Resource,
    domain: AshEvents.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events, AshCloak]

  postgres do
    table "orgs_cloaked"
    repo AshEvents.TestRepo
  end

  cloak do
    vault(AshEvents.Vault)
    attributes([:name])
  end

  events do
    event_log AshEvents.EventLogs.EventLogCloaked
    allowed_change_modules create: [AshCloak.Changes.Encrypt], update: [AshCloak.Changes.Encrypt]
  end

  actions do
    defaults [:read]

    create :create do
      accept [:id, :created_at, :updated_at, :name]
    end

    update :update do
      require_atomic? false
      accept [:created_at, :updated_at, :name]
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
  end
end
