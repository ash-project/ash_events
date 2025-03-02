defmodule AshEvents.EventResource do
  @moduledoc """
    Extension to use on the Ash.Resource that will persist events.

    It will have the following automatically added to the resource:

    actions do
      create :create do
      accept [:name, :version, :entity_id, ]
      end
    end

    attributes do
      integer_primary_key :id

      attribute :name, :string do
        public? true
        allow_nil? false
      end

      attribute :version, :string do
        public? true
        allow_nil? false
      end

      attribute :occurred_at, :utc_datetime_usec do
        public? true
        allow_nil? false
      end

      attribute :entity_id, <entity_id_attribute_type> (default :uuid) do
        public? true
        allow_nil? <entity_id_allow_nil?>
      end

      attribute :data, :map do
        public? true
        allow_nil? false
      end

      attribute :metadata, :map do
        public? true
        allow_nil? false
      end
    end
  """
  defmodule EventHandlerEntry do
    defstruct [:module, :event_name_prefix]
  end

  @event_handler %Spark.Dsl.Entity{
    name: :event_handler,
    describe: """
    A module implementing the AshEvents.EventHandler-behaviour, which will be used to process
    events as they are created, and during an event log replay.
    """,
    examples: [
      """
      event_handler MyApp.SomeDomain.EventHandler do
        prefix "user_"
      end
      """
    ],
    target: AshEvents.EventResource.EventHandlerEntry,
    schema: [
      module: [
        type: {:behaviour, AshEvents.EventHandler},
        required: true
      ],
      event_name_prefix: [
        type: :string,
        doc: """
        If a prefix is set, the event handler will only receive events whose name matches the
        prefix. Without a prefix, the event handler will receive all events.

        Example: prefix `accounts_´ will match event `accounts_user_created`,
        but not `blog_comment_added`.
        """,
        required: false,
        default: ""
      ]
    ],
    args: [:module]
  }

  @event_handlers %Spark.Dsl.Section{
    name: :event_handlers,
    entities: [@event_handler]
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
      entity_id_type: [
        type: :any,
        doc: """
        The type of the primary key used by the system's projections/resources, which will be the
        type of the `entity_id`-field on the events. Defaults to :uuid.
        """,
        default: :uuid
      ]
      # entity_id_allow_nil?: [
      #  type: :boolean,
      #  doc: """
      #  If set to true, the event's entity_id can be nilable. Default is false.
      #  """,
      #  default: true
      # ]
    ],
    entities: [@belongs_to_actor],
    examples: [
      """
      event_resource do
        create_accept [:some_custom_attribute]
        entity_id_type :integer (default is :uuid)
        entity_id_allow_nil? false (default is true)
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
    sections: [@event_resource, @event_handlers]
end

defmodule AshEvents.EventResource.Info do
  @moduledoc "Introspection helpers for `AshEvents.EventResource`"
  use Spark.InfoGenerator,
    extension: AshEvents.EventResource,
    sections: [:event_resource, :event_handlers]
end
