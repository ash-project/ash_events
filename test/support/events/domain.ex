defmodule AshEvents.Test.Events do
  @moduledoc false
  use Ash.Domain

  resources do
    resource AshEvents.Test.Events.EventLog do
      define :replay_events, action: :replay
    end

    resource AshEvents.Test.Events.EventLogUuidV7 do
      define :replay_events_uuidv7, action: :replay
    end

    resource AshEvents.Test.Events.EventLogMissingClear do
      define :replay_events_missing_clear, action: :replay
    end

    resource AshEvents.Test.Events.SystemActor
  end
end
