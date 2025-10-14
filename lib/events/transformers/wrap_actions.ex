# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Events.Transformers.WrapActions do
  @moduledoc false
  use Spark.Dsl.Transformer

  def after?(_), do: true

  # sobelow_skip ["DOS.BinToAtom"]
  def transform(dsl) do
    event_log_resource = AshEvents.Events.Info.events_event_log!(dsl)

    advisory_lock_key_generator =
      AshEvents.EventLog.Info.event_log_advisory_lock_key_generator!(event_log_resource)

    advisory_lock_key_default =
      AshEvents.EventLog.Info.event_log_advisory_lock_key_default!(event_log_resource)

    only_actions =
      case AshEvents.Events.Info.events_only_actions(dsl) do
        {:ok, list} -> list
        :error -> nil
      end

    ignored = AshEvents.Events.Info.events_ignore_actions!(dsl)
    action_versions = AshEvents.Events.Info.events_current_action_versions!(dsl)
    resource = Spark.Dsl.Verifier.get_persisted(dsl, :module)
    all_actions = Ash.Resource.Info.actions(dsl)

    event_actions =
      if only_actions do
        all_actions
        |> Enum.filter(&(&1.name in only_actions))
      else
        all_actions
        |> Enum.reject(&(&1.name in ignored or &1.type not in [:create, :update, :destroy]))
      end

    if only_actions do
      Enum.each(event_actions, fn action ->
        if action.type not in [:create, :update, :destroy] do
          raise(
            "Action :#{action.name} on #{resource} is not a create, update, or destroy action, and cannot be used in event logs."
          )
        end
      end)
    end

    action_version_names = Keyword.keys(action_versions)

    Enum.each(action_version_names, fn action_name ->
      if action_name in ignored do
        raise(
          "Action :#{action_name} in #{resource} is listed in ignore_actions, but also has an action version defined."
        )
      end

      if only_actions != nil and action_name not in only_actions do
        raise(
          "Action :#{action_name} in #{resource} is listed in action_versions, but not in only_actions."
        )
      end
    end)

    store_changeset_params = %Ash.Resource.Change{
      change: {AshEvents.Events.Changes.StoreChangesetParams, []},
      on: nil,
      only_when_valid?: false,
      description: nil,
      always_atomic?: false,
      where: []
    }

    replay_config = AshEvents.Events.Info.events_replay_non_input_attribute_changes!(dsl)

    apply_changed_attributes = %Ash.Resource.Change{
      change: {AshEvents.Events.Changes.ApplyChangedAttributes, [replay_config: replay_config]},
      on: nil,
      only_when_valid?: false,
      description: nil,
      always_atomic?: false,
      where: []
    }

    Enum.reduce(event_actions, {:ok, dsl}, fn action, {:ok, dsl} ->
      wrapped_changes =
        Enum.map(action.changes, fn change ->
          case change do
            %Ash.Resource.Validation{} = validation ->
              %Ash.Resource.Change{
                change:
                  {AshEvents.Events.ReplayValidationWrapper,
                   [
                     validation: validation,
                     message: validation.message
                   ]},
                on: validation.on,
                only_when_valid?: validation.only_when_valid?,
                description: validation.description,
                always_atomic?: false,
                where: validation.where || []
              }

            %Ash.Resource.Change{} = change ->
              %Ash.Resource.Change{
                change: {AshEvents.Events.ReplayChangeWrapper, [change: change]},
                on: change.on,
                only_when_valid?: change.only_when_valid?,
                description: change.description,
                always_atomic?: change.always_atomic?,
                where: change.where || []
              }
          end
        end)

      manual_module =
        case action.type do
          :create -> AshEvents.CreateActionWrapper
          :update -> AshEvents.UpdateActionWrapper
          :destroy -> AshEvents.DestroyActionWrapper
        end

      manual_action =
        %{
          action
          | manual:
              {manual_module,
               [
                 action: action.name,
                 event_log: event_log_resource,
                 version: Keyword.get(action_versions, action.name, 1),
                 advisory_lock_key_generator: advisory_lock_key_generator,
                 advisory_lock_key_default: advisory_lock_key_default
               ]},
            primary?: action.primary?,
            arguments: action.arguments,
            changes: [store_changeset_params | wrapped_changes] ++ [apply_changed_attributes]
        }
        |> then(fn action ->
          case action.type do
            :create -> Map.put(action, :upsert?, action.upsert?)
            :update -> Map.put(action, :require_atomic?, false)
            :destroy -> Map.merge(action, %{require_atomic?: false, return_destroyed?: true})
            _ -> action
          end
        end)

      {:ok, dsl_with_main_action} =
        {:ok,
         Spark.Dsl.Transformer.replace_entity(
           dsl,
           [:actions],
           manual_action,
           &(&1.name == action.name)
         )}

      if action.type == :create and action.upsert? do
        replay_update_action_name = :"ash_events_replay_#{action.name}_update"

        replay_update_action = %Ash.Resource.Actions.Update{
          name: replay_update_action_name,
          type: :update,
          accept: action.accept,
          arguments: action.arguments,
          primary?: false,
          description: "Auto-generated update action for replaying #{action.name} upsert events",
          require_atomic?: false,
          manual: nil,
          changes: [],
          touches_resources: [],
          transaction?: nil,
          metadata: [],
          delay_global_validations?: false
        }

        {:ok,
         Spark.Dsl.Transformer.add_entity(
           dsl_with_main_action,
           [:actions],
           replay_update_action
         )}
      else
        {:ok, dsl_with_main_action}
      end
    end)
  end
end
