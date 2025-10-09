# SPDX-FileCopyrightText: 2024 Torkild G. Kjevik
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
