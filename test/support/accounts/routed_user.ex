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
    event_log AshEvents.Test.Events.EventLog
    ignore_actions [:routed_create]
  end

  actions do
    defaults [:read]

    create :routed_create do
      accept [:id, :created_at, :updated_at, :email, :given_name, :family_name]
      argument :role, :string, default: "user"
    end

    read :get_by_id do
      get_by [:id]
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
  end
end
