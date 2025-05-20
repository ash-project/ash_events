defmodule AshEvents.Test.Accounts.OrgCloaked do
  @moduledoc false
  use Ash.Resource,
    domain: AshEvents.Test.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events, AshCloak]

  postgres do
    table "orgs_cloaked"
    repo AshEvents.TestRepo
  end

  cloak do
    vault(AshEvents.Test.Vault)
    attributes([:name])
  end

  events do
    event_log AshEvents.Test.Events.EventLogCloaked
  end

  actions do
    defaults [:read]

    create :create do
      accept [:id, :created_at, :updated_at, :name]
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
