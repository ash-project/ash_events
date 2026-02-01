# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EventLog.Verifiers.VerifyClearRecordsForReplay do
  @moduledoc """
  Verifies that the clear_records_for_replay configuration is valid.

  Checks that:
  - The clear_records_for_replay module exists (if specified)
  - The clear_records_for_replay module implements the AshEvents.ClearRecordsForReplay behaviour
  """
  use Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    clear_records_module =
      case AshEvents.EventLog.Info.event_log_clear_records_for_replay(dsl_state) do
        {:ok, module} -> module
        :error -> nil
      end

    resource = Spark.Dsl.Verifier.get_persisted(dsl_state, :module)

    if clear_records_module do
      cond do
        not module_exists?(clear_records_module) ->
          {:error,
           Spark.Error.DslError.exception(
             message:
               "Module #{clear_records_module} specified in clear_records_for_replay does not exist",
             path: [:event_log, :clear_records_for_replay],
             module: resource
           )}

        not implements_behaviour?(clear_records_module, AshEvents.ClearRecordsForReplay) ->
          {:error,
           Spark.Error.DslError.exception(
             message:
               "Module #{clear_records_module} specified in clear_records_for_replay does not implement the AshEvents.ClearRecordsForReplay behaviour",
             path: [:event_log, :clear_records_for_replay],
             module: resource
           )}

        true ->
          :ok
      end
    else
      :ok
    end
  end

  defp module_exists?(module) do
    Code.ensure_loaded?(module)
  rescue
    _ -> false
  end

  defp implements_behaviour?(module, behaviour) do
    module.module_info(:attributes)
    |> Keyword.get(:behaviour, [])
    |> Enum.member?(behaviour)
  rescue
    _ -> false
  end
end
