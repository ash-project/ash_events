# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Events.Verifiers.VerifyEventLog do
  @moduledoc """
  Verifies that the event_log configuration is valid.

  Checks that:
  - The event_log module is an Ash resource
  - The event_log resource uses the AshEvents.EventLog extension
  - A temporal resource's event_log sets `record_as_of?`
  """
  use Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    event_log_module = AshEvents.Events.Info.events_event_log!(dsl_state)
    resource = Spark.Dsl.Verifier.get_persisted(dsl_state, :module)

    cond do
      not Ash.Resource.Info.resource?(event_log_module) ->
        {:error,
         Spark.Error.DslError.exception(
           message: "Module #{event_log_module} specified in event_log is not an Ash resource",
           path: [:events, :event_log],
           module: resource
         )}

      not has_event_log_extension?(event_log_module) ->
        {:error,
         Spark.Error.DslError.exception(
           message:
             "Module #{event_log_module} specified in event_log does not use the AshEvents.EventLog extension",
           path: [:events, :event_log],
           module: resource
         )}

      Ash.Resource.Info.temporal?(dsl_state) and
          not AshEvents.EventLog.Info.event_log_record_as_of?(event_log_module) ->
        {:error,
         Spark.Error.DslError.exception(
           message:
             "#{inspect(resource)} is a temporal resource, but its event log #{inspect(event_log_module)} " <>
               "does not set `record_as_of?`, so its events could not record the application time " <>
               "of each write. Add `record_as_of? true` to the `event_log` section of " <>
               "#{inspect(event_log_module)}, and generate a migration for the `as_of` and " <>
               "`as_of_range` attributes it adds.",
           path: [:events, :event_log],
           module: resource
         )}

      true ->
        :ok
    end
  end

  defp has_event_log_extension?(module) do
    extensions = Spark.extensions(module)
    AshEvents.EventLog in extensions
  rescue
    _ -> false
  end
end
