defmodule AshEvents.Events do
  @events %Spark.Dsl.Section{
    name: :events,
    describe: """
    Sets up the resource.
    """,
    examples: [
      """
      """
    ],
    schema: [
      event_log: [
        type: {:behaviour, AshEvents.EventLog},
        required: true,
        doc: "The event-log resource that creates and stores events."
      ],
      ignore_actions: [
        type: {:list, :atom},
        default: [],
        doc: "A list of actions that should not have events created when run."
      ],
      current_action_versions: [
        type: :keyword_list,
        doc:
          "A keyword list of action versions. This will set the version in the created event when the actions are run. Example: [create: 2, update: 3, destroy: 2]",
        default: []
      ]
    ]
  }

  use Spark.Dsl.Extension,
    transformers: [AshEvents.Events.Transformers.AddActions],
    sections: [@events]
end

defmodule AshEvents.Events.Info do
  use Spark.InfoGenerator,
    extension: AshEvents.Events,
    sections: [:events]
end
