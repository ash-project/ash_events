defmodule AshEvents.CommandResource do
  defmodule CreateCommand do
    defstruct [
      :name,
      :primary?,
      :description,
      :error_handler,
      accept: nil,
      require_attributes: [],
      allow_nil_input: [],
      manual: nil,
      notifiers: [],
      touches_resources: [],
      action_select: nil,
      delay_global_validations?: false,
      skip_global_validations?: false,
      skip_unknown_inputs: [],
      upsert?: false,
      upsert_identity: nil,
      upsert_fields: nil,
      return_skipped_upsert?: false,
      upsert_condition: nil,
      arguments: [],
      changes: [],
      reject: [],
      metadata: [],
      transaction?: true,
      type: :create,
      on_success: nil
    ]
  end

  defmodule UpdateCommand do
    defstruct [
      :name,
      :primary?,
      :description,
      :error_handler,
      accept: nil,
      require_attributes: [],
      allow_nil_input: [],
      skip_unknown_inputs: [],
      manual: nil,
      manual?: false,
      require_atomic?: Application.compile_env(:ash, :require_atomic_by_default?, true),
      atomic_upgrade?: true,
      atomic_upgrade_with: nil,
      action_select: nil,
      notifiers: [],
      atomics: [],
      delay_global_validations?: false,
      skip_global_validations?: false,
      arguments: [],
      changes: [],
      reject: [],
      metadata: [],
      transaction?: true,
      touches_resources: [],
      type: :update,
      on_success: nil
    ]
  end

  defmodule DestroyCommand do
    defstruct [
      :name,
      :primary?,
      :soft?,
      :description,
      :error_handler,
      manual: nil,
      require_atomic?: Application.compile_env(:ash, :require_atomic_by_default?, true),
      skip_unknown_inputs: [],
      atomic_upgrade?: true,
      atomic_upgrade_with: nil,
      action_select: nil,
      arguments: [],
      touches_resources: [],
      delay_global_validations?: false,
      skip_global_validations?: false,
      notifiers: [],
      accept: nil,
      require_attributes: [],
      allow_nil_input: [],
      changes: [],
      reject: [],
      transaction?: true,
      metadata: [],
      type: :destroy,
      on_success: nil
    ]
  end

  @on_command_success [
    type:
      {:or,
       [
         {:spark_function_behaviour, Ash.Resource.Actions.Implementation,
          {Ash.Resource.Action.ImplementationFunction, 3}},
         {:spark, Reactor}
       ]},
    default: nil
  ]

  @action_change %Spark.Dsl.Entity{
    name: :change,
    describe: """
    A change to be applied to the changeset.

    See `Ash.Resource.Change` for more.
    """,
    examples: [
      "change relate_actor(:reporter)",
      "change {MyCustomChange, :foo}"
    ],
    no_depend_modules: [:change],
    target: Ash.Resource.Change,
    schema: Ash.Resource.Change.action_schema(),
    args: [:change]
  }

  @action_argument %Spark.Dsl.Entity{
    name: :argument,
    describe: """
    Declares an argument on the action
    """,
    examples: [
      "argument :password_confirmation, :string"
    ],
    target: Ash.Resource.Actions.Argument,
    args: [:name, :type],
    transform: {Ash.Type, :set_type_transformation, []},
    schema: Ash.Resource.Actions.Argument.schema()
  }

  @action_validate %Spark.Dsl.Entity{
    name: :validate,
    describe: """
    Declares a validation to be applied to the changeset.

    See `Ash.Resource.Validation.Builtins` or `Ash.Resource.Validation` for more.
    """,
    examples: [
      "validate changing(:email)"
    ],
    target: Ash.Resource.Validation,
    schema: Ash.Resource.Validation.action_schema(),
    no_depend_modules: [:validation],
    transform: {Ash.Resource.Validation, :transform, []},
    args: [:validation]
  }

  @create_command %Spark.Dsl.Entity{
    name: :create_command,
    describe: """
    Declares a command create action, which will generate an event when executed.
    """,
    target: CreateCommand,
    imports: [
      Ash.Resource.Change.Builtins,
      Ash.Resource.Validation.Builtins,
      Ash.Expr
    ],
    schema:
      Ash.Resource.Actions.Create.opt_schema() ++
        [
          version: [
            type: :integer,
            doc: """
            The version of the resulting event. If you have breaking changes in your
            input params, increment this.
            """
          ],
          on_success: @on_command_success
        ],
    entities: [
      changes: [
        @action_change,
        @action_validate
      ],
      arguments: [
        @action_argument
      ]
    ],
    args: [:name]
  }

  @update_command %Spark.Dsl.Entity{
    name: :update_command,
    describe: """
    Declares a command update action, which will generate an event when executed.
    """,
    imports: [
      Ash.Resource.Change.Builtins,
      Ash.Resource.Validation.Builtins,
      Ash.Expr
    ],
    target: UpdateCommand,
    schema:
      Ash.Resource.Actions.Update.opt_schema() ++
        [
          version: [
            type: :integer,
            doc: """
            The version of the resulting event. If you have breaking changes in your
            input params, increment this.
            """
          ],
          on_success: @on_command_success
        ],
    entities: [
      changes: [
        @action_change,
        @action_validate
      ],
      arguments: [
        @action_argument
      ]
    ],
    args: [:name]
  }

  @destroy_command %Spark.Dsl.Entity{
    name: :destroy_command,
    describe: """
    Declares a command destroy action, which will generate an event when executed.
    """,
    imports: [
      Ash.Resource.Change.Builtins,
      Ash.Resource.Validation.Builtins,
      Ash.Expr
    ],
    target: DestroyCommand,
    schema:
      Ash.Resource.Actions.Update.opt_schema() ++
        [
          version: [
            type: :integer,
            doc: """
            The version of the resulting event. If you have breaking changes in your
            input params, increment this.
            """
          ],
          on_success: @on_command_success
        ],
    entities: [
      changes: [
        @action_change,
        @action_validate
      ],
      arguments: [
        @action_argument
      ]
    ],
    args: [:name]
  }

  @commands %Spark.Dsl.Section{
    name: :commands,
    describe: """
    Defines the commands that can be executed.
    """,
    examples: [
      """
      """
    ],
    schema: [
      event_resource: [
        type: {:behaviour, AshEvents.EventResource},
        required: true,
        doc: "The event resource that creates and stores events."
      ]
    ],
    entities: [@create_command, @update_command, @destroy_command]
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
