defmodule AshEvents do
  @events %Spark.Dsl.Section{
    name: :events,
    schema: [
      event_resource: [
        type: {:behaviour, Ash.Resource},
        required: true,
        doc: "The resource to use to store events."
      ],
      style: [
        type: {:one_of, [:event_sourced, :event_driven]},
        default: :event_driven,
        doc: "Which style of event architecture you want. See the getting started guide for more."
      ]
    ]
  }

  @sections [@events]

  @transformers [
    AshEvents.Transformers.RewriteActions
  ]

  use Spark.Dsl.Extension, transformers: @transformers, sections: @sections
end
