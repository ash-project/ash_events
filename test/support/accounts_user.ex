defmodule AshEvents.Test.Accounts.User do
  use Ash.Resource,
    domain: AshEvents.Test.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.CommandResource]

  postgres do
    table "users"
    repo AshEvents.TestRepo
  end

  commands do
    event_resource AshEvents.Test.Events.EventResource

    create_command :create, "1.0" do
      accept [:id, :email, :given_name, :family_name]

      on_success fn user, ctx ->
        IO.inspect("User created: #{user.email}")
        {:ok, user}
      end
    end

    update_command :update, "1.0" do
      accept [:given_name, :family_name]
      allow_nil_input [:given_name, :family_name]

      on_success fn user, ctx ->
        IO.inspect("User updated: #{user.email}")
        {:ok, user}
      end
    end

    destroy_command :destroy, "1.0" do
      primary? true

      on_success fn user, ctx ->
        IO.inspect("User destroyed: #{user.email}")
        {:ok, user}
      end
    end
  end

  actions do
    defaults [:read]

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
