# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Accounts.RoutedUser do
  @moduledoc false
  use Ash.Resource,
    domain: AshEvents.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events]

  postgres do
    table "routed_users"
    repo AshEvents.TestRepo
  end

  events do
    event_log AshEvents.EventLogs.EventLog
    # routed_create is in ignore_actions - it's only used for backfilling
    # during replay. It explicitly accepts the fields it needs.
    ignore_actions [:routed_create]
  end

  actions do
    defaults [:read]

    create :routed_create do
      # Backfill action: accepts fields needed from rerouted events
      # Including :id to preserve the original record's identity
      # skip_unknown_inputs allows ignoring fields from the original resource
      # that don't exist on this resource (e.g., confirmed_at)
      accept [:id, :email, :given_name, :family_name, :hashed_password]
      argument :role, :string, default: "user"
      skip_unknown_inputs :*
    end

    read :get_by_id do
      get_by [:id]
    end
  end

  attributes do
    # writable? true because this resource receives id as input from rerouted events
    uuid_primary_key :id do
      writable? true
    end

    create_timestamp :created_at do
      public? true
      allow_nil? false
    end

    update_timestamp :updated_at do
      public? true
      allow_nil? false
    end

    attribute :email, :string do
      public? true
      allow_nil? false
    end

    attribute :given_name, :string do
      allow_nil? false
      public? true
    end

    attribute :family_name, :string do
      allow_nil? false
      public? true
    end

    attribute :hashed_password, :string do
      allow_nil? true
    end
  end
end
