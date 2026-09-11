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
          |> raw_ciphertext()
          |> vault.decrypt!()
          |> Jason.decode!()
      end
    end)
  end

  def calculate([], _, _), do: []

  # Cloak ciphertext always starts with the reserved tag byte 1. Releases before
  # 0.8.0 stored the ciphertext base64-encoded, and base64 text can never start
  # with byte 1, so anything else is a legacy row that must be decoded first.
  defp raw_ciphertext(<<1, _::binary>> = ciphertext), do: ciphertext
  defp raw_ciphertext(legacy_base64), do: Base.decode64!(legacy_base64)
end
