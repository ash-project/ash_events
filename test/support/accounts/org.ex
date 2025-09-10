defmodule AshEvents.Accounts.Org do
  @moduledoc false
  use Ash.Resource,
    domain: AshEvents.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events]

  postgres do
    table "orgs"
    repo AshEvents.TestRepo
  end

  events do
    event_log AshEvents.Test.Events.EventLog
    create_timestamp :created_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read]

    create :create do
      accept [:id, :created_at, :updated_at, :name]

      validate string_length(:name, min: 2, max: 100)
    end

    update :update do
      accept [:name, :updated_at]

      validate string_length(:name, min: 2, max: 100)
    end

    update :reactivate do
      require_atomic? false
      argument :justification, :string, allow_nil?: false, constraints: [allow_empty?: true]
      validate attribute_equals(:active, false), message: "Organization is already active"
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

    attribute :active, :boolean do
      public? true
      allow_nil? false
      default true
    end
  end
end
