defmodule AshEvents.Commands.Resource.Transformers.AddActions do
  @moduledoc false
  use Spark.Dsl.Transformer

  @metadata_arg %Ash.Resource.Actions.Argument{
    name: :event_metadata,
    allow_nil?: false,
    type: :map,
    default: %{},
    description: "The metadata to store with the event."
  }

  def add_create_actions(dsl, event_resource, commands) do
    Enum.reduce(commands, {:ok, dsl}, fn action, {:ok, dsl} ->
      action_impl_data =
        action
        |> Map.from_struct()
        |> Map.drop([:type, :name, :reject, :on_success])
        |> Map.update(
          :arguments,
          [],
          &Enum.concat(&1, [@metadata_arg])
        )
        |> Map.to_list()
        |> Enum.filter(fn {k, v} -> v != nil end)

      action_impl_name = :"#{action.name}_ash_events_impl"

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
        |> Enum.concat([@metadata_arg])
        |> Enum.concat(arguments)
        |> Enum.uniq_by(& &1.name)

      generic_action = %Ash.Resource.Actions.Action{
        name: action.name,
        description: action.description,
        returns: :struct,
        constraints: [instance_of: dsl.persist.module],
        arguments: arguments,
        run:
          {AshEvents.PersistEvent,
           [
             event_resource: event_resource,
             action: action_impl_name,
             on_success: action.on_success
           ]},
        transaction?: true
      }

      dsl
      |> Spark.Dsl.Transformer.add_entity([:actions], generic_action)
      |> Ash.Resource.Builder.add_action(:create, action_impl_name, action_impl_data)
    end)
  end

  def add_update_actions(dsl, event_resource, commands) do
    {:ok, dsl}
  end

  def add_destroy_actions(dsl, event_resource, commands) do
    {:ok, dsl}
  end

  def transform(dsl) do
    event_resource = AshEvents.Commands.Resource.Info.commands_event_resource!(dsl)

    dsl
    |> AshEvents.Commands.Resource.Info.commands()
    |> Enum.filter(&(Map.get(&1, :type) != nil))
    |> Enum.group_by(& &1.type)
    |> Map.put_new(:read, [])
    |> Map.put_new(:create, [])
    |> Map.put_new(:update, [])
    |> Map.put_new(:destroy, [])
    |> Enum.reduce_while(dsl, fn {type, commands}, dsl ->
      case type do
        :create ->
          case add_create_actions(dsl, event_resource, commands) do
            {:error, reason} -> {:halt, {:error, reason}}
            dsl -> {:cont, dsl}
          end

        :update ->
          case add_update_actions(dsl, event_resource, commands) do
            {:ok, dsl} -> {:cont, dsl}
            {:error, reason} -> {:halt, {:error, reason}}
          end

        :destroy ->
          case add_destroy_actions(dsl, event_resource, commands) do
            {:ok, dsl} -> {:cont, dsl}
            {:error, reason} -> {:halt, {:error, reason}}
          end

        _ ->
          {:cont, dsl}
      end
    end)
  end
end
