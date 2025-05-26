defmodule AshEvents.Test.Accounts.OrgDetails do
  @moduledoc false
  use Ash.Resource,
    domain: AshEvents.Test.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events]

  postgres do
    table "org_details"
    repo AshEvents.TestRepo
  end

  events do
    event_log AshEvents.Test.Events.EventLog
    only_actions([:create, :update])
  end

  actions do
    defaults [:read]

    create :create do
      accept [:id, :created_at, :updated_at, :details]
    end

    create :create_not_in_only do
      accept [:id, :created_at, :updated_at, :details]
    end

    update :update do
      accept [:details]
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

    attribute :details, :string do
      public? true
      allow_nil? false
    end
  end

  multitenancy do
    strategy :attribute
    attribute :org_id
  end

  relationships do
    belongs_to :org, AshEvents.Test.Accounts.Org do
      allow_nil? false
      public? true
    end
  end
end
