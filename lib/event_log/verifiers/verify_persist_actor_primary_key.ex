# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EventLog.Verifiers.VerifyPersistActorPrimaryKey do
  @moduledoc """
  Verifies that when multiple persist_actor_primary_key options are defined,
  they all have allow_nil? set to true.

  This ensures that event logs can handle cases where multiple actor types
  might be stored, but only one is relevant for any given event.
  """
  use Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    persist_actor_primary_keys =
      Spark.Dsl.Transformer.get_entities(dsl_state, [:event_log])
      |> Enum.filter(fn
        %AshEvents.EventLog.PersistActorPrimaryKey{} -> true
        _ -> false
      end)

    if length(persist_actor_primary_keys) > 1 do
      case Enum.all?(persist_actor_primary_keys, & &1.allow_nil?) do
        true ->
          :ok

        false ->
          resource = Spark.Dsl.Verifier.get_persisted(dsl_state, :module)

          {:error,
           Spark.Error.DslError.exception(
             message:
               "When declaring multiple persist_actor_primary_key options, they all must have allow_nil? set to true",
             path: [:event_log],
             module: resource
           )}
      end
    else
      :ok
    end
  end
end
