defmodule AshEvents.Test.Accounts.OrgStateMachine do
  @moduledoc false
  use Ash.Resource,
    domain: AshEvents.Test.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events, AshStateMachine],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "org_state_machine"
    repo AshEvents.TestRepo
  end

  state_machine do
    default_initial_state(:active)
    initial_states([:active])

    transitions do
      transition(:set_inactive, from: :active, to: :inactive)
      transition(:set_active, from: :inactive, to: :active)
    end
  end

  events do
    event_log AshEvents.Test.Events.EventLogStateMachine
  end

  actions do
    defaults [:read]

    create :create do
      accept [:id, :created_at, :updated_at, :name]

      change fn cs, ctx ->
        cs
      end
    end

    update :set_inactive do
      require_atomic? false
      change transition_state(:inactive)
    end

    update :set_active do
      require_atomic? false
      change transition_state(:active)
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

  policies do
    policy action(:create) do
      authorize_if actor_attribute_equals(:is_system_actor, true)
    end

    policy action(:set_inactive) do
      authorize_if actor_attribute_equals(:is_system_actor, true)
    end
  end
end
