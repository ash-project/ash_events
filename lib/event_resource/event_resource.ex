defmodule AshEvents.EventResource do
  @moduledoc """
    Extension to use on the Ash.Resource that will persist events.

    It will have the following automatically added to the resource:

    actions do
      create :create do
        accept [:name, :version, :record_id, :data, :metadata]
      end

      action :replay do
        argument :last_event_id, :integer, allow_nil?: true
      end
    end

    attributes do
      integer_primary_key :id

      attribute :version, :string do
        public? true
        allow_nil? false
      end

      attribute :occurred_at, :utc_datetime_usec do
        public? true
        allow_nil? false
      end

      attribute :record_id, <record_id_attribute_type> (default :uuid) do
        public? true
        allow_nil? <record_id_allow_nil?>
      end

      attribute :data, :map do
        public? true
        allow_nil? false
      end

      attribute :metadata, :map do
        public? true
        allow_nil? false
      end

      attribute :ash_events_resource, :atom do
        public? false
        allow_nil? false
      end

      attribute :ash_events_action, :atom do
        public? false
        allow_nil? false
      end
    end
  """

  defmodule ReplayOverride do
    defstruct [:event_resource, :event_action, :versions, :route_to]
  end

  defmodule RouteTo do
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
    describe: """
    Overrides the default event replay behavior for a specific resource action.
    """,
    examples: [
      """
      replay_override MyApp.Accounts.User, :create_ash_events_impl, "1." do
        route_to MyApp.Account.User, :create_v1
      end
      """
    ],
    target: ReplayOverride,
    schema: [
      event_resource: [
        type: :atom,
        required: true
      ],
      event_action: [
        type: :atom,
        required: true
      ],
      versions: [
        type: {:list, :integer},
        doc: """
        A list of event versions to match on. The event will only be routed here
        if the version of the event matches one of the listed versions.
        """,
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

  @persist_actor_id %Spark.Dsl.Entity{
    name: :persist_actor_id,
    describe: """
    Store the actor's id in the event.
    When creating a new event, if the actor on the action is set and matches the resource type,
    it's id will be stored in the declared field. If your actors are polymorphic or varying
    types, declare a persist_actor_id for each type.
    """,
    examples: [
      "persist_actor_id_id :user_id, MyApp.Accounts.User"
    ],
    no_depend_modules: [:destination],
    target: AshEvents.EventResource.PersistActorId,
    args: [:name, :destination],
    schema: AshEvents.EventResource.PersistActorId.schema()
  }

  @event_resource %Spark.Dsl.Section{
    name: :event_resource,
    schema: [
      create_accept: [
        type: {:list, :atom},
        doc: """
        A list of extra attributes to be accepted by the create action.

        Any custom attributes you define on this resource that you want to be hydrated
        when an event is created, should be added here.
        """,
        default: []
      ],
      clear_records_for_replay: [
        type: {:behaviour, AshEvents.ClearRecordsForReplay},
        required: false,
        doc: """
        A module with the AshEvents.ClearRecords-behaviour, that is expected to clear all
        records before an event replay.
        """
      ],
      record_id_type: [
        type: :any,
        doc: """
        The type of the primary key used by the system, which will be the type of the
        `record_id`-field on the events. Defaults to :uuid. Note that this means that
        all your resources you want to create events for must have a primary key of
        this type.
        """,
        default: :uuid
      ]
    ],
    entities: [@persist_actor_id],
    examples: [
      """
      event_resource do
        record_id_type :integer (default is :uuid)
      end
      """
    ]
  }

  use Spark.Dsl.Extension,
    transformers: [
      AshEvents.EventResource.Transformers.AddActions,
      AshEvents.EventResource.Transformers.AddAttributes,
      AshEvents.EventResource.Transformers.ValidatePersistActorId
    ],
    sections: [@event_resource, @replay_overrides]
end

defmodule AshEvents.EventResource.Info do
  @moduledoc "Introspection helpers for `AshEvents.EventResource`"
  use Spark.InfoGenerator,
    extension: AshEvents.EventResource,
    sections: [:event_resource, :replay_overrides]
end
