# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EventLog.Calculations.Decrypt do
  @moduledoc false
  use Ash.Resource.Calculation

  def load(_, opts, _), do: [opts[:field]]

  def calculate([%resource{} | _] = records, opts, _context) do
    vault = AshEvents.EventLog.Info.event_log_cloak_vault!(resource)

    Enum.map(records, fn record ->
      record
      |> Map.get(opts[:field])
      |> case do
        nil ->
          nil

        value ->
          value
          |> Base.decode64!()
          |> vault.decrypt!()
          |> Jason.decode!()
      end
    end)
  end

  def calculate([], _, _), do: []
end
