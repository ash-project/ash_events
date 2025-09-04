if Code.ensure_loaded?(AshAuthentication) do
  defmodule AshEvents.AshAuthenticationActionValidators do
    @moduledoc false

    @behaviour AshAuthentication.Validations.ActionValidators

    alias Ash.Resource.Actions
    alias Spark.Error.DslError

    defdelegate validate_action_exists(dsl_state, action_name),
      to: AshAuthentication.Validations.Action

    defdelegate validate_action_argument_option(action, argument_name, field, values),
      to: AshAuthentication.Validations.Action

    defdelegate validate_action_has_argument(action, argument_name),
      to: AshAuthentication.Validations.Action

    @spec validate_action_has_change(Actions.action(), module) ::
            :ok | {:error, Exception.t()}
    def validate_action_has_change(action, change_module) do
      has_change? =
        action
        |> Map.get(:changes, [])
        |> Enum.map(&Map.get(&1, :change))
        |> Enum.reject(&is_nil/1)
        |> Enum.any?(fn {change_mod, ctx} ->
          if change_mod == AshEvents.Events.ReplayChangeWrapper do
            {wrapped_change_mod, _} = ctx[:change].change
            wrapped_change_mod == change_module
          else
            change_module == change_mod
          end
        end)

      if has_change?,
        do: :ok,
        else:
          {:error,
           DslError.exception(
             path: [:actions, :change],
             message:
               "The action `#{inspect(action.name)}` should have the `#{inspect(change_module)}` change present."
           )}
    end

    defdelegate validate_action_has_manual(action, manual_module),
      to: AshAuthentication.Validations.Action

    defdelegate validate_action_has_validation(action, validation_module),
      to: AshAuthentication.Validations.Action

    defdelegate validate_action_has_preparation(action, preparation_module),
      to: AshAuthentication.Validations.Action

    defdelegate validate_action_option(action, field, values),
      to: AshAuthentication.Validations.Action
  end
end
