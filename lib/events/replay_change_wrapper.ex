defmodule AshEvents.Events.ReplayChangeWrapper do
  @moduledoc false
  use Ash.Resource.Change

  def change(cs, opts, ctx) do
    %Ash.Resource.Change{change: {change_module, arguments}} = opts[:change]
    ash_events_replay? = cs.context[:ash_events_replay?] || false

    if ash_events_replay? do
      {:ok, allowed_change_modules} =
        AshEvents.Events.Info.events_allowed_change_modules(cs.resource)

      is_allowed? =
        Enum.any?(allowed_change_modules, fn {action, modules} ->
          :"#{action}_ash_events_orig_impl" == cs.action.name and
            Enum.member?(modules, change_module)
        end)

      updated_cs = process_change(cs, change_module, arguments, ctx)

      if is_allowed? do
        updated_cs
      else
        %{
          updated_cs
          | around_transaction: cs.around_transaction,
            before_transaction: cs.before_transaction,
            after_transaction: cs.after_transaction,
            around_action: cs.around_action,
            before_action: cs.before_action,
            after_action: cs.after_action
        }
      end
    else
      process_change(cs, change_module, arguments, ctx)
    end
  end

  defp process_change(cs, change_module, arguments, ctx) do
    if change_module == AshStateMachine.BuiltinChanges.TransitionState do
      original_action_name =
        cs.action.name
        |> to_string()
        |> String.trim("_ash_events_orig_impl")
        |> String.to_atom()

      renamed_action = Map.put(cs.action, :name, original_action_name)

      cs
      |> Map.put(:action, renamed_action)
      |> change_module.change(arguments, ctx)
      |> Map.put(:action, cs.action)
    else
      change_module.change(cs, arguments, ctx)
    end
  end
end
