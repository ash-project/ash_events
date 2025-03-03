defmodule AshEvents.CommandResource do
  defmodule Command do
    defstruct [
      :name,
      :description,
      :transaction?,
      :event_name,
      :event_version,
      :returns,
      :constrains,
      :before_dispatch,
      :after_dispatch,
      :code_interface?,
      arguments: []
    ]
  end

  @command %Spark.Dsl.Entity{
    name: :command,
    describe: """
    Declares a command action, which will generate an event when executed.

    Commands accept two arguments: `data`, which is the values that will be stored in the event,
    and acted upon by the event handlers, and `metadata`, which is additional information that
    can be stored with the event.
    The lifecycle of a command is as follows:

    1. The command is executed.
    2. The `before_dispatch` function is called, if defined. This function will receive the
       arguments passed to the command, and should return same arguments, possibly modified.
    3. The event is created and dispatched.
    4. The `after_dispatch` function is called, if defined. This function will receive the
       event that was created and dispatched, and its return value will also be the return
       value of the command.

    A command opens a transaction, and will rollback if an error occurs at any point.

    For commands with side-effects, or if you need to perform any additional
    logic before or after the command is executed, you can define `before_dispatch`
    and `after_dispatch` functions/modules.

    The actions on your read models should be entirely free of side-effects in order
    to enable replaying of events, so commands should be the only place where side-effects
    occur (or are scheduled) when using AshEvents.
    """,
    examples: [
      """
      command :update_user_details, :struct do
        event_name "accounts_user_details_updated"
        event_version "1.0"
        constraints instance_of: User

        after_dispatch fn created_event, opts ->
          Accounts.get_user_by_id(created_event.entity_id, opts)
        end
      end
      """
    ],
    target: Command,
    schema: [
      name: [
        type: :atom,
        doc: "The name of the command."
      ],
      description: [
        type: :string,
        doc: "A description of the command.",
        default: ""
      ],
      event_name: [
        type: :string,
        doc: "The name of the event to generate"
      ],
      event_version: [
        type: :string,
        doc: "The version of the event to generate"
      ],
      returns: [
        type: Ash.OptionsHelpers.ash_type(),
        doc: "The type of the data returned by the command."
      ],
      constraints: [
        type: :keyword_list,
        doc: """
        Constraints for the return type. See `Ash.Type` for more.
        """
      ],
      code_interface?: [
        type: :boolean,
        default: true,
        doc: """
        Whether to generate a code interface for this command. Defaults to true.
        """
      ],
      before_dispatch: [
        type:
          {:or,
           [
             {:spark_function_behaviour, Ash.Resource.Actions.Implementation,
              {Ash.Resource.Action.ImplementationFunction, 2}},
             {:spark, Reactor}
           ]}
      ],
      after_dispatch: [
        type:
          {:or,
           [
             {:spark_function_behaviour, Ash.Resource.Actions.Implementation,
              {Ash.Resource.Action.ImplementationFunction, 2}},
             {:spark, Reactor}
           ]}
      ]
    ],
    # entities: [arguments: [@command_argument]],
    args: [:name, {:optional, :returns}]
  }

  @commands %Spark.Dsl.Section{
    name: :commands,
    describe: """
    Defines the commands that can be executed.
    """,
    examples: [
      """
      commands do
        command :update_user_details, :struct do
          event_name "accounts_user_details_updated"
          event_version "1.0"
          constraints instance_of: User

          argument :given_name, :string, allow_nil?: false
          argument :family_name, :string, allow_nil?: false
          argument :email, :string, allow_nil?: false

          on_success fn created_event, opts ->
            {:ok, %User{}}
          end
        end
      end
      """
    ],
    schema: [
      event_resource: [
        type: {:behaviour, AshEvents.EventResource},
        required: true,
        doc: "The event resource that creates and stores events."
      ]
    ],
    entities: [@command]
  }

  use Spark.Dsl.Extension,
    transformers: [AshEvents.Commands.Resource.Transformers.AddActions],
    sections: [@commands]
end

defmodule AshEvents.Commands.Resource.Info do
  use Spark.InfoGenerator,
    extension: AshEvents.CommandResource,
    sections: [:commands]
end
