defmodule AshEvents.EventResource.Transformers.AddAttributes do
  @moduledoc false
  use Spark.Dsl.Transformer

  def before?(_), do: true

  def transform(dsl) do
    {:ok, record_primary_id_type} =
      AshEvents.EventResource.Info.event_resource_record_id_type(dsl)

    persist_actor_ids = AshEvents.EventResource.Info.event_resource(dsl)

    dsl
    |> Ash.Resource.Builder.add_attribute(:id, :integer,
      primary_key?: true,
      writable?: false,
      generated?: true,
      allow_nil?: false
    )
    |> Ash.Resource.Builder.add_attribute(:record_id, record_primary_id_type, allow_nil?: false)
    |> Ash.Resource.Builder.add_attribute(:version, :integer, allow_nil?: false, default: 1)
    |> Ash.Resource.Builder.add_attribute(:metadata, :map,
      allow_nil?: false,
      default: %{},
      description: """
        Any relevant metadata you want to store with the event.

        Example: `%{source: "Signup form"}`
      """
    )
    |> Ash.Resource.Builder.add_attribute(:data, :map,
      allow_nil?: false,
      default: %{},
      description: """
      This is where the input arguments from the issued command gets stored.
      """
    )
    |> Ash.Resource.Builder.add_new_attribute(:occurred_at, :utc_datetime_usec,
      allow_nil?: false,
      default: &DateTime.utc_now/0
    )
    |> Ash.Resource.Builder.add_attribute(:ash_events_resource, :atom, allow_nil?: false)
    |> Ash.Resource.Builder.add_attribute(:ash_events_action, :atom, allow_nil?: false)
    |> Ash.Resource.Builder.add_attribute(:ash_events_action_type, :atom,
      allow_nil?: false,
      constraints: [one_of: [:create, :update, :destroy]]
    )
    |> then(fn dsl ->
      Enum.reduce(persist_actor_ids, dsl, fn persist_actor_id, dsl ->
        Ash.Resource.Builder.add_attribute(
          dsl,
          persist_actor_id.name,
          persist_actor_id.attribute_type,
          public?: persist_actor_id.public?,
          allow_nil?: persist_actor_id.allow_nil?
        )
      end)
    end)
  end
end
