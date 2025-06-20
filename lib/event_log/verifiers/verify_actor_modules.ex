defmodule AshEvents.EventLog.Verifiers.VerifyActorResources do
  @moduledoc false
  use Spark.Dsl.Verifier

  def verify(dsl_state) do
    # Access the final DSL state
    persist_actor_primary_keys = AshEvents.EventLog.Info.event_log(dsl_state)

    Enum.reduce(persist_actor_primary_keys, :ok, fn entry, acc ->
      if Ash.Resource.Info.resource?(entry.destination) do
        acc
      else
        resource = Spark.Dsl.Verifier.get_persisted(dsl_state, :module)

        {:error,
         Spark.Error.DslError.exception(
           message:
             "Destination #{entry.destination} for persist_actor_primary_key in #{resource} must be an Ash-resource",
           path: [:event_log],
           module: Spark.Dsl.Verifier.get_persisted(dsl_state, :module)
         )}
      end
    end)
  end
end
