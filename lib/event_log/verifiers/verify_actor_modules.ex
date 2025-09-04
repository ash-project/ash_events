defmodule AshEvents.EventLog.Verifiers.VerifyActorResources do
  @moduledoc """
  Verifies that persist_actor_primary_key entries reference valid Ash resources.

  Checks that:
  - The destination module is an Ash resource
  - The destination resource has a primary key attribute
  """
  use Spark.Dsl.Verifier

  def verify(dsl_state) do
    persist_actor_primary_keys = AshEvents.EventLog.Info.event_log(dsl_state)
    resource = Spark.Dsl.Verifier.get_persisted(dsl_state, :module)

    Enum.reduce_while(persist_actor_primary_keys, :ok, fn entry, _acc ->
      cond do
        not Ash.Resource.Info.resource?(entry.destination) ->
          {:halt,
           {:error,
            Spark.Error.DslError.exception(
              message:
                "Destination #{entry.destination} for persist_actor_primary_key in #{resource} must be an Ash resource",
              path: [:event_log],
              module: resource
            )}}

        Enum.empty?(Ash.Resource.Info.primary_key(entry.destination)) ->
          {:halt,
           {:error,
            Spark.Error.DslError.exception(
              message:
                "Destination #{entry.destination} for persist_actor_primary_key in #{resource} must have a primary key attribute",
              path: [:event_log],
              module: resource
            )}}

        true ->
          {:cont, :ok}
      end
    end)
  end
end
