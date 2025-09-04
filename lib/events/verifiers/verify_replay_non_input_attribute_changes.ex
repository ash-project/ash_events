defmodule AshEvents.Events.Verifiers.VerifyReplayNonInputAttributeChanges do
  @moduledoc """
  Verifies that replay_non_input_attribute_changes configuration is valid.

  Checks that:
  - All action names reference existing actions on the resource
  - All values are either :force_change or :as_arguments
  """
  use Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    replay_config = AshEvents.Events.Info.events_replay_non_input_attribute_changes!(dsl_state)
    resource = Spark.Dsl.Verifier.get_persisted(dsl_state, :module)
    all_actions = Ash.Resource.Info.actions(dsl_state)
    all_action_names = Enum.map(all_actions, & &1.name)

    Enum.reduce_while(replay_config, :ok, fn {action_name, strategy}, acc ->
      cond do
        action_name not in all_action_names ->
          {:halt,
           {:error,
            Spark.Error.DslError.exception(
              message:
                "Action #{inspect(action_name)} in replay_non_input_attribute_changes does not exist on resource #{resource}",
              path: [:events, :replay_non_input_attribute_changes],
              module: resource
            )}}

        strategy not in [:force_change, :as_arguments] ->
          {:halt,
           {:error,
            Spark.Error.DslError.exception(
              message:
                "Invalid strategy #{inspect(strategy)} for action #{inspect(action_name)} in replay_non_input_attribute_changes. Must be either :force_change or :as_arguments",
              path: [:events, :replay_non_input_attribute_changes],
              module: resource
            )}}

        true ->
          {:cont, acc}
      end
    end)
  end
end
