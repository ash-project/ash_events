# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Events.ReplayChangeWrapper do
  @moduledoc false
  use Ash.Resource.Change

  def change(cs, opts, ctx) do
    %Ash.Resource.Change{change: {change_module, change_opts}} = opts[:change]

    ash_events_replay? = cs.context[:ash_events_replay?] || false

    if ash_events_replay? do
      {:ok, allowed_change_modules} =
        AshEvents.Events.Info.events_allowed_change_modules(cs.resource)

      is_allowed? =
        Enum.any?(allowed_change_modules, fn {action, modules} ->
          action == cs.action.name and Enum.member?(modules, change_module)
        end)

      updated_cs = run_change(cs, change_module, change_opts, ctx)

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
      run_change(cs, change_module, change_opts, ctx)
    end
  end

  defp run_change(cs, module, opts, ctx) do
    case module.init(opts) do
      {:ok, opts} ->
        opts =
          templated_opts(
            opts,
            cs.context[:private][:actor],
            cs.tenant,
            cs.arguments,
            cs.context,
            cs
          )

        module.change(cs, opts, ctx)

      {:error, error} ->
        Ash.Changeset.add_error(cs, error)
    end
  end

  defp templated_opts(opts, actor, tenant, arguments, context, changeset) do
    Ash.Expr.fill_template(
      opts,
      actor: actor,
      tenant: tenant,
      args: arguments,
      context: context,
      changeset: changeset
    )
  end
end
