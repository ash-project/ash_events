# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EventLogs do
  @moduledoc false
  use Ash.Domain

  resources do
    resource AshEvents.EventLogs.EventLog do
      define :replay_events, action: :replay
    end

    resource AshEvents.EventLogs.EventLogUuidV7 do
      define :replay_events_uuidv7, action: :replay
    end

    resource AshEvents.EventLogs.EventLogMissingClear do
      define :replay_events_missing_clear, action: :replay
    end

    resource AshEvents.EventLogs.EventLogCloaked do
      define :replay_events_cloaked, action: :replay
    end

    resource AshEvents.EventLogs.EventLogStateMachine do
      define :replay_events_state_machine, action: :replay
    end

    resource AshEvents.EventLogs.SystemActor
  end
end
