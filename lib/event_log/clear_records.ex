# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.ClearRecordsForReplay do
  @moduledoc """
  Behaviour for clearing records from the event log.
  """
  defmacro __using__(_opts) do
    quote do
      @behaviour AshEvents.ClearRecordsForReplay
    end
  end

  @callback clear_records!(opts :: keyword()) ::
              :ok | {:error, reason :: term}
end
