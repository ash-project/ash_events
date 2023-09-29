defmodule AshEventSource do
  @event_source %Spark.Dsl.Section{
    name: :event_source,
    schema: [
      event_resource: [
        type: {:behaviour, Ash.Resource},
        required: true,
        doc: "The resource to use to store events."
      ]
    ]
  }

  @sections [@event_source]

  @transformers [
    AshEventSource.Transformers.RewriteActions
  ]

  use Spark.Dsl.Extension, transformers: @transformers, sections: @sections
end
