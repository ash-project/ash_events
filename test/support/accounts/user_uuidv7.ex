defmodule AshEvents.Test.Accounts.UserUuidV7 do
  @moduledoc false
  use Ash.Resource,
    domain: AshEvents.Test.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshEvents.Events]

  postgres do
    table "users_uuidv7"
    repo AshEvents.TestRepo
  end

  events do
    event_log AshEvents.Test.Events.EventLogUuidV7
    current_action_versions create: 1
  end

  actions do
    defaults [:read]

    create :create do
      accept [:id, :created_at, :updated_at, :email, :given_name, :family_name]
    end

    update :update do
      require_atomic? false
      accept [:given_name, :family_name]
    end

    destroy :destroy do
      require_atomic? false
      primary? true
      accept []
    end

    read :get_by_id do
      get_by [:id]
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
end
