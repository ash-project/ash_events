defmodule AshEvents.Test.Events.SystemActor do
  use Ash.Resource,
    domain: AshEvents.Test.Events

  attributes do
    attribute :name, :string, primary_key?: true, allow_nil?: false
  end
end
