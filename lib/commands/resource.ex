defmodule AshEvents.Commands.Resource do
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
      arguments: []
    ]
  end

  # @command_argument %Spark.Dsl.Entity{
  #   name: :argument,
  #   describe: """
  #   Declares an argument on the command action.
  #   """,
  #   examples: [
  #     "argument :password_confirmation, :string"
  #   ],
  #   target: Ash.Resource.Actions.Argument,
  #   args: [:name, :type],
  #   transform: {Ash.Type, :set_type_transformation, []},
  #   schema: Ash.Resource.Actions.Argument.schema()
  # }

  @command %Spark.Dsl.Entity{
    name: :command,
    describe: """
    Declares a command without any side-effects, besides updating the system's internal state.

    Since there are no side-effects to consider when executing this command, the event
    will be automatically created and dispatched for you, triggering the event handlers
    defined on your event resource to run and perform any updates to your projections/resources.
    """,
    examples: [
      """
      command :update_user_details, :struct do
        event_name "accounts_user_details_updated"
        event_version "1.0"
        constraints instance_of: User

        argument :given_name, :string, allow_nil?: false
        argument :family_name, :string, allow_nil?: false
        argument :email, :string, allow_nil?: false

        run fn input, opts, ctx ->
          {:ok, %User{}}
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
    extension: AshEvents.Commands.Resource,
    sections: [:commands]
end
