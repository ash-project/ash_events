defmodule AshEvents.Events.ReplayChangeWrapper do
  @moduledoc false
  use Ash.Resource.Change

  def change(cs, opts, ctx) do
    {type, change_module, opts} =
      case opts[:change] do
        %Ash.Resource.Change{change: {change_module, opts}} ->
          {:change, change_module, opts}

        %Ash.Resource.Validation{validation: {validation_module, opts}} ->
          {:validation, validation_module, opts}
      end

    ash_events_replay? = cs.context[:ash_events_replay?] || false

    if ash_events_replay? do
      {:ok, allowed_change_modules} =
        AshEvents.Events.Info.events_allowed_change_modules(cs.resource)

      is_allowed? =
        Enum.any?(allowed_change_modules, fn {action, modules} ->
          action == cs.action.name and Enum.member?(modules, change_module)
        end)

      updated_cs = run_module(cs, type, change_module, opts, ctx)

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
      run_module(cs, type, change_module, opts, ctx)
    end
  end

  defp run_module(cs, type, module, opts, ctx) do
    case type do
      :change ->
        module.change(cs, opts, ctx)

      :validation ->
        case module.validate(cs, opts, ctx) do
          :ok -> cs
          {:error, error} -> Ash.Changeset.add_error(cs, error)
        end
    end
  end
end
