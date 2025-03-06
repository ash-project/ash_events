defmodule AshEvents.EventResource.Transformers.ValidatePersistActorId do
  @moduledoc "Validates that when multiple persist_actor_id options are defined that they all allow_nil? true"
  use Spark.Dsl.Transformer

  def transform(dsl_state) do
    with entities <- Spark.Dsl.Transformer.get_entities(dsl_state, [:event_resource]),
         persist_actor_ids when length(persist_actor_ids) > 1 <-
           Enum.filter(entities, fn
             %AshEvents.EventResource.PersistActorId{} -> true
             _ -> false
           end),
         false <-
           Enum.all?(persist_actor_ids, & &1.allow_nil?) do
      {:error, "when declaring multiple persist_actor_ids, they all must allow_nil?"}
    else
      _ ->
        {:ok, dsl_state}
    end
  end
end
