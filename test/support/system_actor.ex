defmodule AshEvents.EventLogs.SystemActor do
  @moduledoc false
  use Ash.Resource,
    domain: AshEvents.EventLogs

  attributes do
    attribute :name, :string, primary_key?: true, allow_nil?: false
    attribute :is_system_actor, :boolean, allow_nil?: false, default: true
  end
end
