defmodule AshEvents.Transformers.RewriteActions do
  @moduledoc "Rewrite each create, update and destroy action into event sourced actions"
  use Spark.Dsl.Transformer

  def after?(_), do: true

  def transform(dsl) do
    event_resource = AshEvents.Info.events_event_resource!(dsl)

    dsl
    |> Ash.Resource.Info.actions()
    |> Enum.filter(&(&1.type in [:create, :update, :destroy]))
    |> Enum.reduce({:ok, dsl}, fn action, {:ok, dsl} ->
      new_name = :"#{action.name}_implementation"
      copied_action = %{action | name: new_name}

      arguments =
        action.accept
        |> Enum.map(fn attr_name ->
          attr = Ash.Resource.Info.attribute(dsl, attr_name)

          %Ash.Resource.Actions.Argument{
            name: attr.name,
            allow_nil?: attr.allow_nil?,
            type: attr.type,
            constraints: attr.constraints,
            default: attr.default,
            description: attr.description,
            sensitive?: attr.sensitive?
          }
        end)

      arguments =
        action.arguments
        |> Enum.concat(arguments)
        |> Enum.uniq_by(& &1.name)

      action = %Ash.Resource.Actions.Action{
        name: action.name,
        description: action.description,
        returns: :atom,
        constraints: [one_of: [:success, :failure]],
        arguments: arguments,
        run: {AshEvents.PersistEvent, [event_resource: event_resource, action: new_name]},
        transaction?: true
      }

      {:ok,
       dsl
       |> Spark.Dsl.Transformer.replace_entity([:actions], action, &(&1.name == action.name))
       |> Spark.Dsl.Transformer.add_entity([:actions], copied_action)}
    end)
  end
end
