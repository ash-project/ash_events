# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EventLog.Verifiers.VerifyPublicAttributes do
  @moduledoc """
  Verifies that public_fields configuration contains valid attribute names.

  Checks that:
  - When public_fields is a list, all entries are valid attribute names
  - When public_fields is :all, no validation is needed
  """
  use Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    public_fields = AshEvents.EventLog.Info.event_log_public_fields!(dsl_state)
    resource = Spark.Dsl.Verifier.get_persisted(dsl_state, :module)

    case public_fields do
      :all ->
        :ok

      [] ->
        :ok

      list when is_list(list) ->
        # Get canonical AshEvents fields and persist_actor_primary_key fields
        ash_events_fields = AshEvents.EventLog.Transformers.AddAttributes.ash_events_fields()
        persist_actor_primary_keys = AshEvents.EventLog.Info.event_log(dsl_state)
        actor_field_names = Enum.map(persist_actor_primary_keys, & &1.name)

        valid_field_names = ash_events_fields ++ actor_field_names

        # Check for invalid field names
        invalid_names = Enum.reject(list, fn name -> name in valid_field_names end)

        if Enum.empty?(invalid_names) do
          :ok
        else
          {:error,
           Spark.Error.DslError.exception(
             message:
               "public_fields contains invalid field names: #{inspect(invalid_names)}. " <>
                 "Valid AshEvents field names are: #{inspect(Enum.sort(valid_field_names))}",
             path: [:event_log, :public_fields],
             module: resource
           )}
        end
    end
  end
end
