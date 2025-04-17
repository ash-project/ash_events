defmodule AshEvents.EventLog.Transformers.ValidatePersistActorPrimaryKey do
  @moduledoc "Validates that when multiple persist_actor_primary_key options are defined that they all allow_nil? true"
  use Spark.Dsl.Transformer

  def transform(dsl_state) do
    with entities <- Spark.Dsl.Transformer.get_entities(dsl_state, [:event_log]),
         persist_actor_primary_keys when length(persist_actor_primary_keys) > 1 <-
           Enum.filter(entities, fn
             %AshEvents.EventLog.PersistActorPrimaryKey{} -> true
             _ -> false
           end),
         false <-
           Enum.all?(persist_actor_primary_keys, & &1.allow_nil?) do
      {:error, "when declaring multiple persist_actor_primary_key, they all must allow_nil?"}
    else
      _ ->
        {:ok, dsl_state}
    end
  end
end
