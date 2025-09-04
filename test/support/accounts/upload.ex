defmodule AshEvents.Test.Accounts.Upload do
  @moduledoc false
  use Ash.Resource,
    domain: AshEvents.Test.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events, AshStateMachine],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "uploads"
    repo AshEvents.TestRepo
  end

  state_machine do
    initial_states [:uploaded, :skipped]
    default_initial_state :skipped

    transitions do
      transition :create, from: :*, to: :*
      transition :mark_uploaded, from: :skipped, to: :uploaded
      transition :mark_skipped, from: :uploaded, to: :skipped
    end
  end

  events do
    event_log AshEvents.Test.Events.EventLog
  end

  actions do
    defaults [:read]

    create :create do
      accept [:id, :created_at, :updated_at, :file_name, :s3_key_formatted]
      upsert? true
      upsert_identity :unique_file_name

      change transition_state(:uploaded) do
        where [attributes_present([:s3_key_formatted])]
      end
    end

    update :mark_uploaded do
      accept []
      require_atomic? false
      change transition_state(:uploaded)
    end

    update :mark_skipped do
      accept []
      require_atomic? false
      change transition_state(:skipped)
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

    attribute :file_name, :string do
      public? true
      allow_nil? false
    end

    attribute :s3_key_formatted, :string do
      public? true
      allow_nil? true
    end
  end

  identities do
    identity :unique_file_name, [:file_name]
  end

  policies do
    bypass always() do
      authorize_if AshEvents.Checks.TestCheck
    end
  end
end
