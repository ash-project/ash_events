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

  defp build_generic_action(action, dsl, event_resource, new_action_name) do
    action_accept = Map.get(action, :accept) || []

    arguments =
      action_accept
      |> Enum.map(fn attr_name ->
        attr = Ash.Resource.Info.attribute(dsl, attr_name)

        allow_nil =
          cond do
            attr_name in action.allow_nil_input -> true
            attr_name in action.require_attributes -> false
            true -> attr.allow_nil?
          end

        %Ash.Resource.Actions.Argument{
          name: attr.name,
          allow_nil?: allow_nil,
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

    %Ash.Resource.Actions.Action{
      name: action.name,
      description: action.description,
      returns: :struct,
      constraints: [instance_of: dsl.persist.module],
      arguments: arguments,
      run:
        {AshEvents.PersistEvent,
         [
           event_resource: event_resource,
           action: new_action_name,
           on_success: action.on_success
         ]},
      transaction?: true
    }
  end

  defp build_action_impl_data(action) do
    action
    |> Map.from_struct()
    |> Map.drop([:type, :name, :reject, :on_success, :atomics])
    |> Map.update(:arguments, [], &Enum.concat(&1, [@metadata_arg]))
    |> Map.to_list()
    |> Enum.filter(fn {_k, v} -> v != nil end)
  end

  def add_create_actions(dsl, event_resource, commands) do
    Enum.reduce(commands, {:ok, dsl}, fn action, {:ok, dsl} ->
      action_impl_data = build_action_impl_data(action)
      action_impl_name = :"#{action.name}_ash_events_impl"

      generic_action =
        build_generic_action(action, dsl, event_resource, action_impl_name)

      dsl
      |> Spark.Dsl.Transformer.add_entity([:actions], generic_action)
      |> Ash.Resource.Builder.add_action(:create, action_impl_name, action_impl_data)
    end)
  end

  def add_update_actions(dsl, event_resource, commands, record_arg) do
    Enum.reduce(commands, {:ok, dsl}, fn action, {:ok, dsl} ->
      action_impl_data = build_action_impl_data(action)
      action_impl_name = :"#{action.name}_ash_events_impl"

      generic_action =
        build_generic_action(action, dsl, event_resource, action_impl_name)
        |> Map.update(:arguments, [], &Enum.concat(&1, [record_arg]))

      dsl
      |> Spark.Dsl.Transformer.add_entity([:actions], generic_action)
      |> Ash.Resource.Builder.add_action(:update, action_impl_name, action_impl_data)
    end)
  end

  def add_destroy_actions(dsl, event_resource, commands, record_arg) do
    Enum.reduce(commands, {:ok, dsl}, fn action, {:ok, dsl} ->
      action_impl_data = build_action_impl_data(action)
      action_impl_name = :"#{action.name}_ash_events_impl"

      generic_action =
        build_generic_action(action, dsl, event_resource, action_impl_name)
        |> Map.update(:arguments, [], &Enum.concat(&1, [record_arg]))

      dsl
      |> Spark.Dsl.Transformer.add_entity([:actions], generic_action)
      |> Ash.Resource.Builder.add_action(:destroy, action_impl_name, action_impl_data)
    end)
  end

  def transform(dsl) do
    event_resource = AshEvents.Commands.Resource.Info.commands_event_resource!(dsl)

    record_arg = %Ash.Resource.Actions.Argument{
      name: :record,
      allow_nil?: false,
      type: :struct,
      constraints: [instance_of: dsl.persist.module]
    }

    {:ok,
     dsl
     |> AshEvents.Commands.Resource.Info.commands()
     |> Enum.filter(&(Map.get(&1, :type) != nil))
     |> Enum.group_by(& &1.type)
     |> Map.put_new(:create, [])
     |> Map.put_new(:update, [])
     |> Map.put_new(:destroy, [])
     |> Enum.reduce_while(dsl, fn {type, commands}, dsl ->
       case type do
         :create ->
           add_create_actions(dsl, event_resource, commands)

         :update ->
           add_update_actions(dsl, event_resource, commands, record_arg)

         :destroy ->
           add_destroy_actions(dsl, event_resource, commands, record_arg)

         _ ->
           raise "Command type #{inspect(type)} not supported"
       end
       |> case do
         {:ok, dsl} -> {:cont, dsl}
         {:error, reason} -> {:halt, {:error, reason}}
       end
     end)}
  end
end
