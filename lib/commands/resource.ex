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
      :on_success,
      :code_interface?,
      arguments: []
    ]
  end

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

  @create_command %Spark.Dsl.Entity{
    name: :create_command,
    describe: """
    Declares a command create action, which will generate an event when executed.
    """,
    target: CreateCommand,
    schema:
      Ash.Resource.Actions.Create.opt_schema() ++
        [
          event_name: [
            type: :string,
            doc: """
            The name of the event to generate.
            """
          ],
          version: [
            type: :string,
            doc: """
            The version of the resulting event. If you have breaking changes in your
            input params, increment this.
            """
          ],
          on_success: [
            type:
              {:or,
               [
                 {:spark_function_behaviour, Ash.Resource.Actions.Implementation,
                  {Ash.Resource.Action.ImplementationFunction, 2}},
                 {:spark, Reactor}
               ]},
            default: nil
          ]
        ],
    args: [:name, {:optional, :version}]
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
    entities: [@create_command]
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
