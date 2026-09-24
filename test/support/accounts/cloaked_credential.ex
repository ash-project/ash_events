# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Accounts.CloakedCredential do
  @moduledoc false
  use Ash.Resource,
    domain: AshEvents.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events]

  postgres do
    table "cloaked_credentials"
    repo AshEvents.TestRepo
  end

  events do
    event_log AshEvents.EventLogs.EventLogCloakedNoSensitiveInputs
  end

  actions do
    defaults [:read]

    create :create do
      accept [:name, :api_token]
      argument :passphrase, :string, sensitive?: true
      argument :note, :string
    end

    update :update do
      require_atomic? false
      accept [:name, :api_token]
      argument :passphrase, :string, sensitive?: true
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
    end

    attribute :api_token, :string do
      public? true
      sensitive? true
    end
  end
end
