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
    defstruct [:event_resource, :event_action, :version_prefix, :route_to]
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
      version_prefix: [
        type: :string,
        doc: """
        A prefix to match the event's version on. If set, the event will only be routed here
        if the prefix matches the beginning of the version string.
        """,
        required: true
      ]
    ],
    args: [:event_resource, :event_action, :version_prefix],
    entities: [route_to: [@route_to]]
  }

  @replay_overrides %Spark.Dsl.Section{
    name: :replay_overrides,
    entities: [@replay_override]
  }

  @belongs_to_actor %Spark.Dsl.Entity{
    name: :belongs_to_actor,
    describe: """
    Creates a belongs_to relationship for the actor resource. When creating a new event,
    if the actor on the action is set and matches the resource type, the event will be
    related to the actor. If your actors are polymorphic or varying types, declare a
    belongs_to_actor for each type.

    A reference is also created with `on_delete: :nilify` and `on_update: :update`

    If you need more complex relationships, set `define_attribute? false` and add
    the relationship via a mixin.

    If your actor is not a resource, add a mixin and with a change for all creates
    that sets the actor's to one your attributes.
    """,
    examples: [
      "belongs_to_actor :user, MyApp.Accounts.User"
    ],
    no_depend_modules: [:destination],
    target: AshEvents.EventResource.BelongsToActor,
    args: [:name, :destination],
    schema: AshEvents.EventResource.BelongsToActor.schema()
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
      record_id_type: [
        type: :any,
        doc: """
        The type of the primary key used by the system's projections/resources, which will be the
        type of the `record_id`-field on the events. Defaults to :uuid.
        """,
        default: :uuid
      ]
      # record_id_allow_nil?: [
      #  type: :boolean,
      #  doc: """
      #  If set to true, the event's record_id can be nilable. Default is false.
      #  """,
      #  default: true
      # ]
    ],
    entities: [@belongs_to_actor],
    examples: [
      """
      event_resource do
        create_accept [:some_custom_attribute]
        record_id_type :integer (default is :uuid)
        record_id_allow_nil? false (default is true)
      end
      """
    ]
  }

  use Spark.Dsl.Extension,
    transformers: [
      AshEvents.EventResource.Transformers.AddActions,
      AshEvents.EventResource.Transformers.AddAttributes,
      AshEvents.EventResource.Transformers.ValidateBelongsToActor
    ],
    sections: [@event_resource, @replay_overrides]
end

defmodule AshEvents.EventResource.Info do
  @moduledoc "Introspection helpers for `AshEvents.EventResource`"
  use Spark.InfoGenerator,
    extension: AshEvents.EventResource,
    sections: [:event_resource, :replay_overrides]
end
