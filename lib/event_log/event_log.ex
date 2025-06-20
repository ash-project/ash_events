defmodule AshEvents.EventLog do
  @moduledoc """
  Extension to use on the Ash.Resource that will persist events.
  """

  defmodule ReplayOverride do
    @moduledoc false
    defstruct [:event_resource, :event_action, :versions, :route_to]
  end

  defmodule RouteTo do
    @moduledoc false
    defstruct [:resource, :action]
  end

  @route_to %Spark.Dsl.Entity{
    name: :route_to,
    describe: """
    Routes the event to a different action.
    """,
    target: RouteTo,
    schema: [
      resource: [
        type: :atom,
        required: true
      ],
      action: [
        type: :atom,
        required: true
      ]
    ],
    args: [:resource, :action]
  }

  @replay_override %Spark.Dsl.Entity{
    name: :replay_override,
    describe: "Overrides the default event replay behavior for a specific resource action.",
    examples: [
      """
      replay_overrides do
        replay_override MyApp.Accounts.User, :create do
          versions [1]
          route_to MyApp.Accounts.User, :create_v1
        end
      end
      """
    ],
    target: ReplayOverride,
    schema: [
      event_resource: [
        type: :atom,
        required: true,
        doc: "The name of the resource stored in the event, that you want to match on."
      ],
      event_action: [
        type: :atom,
        required: true,
        doc: "The name of the action stored in the event, that you want to match on."
      ],
      versions: [
        type: {:list, :integer},
        doc: "A list of event versions to match on.",
        required: true
      ]
    ],
    args: [:event_resource, :event_action],
    entities: [route_to: [@route_to]]
  }

  @replay_overrides %Spark.Dsl.Section{
    name: :replay_overrides,
    entities: [@replay_override]
  }

  @persist_actor_primary_key %Spark.Dsl.Entity{
    name: :persist_actor_primary_key,
    describe:
      "Store the actor's primary key in the event if an actor is set, and the actor matches the resource type. You can define an entry for each actor type.",
    examples: [
      "persist_actor_primary_key :user_id, MyApp.Accounts.User",
      "persist_actor_primary_key :system_actor, MyApp.SystemActor"
    ],
    no_depend_modules: [:destination],
    target: AshEvents.EventLog.PersistActorPrimaryKey,
    args: [:name, :destination],
    schema: AshEvents.EventLog.PersistActorPrimaryKey.schema()
  }

  @event_log %Spark.Dsl.Section{
    name: :event_log,
    schema: [
      primary_key_type: [
        type: {:one_of, [:integer, Ash.Type.UUIDv7]},
        doc:
          "The type of the primary key used by the event log resource. Valid options are :integer  and :uuid_v7. Defaults to :integer.",
        default: :integer
      ],
      clear_records_for_replay: [
        type: {:behaviour, AshEvents.ClearRecordsForReplay},
        required: false,
        doc:
          "A module with the AshEvents.ClearRecords-behaviour, that is expected to clear all records before an event replay."
      ],
      advisory_lock_key_generator: [
        type: {:behaviour, AshEvents.AdvisoryLockKeyGenerator},
        default: AshEvents.AdvisoryLockKeyGenerator.Default,
        doc:
          "A module with the AshEvents.AdvisoryLockKeyGenerator-behaviour, that is expected to generate advisory lock keys when inserting events."
      ],
      advisory_lock_key_default: [
        type: {:or, [:integer, {:list, :integer}]},
        default: 2_147_483_647,
        doc:
          "The value to use when acquiring advisory locks during event inserts. Must be an integer or a list of two 32-bit integers."
      ],
      cloak_vault: [
        type: :atom,
        required: false,
        doc:
          "The vault module to use for encrypting and decrypting both the event data and metadata."
      ],
      record_id_type: [
        type: :any,
        doc:
          "The type of the primary key used by the system, which will be the type of the `record_id`-field on the events. Defaults to :uuid.",
        default: :uuid
      ]
    ],
    entities: [@persist_actor_primary_key],
    examples: [
      """
      event_log do
        clear_records_for_replay MyApp.Events.ClearAllRecords
        record_id_type :integer # (default is :uuid)
        persist_actor_primary_key :user_id, MyApp.Accounts.User
        persist_actor_primary_key :system_actor, MyApp.SystemActor, attribute_type: :string
      end
      """
    ]
  }

  use Spark.Dsl.Extension,
    transformers: [
      AshEvents.EventLog.Transformers.AddActions,
      AshEvents.EventLog.Transformers.AddAttributes,
      AshEvents.EventLog.Transformers.ValidatePersistActorPrimaryKey
    ],
    sections: [@event_log, @replay_overrides],
    verifiers: [AshEvents.EventLog.Verifiers.VerifyActorResources]
end

defmodule AshEvents.EventLog.Info do
  @moduledoc "Introspection helpers for `AshEvents.EventLog`"
  use Spark.InfoGenerator,
    extension: AshEvents.EventLog,
    sections: [:event_log, :replay_overrides]
end
