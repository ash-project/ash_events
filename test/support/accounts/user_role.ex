defmodule AshEvents.Test.Accounts.UserRole do
  use Ash.Resource,
    domain: AshEvents.Test.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events]

  events do
    event_log AshEvents.Test.Events.EventLog
  end

  postgres do
    table "user_roles"
    repo AshEvents.TestRepo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:id, :created_at, :updated_at, :name]
      argument :user_id, :uuid, allow_nil?: false

      change manage_relationship(:user_id, :user, type: :append)
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:created_at, :updated_at, :name]
    end

    destroy :destroy do
      require_atomic? false
      primary? true
      accept []
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
      allow_nil? false
      public? true
    end
  end

  relationships do
    belongs_to :user, AshEvents.Test.Accounts.User do
      allow_nil? false
    end
  end

  identities do
    identity :unique_for_user, [:user_id]
  end
end
