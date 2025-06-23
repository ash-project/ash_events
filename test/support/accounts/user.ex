defmodule AshEvents.Test.Accounts.User do
  @moduledoc false
  use Ash.Resource,
    domain: AshEvents.Test.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshEvents.Events]

  postgres do
    table "users"
    repo AshEvents.TestRepo
  end

  events do
    event_log AshEvents.Test.Events.EventLog
    ignore_actions [:create_v1]
    current_action_versions create: 1
    create_timestamp :created_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read]

    create :create do
      accept [:id, :created_at, :updated_at, :email, :given_name, :family_name]
      argument :role, :string, default: "user"
      change __MODULE__.CreateUserRole
    end

    create :create_with_atomic do
      accept [:id, :created_at, :updated_at, :email, :given_name, :family_name]
      argument :role, :string, default: "user"
      change __MODULE__.CreateUserRole
      change atomic_update(:given_name, expr(given_name + "should_fail"))
    end

    update :update do
      require_atomic? false
      accept [:given_name, :family_name, :created_at, :updated_at]
      argument :role, :string, allow_nil?: true

      change __MODULE__.UpdateUserRole
    end

    update :update_with_atomic do
      require_atomic? false
      accept [:given_name, :family_name]
      argument :role, :string, allow_nil?: true

      change __MODULE__.UpdateUserRole
      change atomic_update(:given_name, expr(given_name + "should_fail"))
    end

    destroy :destroy do
      require_atomic? false
      primary? true
      accept []
    end

    destroy :destroy_with_atomic do
      require_atomic? false
      accept []

      change atomic_update(:given_name, expr(given_name + "should_fail"))
    end

    read :get_by_id do
      get_by [:id]
    end

    create :create_v1 do
      accept [:id, :created_at, :updated_at, :email, :given_name, :family_name]
      argument :role, :string, default: "user"
    end
  end

  policies do
    bypass always() do
      authorize_if AshEvents.Checks.TestCheck
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

  relationships do
    has_one :user_role, AshEvents.Test.Accounts.UserRole do
      public? true
    end
  end
end
