defmodule AshEvents.Test.Accounts.User do
  alias AshEvents.Test.Accounts

  use Ash.Resource,
    domain: AshEvents.Test.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events]

  postgres do
    table "users"
    repo AshEvents.TestRepo
  end

  events do
    event_resource AshEvents.Test.Events.EventResource

    ignore_actions [:create_v1]
  end

  actions do
    defaults [:read]

    create :create do
      accept [:id, :email, :given_name, :family_name, :created_at, :updated_at]

      change AshEvents.Test.CreateUserRole
    end

    update :update do
      require_atomic? false
      accept [:given_name, :family_name]

      change after_action(fn cs, record, ctx ->
               opts = Ash.Context.to_opts(ctx)
               user = Ash.load!(record, [:user_role], opts)
               Accounts.update_user_role!(user.user_role, %{name: "admin"}, opts)
               {:ok, record}
             end)
    end

    destroy :destroy do
      require_atomic? false
      primary? true
      accept []
    end

    read :get_by_id do
      get? true
      argument :id, :uuid, allow_nil?: false

      filter expr(id == ^arg(:id))
    end

    create :create_v1 do
      accept [:id, :email, :given_name, :family_name]
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
