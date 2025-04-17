defmodule AshEvents.Events.Transformers.AddActions do
  @moduledoc false
  alias AshEvents.Helpers
  use Spark.Dsl.Transformer

  def after?(_), do: true

  @metadata_arg %Ash.Resource.Actions.Argument{
    name: :ash_events_metadata,
    allow_nil?: true,
    type: :map,
    default: %{},
    description: "The metadata to store with the event."
  }

  def transform(dsl) do
    event_log_resource = AshEvents.Events.Resource.Info.events_event_log!(dsl)
    ignored = AshEvents.Events.Resource.Info.events_ignore_actions!(dsl)

    actions =
      Ash.Resource.Info.actions(dsl)
      |> Enum.reject(fn action ->
        action.name in ignored or action.type not in [:create, :update, :destroy]
      end)

    Enum.reduce(actions, {:ok, dsl}, fn action, {:ok, dsl} ->
      original_action_name = Helpers.build_original_action_name(action.name)
      original_action = %{action | name: original_action_name, primary?: false}

      manual_action_changes =
        action.changes ++
          [
            %Ash.Resource.Change{
              change: {AshEvents.Events.RemoveLifecycleHooksChange, []},
              on: nil,
              only_when_valid?: false,
              description: nil,
              always_atomic?: false,
              where: []
            }
          ]

      manual_module =
        case action.type do
          :create -> AshEvents.CreateActionWrapper
          :update -> AshEvents.UpdateActionWrapper
          :destroy -> AshEvents.DestroyActionWrapper
        end

      manual_arguments = action.arguments ++ [@metadata_arg]

      manual_action =
        %{
          action
          | manual:
              {manual_module,
               [
                 action: action.name,
                 event_log: event_log_resource
               ]},
            primary?: action.primary?,
            arguments: manual_arguments,
            changes: manual_action_changes
        }
        |> then(fn action ->
          case action.type do
            :update -> Map.put(action, :require_atomic?, false)
            :destroy -> Map.merge(action, %{require_atomic?: false, return_destroyed?: true})
            _ -> action
          end
        end)

      {:ok,
       dsl
       |> Spark.Dsl.Transformer.replace_entity(
         [:actions],
         manual_action,
         &(&1.name == action.name)
       )
       |> Spark.Dsl.Transformer.add_entity([:actions], original_action)}
    end)
  end
end
