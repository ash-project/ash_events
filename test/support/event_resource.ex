defmodule AshEvents.Test.Events.EventResource do
  use Ash.Resource,
    domain: AshEvents.Test.Events,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.EventResource]

  postgres do
    table "events"
    repo AshEvents.TestRepo
  end

  event_resource do
    belongs_to_actor :user, AshEvents.Test.Accounts.User
  end

  event_handlers do
    event_handler AshEvents.Test.Accounts.EventHandler, event_name_prefix: "accounts_"
  end

  actions do
    defaults [:read]
  end
end
