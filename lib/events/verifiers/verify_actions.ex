# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Events.Verifiers.VerifyActions do
  @moduledoc """
  Verifies that action-related configuration is valid.

  Checks that:
  - only_actions and ignore_actions are mutually exclusive
  - All actions in only_actions, ignore_actions, current_action_versions, 
    and allowed_change_modules reference existing actions on the resource
  - Versions in current_action_versions are positive integers
  - Change modules in allowed_change_modules exist and implement Ash.Resource.Change
  """
  use Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    only_actions =
      case AshEvents.Events.Info.events_only_actions(dsl_state) do
        {:ok, list} -> list
        :error -> nil
      end

    ignore_actions = AshEvents.Events.Info.events_ignore_actions!(dsl_state)
    current_action_versions = AshEvents.Events.Info.events_current_action_versions!(dsl_state)
    {:ok, allowed_change_modules} = AshEvents.Events.Info.events_allowed_change_modules(dsl_state)

    resource = Spark.Dsl.Verifier.get_persisted(dsl_state, :module)
    all_actions = Ash.Resource.Info.actions(dsl_state)
    all_action_names = Enum.map(all_actions, & &1.name)

    with :ok <- verify_mutual_exclusivity(only_actions, ignore_actions, resource),
         :ok <- verify_only_actions_exist(only_actions, all_action_names, resource),
         :ok <- verify_ignore_actions_exist(ignore_actions, all_action_names, resource),
         :ok <-
           verify_current_action_versions(current_action_versions, all_action_names, resource) do
      verify_allowed_change_modules(allowed_change_modules, all_action_names, resource)
    end
  end

  defp verify_mutual_exclusivity(only_actions, ignore_actions, resource) do
    if only_actions != nil and not Enum.empty?(ignore_actions) do
      {:error,
       Spark.Error.DslError.exception(
         message:
           "only_actions and ignore_actions are mutually exclusive. Use one or the other, not both",
         path: [:events],
         module: resource
       )}
    else
      :ok
    end
  end

  defp verify_only_actions_exist(nil, _all_action_names, _resource), do: :ok

  defp verify_only_actions_exist(only_actions, all_action_names, resource) do
    invalid_actions = only_actions -- all_action_names

    if Enum.empty?(invalid_actions) do
      :ok
    else
      {:error,
       Spark.Error.DslError.exception(
         message:
           "Actions #{inspect(invalid_actions)} in only_actions do not exist on resource #{resource}",
         path: [:events, :only_actions],
         module: resource
       )}
    end
  end

  defp verify_ignore_actions_exist(ignore_actions, all_action_names, resource) do
    invalid_actions = ignore_actions -- all_action_names

    if Enum.empty?(invalid_actions) do
      :ok
    else
      {:error,
       Spark.Error.DslError.exception(
         message:
           "Actions #{inspect(invalid_actions)} in ignore_actions do not exist on resource #{resource}",
         path: [:events, :ignore_actions],
         module: resource
       )}
    end
  end

  defp verify_current_action_versions(current_action_versions, all_action_names, resource) do
    Enum.reduce_while(current_action_versions, :ok, fn {action_name, version}, acc ->
      cond do
        action_name not in all_action_names ->
          {:halt,
           {:error,
            Spark.Error.DslError.exception(
              message:
                "Action #{inspect(action_name)} in current_action_versions does not exist on resource #{resource}",
              path: [:events, :current_action_versions],
              module: resource
            )}}

        not is_integer(version) or version <= 0 ->
          {:halt,
           {:error,
            Spark.Error.DslError.exception(
              message:
                "Version #{inspect(version)} for action #{inspect(action_name)} in current_action_versions must be a positive integer",
              path: [:events, :current_action_versions],
              module: resource
            )}}

        true ->
          {:cont, acc}
      end
    end)
  end

  defp verify_allowed_change_modules(allowed_change_modules, all_action_names, resource) do
    Enum.reduce_while(allowed_change_modules, :ok, fn {action_name, change_modules}, acc ->
      if action_name in all_action_names do
        case verify_change_modules(change_modules, action_name, resource) do
          :ok -> {:cont, acc}
          error -> {:halt, error}
        end
      else
        {:halt,
         {:error,
          Spark.Error.DslError.exception(
            message:
              "Action #{inspect(action_name)} in allowed_change_modules does not exist on resource #{resource}",
            path: [:events, :allowed_change_modules],
            module: resource
          )}}
      end
    end)
  end

  defp verify_change_modules(change_modules, action_name, resource)
       when is_list(change_modules) do
    Enum.reduce_while(change_modules, :ok, fn change_module, acc ->
      case verify_single_change_module(change_module, action_name, resource) do
        :ok -> {:cont, acc}
        error -> {:halt, error}
      end
    end)
  end

  defp verify_change_modules(change_module, action_name, resource) do
    verify_single_change_module(change_module, action_name, resource)
  end

  defp verify_single_change_module(change_module, action_name, resource) do
    cond do
      not module_exists?(change_module) ->
        {:error,
         Spark.Error.DslError.exception(
           message:
             "Change module #{change_module} for action #{inspect(action_name)} in allowed_change_modules does not exist",
           path: [:events, :allowed_change_modules],
           module: resource
         )}

      not implements_change_behaviour?(change_module) ->
        {:error,
         Spark.Error.DslError.exception(
           message:
             "Change module #{change_module} for action #{inspect(action_name)} in allowed_change_modules does not implement Ash.Resource.Change",
           path: [:events, :allowed_change_modules],
           module: resource
         )}

      true ->
        :ok
    end
  end

  defp module_exists?(module) do
    Code.ensure_loaded?(module)
  rescue
    _ -> false
  end

  defp implements_change_behaviour?(module) do
    module.module_info(:attributes)
    |> Keyword.get(:behaviour, [])
    |> Enum.member?(Ash.Resource.Change)
  rescue
    _ -> false
  end
end
