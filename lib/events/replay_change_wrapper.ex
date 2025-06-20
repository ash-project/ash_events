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
          action == cs.action.name and Enum.member?(modules, change_module)
        end)

      updated_cs = change_module.change(cs, arguments, ctx)

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
      change_module.change(cs, arguments, ctx)
    end
  end
end
