defmodule AshEvents.EventResource.Transformers.AddActions do
  @moduledoc false
  use Spark.Dsl.Transformer

  @add_destroy? Application.compile_env(:ash_events, :add_event_resource_destroy?) || false

  @event_arguments [
    %Ash.Resource.Actions.Argument{
      name: :name,
      allow_nil?: false,
      type: :string,
      description: "The event name.",
      sensitive?: false
    },
    %Ash.Resource.Actions.Argument{
      name: :version,
      allow_nil?: false,
      type: :string,
      description: "The event name.",
      sensitive?: false
    },
    %Ash.Resource.Actions.Argument{
      name: :entity_id,
      allow_nil?: false,
      type: :string,
      description: "The event name.",
      sensitive?: false
    },
    %Ash.Resource.Actions.Argument{
      name: :metadata,
      allow_nil?: false,
      type: :map,
      default: %{},
      description: "The metadata to store with the event.",
      sensitive?: false
    },
    %Ash.Resource.Actions.Argument{
      name: :data,
      allow_nil?: false,
      type: :map,
      default: %{},
      description: "The event data.",
      sensitive?: false
    }
  ]

  def transform(dsl) do
    {:ok, extra_create_accepts} = AshEvents.EventResource.Info.event_resource_create_accept(dsl)

    handlers = AshEvents.EventResource.Info.event_handlers(dsl)

    dsl
    |> Ash.Resource.Builder.add_action(:create, :create,
      accept: Enum.uniq([:name, :version, :data, :metadata, :entity_id] ++ extra_create_accepts)
    )
    |> Ash.Resource.Builder.add_action(:action, :create_and_dispatch,
      transaction?: true,
      arguments: @event_arguments,
      returns: :map,
      run: {AshEvents.EventResource.Actions.CreateAndDispatch, [handlers: handlers]}
    )
    |> Ash.Resource.Builder.add_action(:action, :replay,
      arguments: [],
      run: {AshEvents.EventResource.Actions.Replay, [handlers: handlers]}
    )
    |> then(fn result ->
      if @add_destroy? do
        result
        |> Ash.Resource.Builder.add_action(:destroy, :destroy, primary?: true)
      else
        result
      end
    end)
  end
end
