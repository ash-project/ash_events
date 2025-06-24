defmodule AshEvents.Events do
  @moduledoc """
  Defines the events section for a resource.
  """
  @events %Spark.Dsl.Section{
    name: :events,
    examples: [
      """
      events do
        event_log MyApp.Events.EventLog
        ignore_actions [:create_old_v1, :update_old_v1, :update_old_v2, :destroy_old_v1]
        current_action_versions create: 2, update: 3, destroy: 2
      end
      """,
      """
      events do
        event_log MyApp.Events.EventLog
        only_actions [:create, :update, :destroy]
        current_action_versions create: 2, update: 3, destroy: 2
      end
      """
    ],
    schema: [
      event_log: [
        type: {:behaviour, AshEvents.EventLog},
        required: true,
        doc: "The event-log resource that creates and stores events."
      ],
      only_actions: [
        type: {:list, :atom},
        doc:
          "A list of actions that should be the only actions that have events created when run."
      ],
      ignore_actions: [
        type: {:list, :atom},
        default: [],
        doc: "A list of actions that should not have events created when run."
      ],
      current_action_versions: [
        type: :keyword_list,
        doc:
          "A keyword list of action versions. This will be used to set the version in the created events when the actions are run. Version will default to 1 for all actions that are not listed here.",
        default: []
      ],
      allowed_change_modules: [
        type: :keyword_list,
        doc:
          "A keyword list of action names and whitelisted change modules that should not be removed during event replay.",
        default: []
      ],
      create_timestamp: [
        type: :atom,
        doc: "The name of the create timestamp attribute on the resource",
        default: nil
      ],
      update_timestamp: [
        type: :atom,
        doc: "The name of the update timestamp attribute on the resource",
        default: nil
      ]
    ]
  }

  use Spark.Dsl.Extension,
    transformers: [AshEvents.Events.Transformers.AddActions],
    sections: [@events]
end

defmodule AshEvents.Events.Info do
  @moduledoc """
    @moduledoc "Introspection helpers for `AshEvents.Events`"
  """
  use Spark.InfoGenerator,
    extension: AshEvents.Events,
    sections: [:events]
end
