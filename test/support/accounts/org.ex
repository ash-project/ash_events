defmodule AshEvents.Test.Accounts.Org do
  @moduledoc false
  use Ash.Resource,
    domain: AshEvents.Test.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events]

  postgres do
    table "orgs"
    repo AshEvents.TestRepo
  end

  events do
    event_log AshEvents.Test.Events.EventLog
  end

  actions do
    defaults [:read]

    create :create do
      accept [:id, :created_at, :updated_at, :name]

      validate string_length(:name, min: 2, max: 100)
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
