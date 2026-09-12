# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Events.ReplayValidationWrapper do
  @moduledoc """
  Specialized wrapper for validations that preserves custom messages during event tracking.

  This wrapper ensures that custom validation messages are preserved when using AshEvents,
  while still allowing for replay-specific behavior during event replay.

  `before_action?: true` on the wrapped validation is honoured outside of replay:
  the validation is registered as a `before_action` hook instead of running
  inline, matching `Ash.Changeset`'s own handling. During replay the validation
  keeps running inline, because a hook registered by a validation that is not in
  `allowed_change_modules` is discarded below and the validation would silently
  never run.
  """
  use Ash.Resource.Change

  def change(changeset, opts, context) do
    validation = opts[:validation]
    custom_message = opts[:message]

    validation_module =
      case validation do
        %Ash.Resource.Validation{validation: {module, _opts}} -> module
        %Ash.Resource.Validation{module: module} -> module
        _ -> nil
      end

    validation_opts =
      case validation do
        %Ash.Resource.Validation{validation: {_module, opts}} -> opts
        %Ash.Resource.Validation{opts: opts} -> opts
        _ -> []
      end

    ash_events_replay? = changeset.context[:ash_events_replay?] || false

    if ash_events_replay? do
      {:ok, allowed_change_modules} =
        AshEvents.Events.Info.events_allowed_change_modules(changeset.resource)

      is_allowed? =
        Enum.any?(allowed_change_modules, fn {action, modules} ->
          action == changeset.action.name and Enum.member?(modules, validation_module)
        end)

      updated_changeset =
        run_validation(changeset, validation_module, validation_opts, context, custom_message)

      if is_allowed? do
        updated_changeset
      else
        %{
          updated_changeset
          | around_transaction: changeset.around_transaction,
            before_transaction: changeset.before_transaction,
            after_transaction: changeset.after_transaction,
            around_action: changeset.around_action,
            before_action: changeset.before_action,
            after_action: changeset.after_action
        }
      end
    else
      maybe_before_action(
        changeset,
        validation,
        validation_module,
        validation_opts,
        context,
        custom_message
      )
    end
  end

  defp maybe_before_action(
         changeset,
         %Ash.Resource.Validation{before_action?: true} = validation,
         validation_module,
         validation_opts,
         context,
         custom_message
       ) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      # Re-checked here rather than relying on the generated change's
      # `only_when_valid?`, which Ash evaluates before the change runs. This
      # mirrors `Ash.Changeset.validate/5`, which re-checks it inside the hook.
      if validation.only_when_valid? and not changeset.valid? do
        changeset
      else
        run_validation(changeset, validation_module, validation_opts, context, custom_message)
      end
    end)
  end

  defp maybe_before_action(
         changeset,
         _validation,
         validation_module,
         validation_opts,
         context,
         custom_message
       ) do
    run_validation(changeset, validation_module, validation_opts, context, custom_message)
  end

  defp run_validation(changeset, validation_module, validation_opts, context, custom_message) do
    validation_context = validation_context(context, custom_message)

    case validation_module.init(validation_opts) do
      {:ok, initialized_opts} ->
        templated_opts =
          templated_opts(
            initialized_opts,
            changeset.context[:private][:actor],
            changeset.tenant,
            changeset.arguments,
            changeset.context,
            changeset
          )

        case validation_module.validate(changeset, templated_opts, validation_context) do
          :ok -> changeset
          {:error, error} -> add_validation_error(changeset, error, custom_message)
        end

      {:error, error} ->
        add_validation_error(changeset, error, custom_message)
    end
  end

  # This wrapper is invoked as a change and receives an
  # `Ash.Resource.Change.Context`, but validations expect an
  # `Ash.Resource.Validation.Context`. The only difference is `message`, which
  # builtins such as `changing/2` read directly (#93).
  defp validation_context(context, custom_message) do
    struct(
      Ash.Resource.Validation.Context,
      context |> Map.delete(:__struct__) |> Map.put(:message, custom_message)
    )
  end

  # Mirrors how `Ash.Changeset` applies a validation's `message` option.
  defp add_validation_error(changeset, error, nil) do
    Ash.Changeset.add_error(changeset, error)
  end

  defp add_validation_error(changeset, error, message) when is_binary(error) do
    Ash.Changeset.add_error(changeset, message)
  end

  defp add_validation_error(changeset, error, message) when is_exception(error) do
    Ash.Changeset.add_error(changeset, Ash.Error.override_validation_message(error, message))
  end

  defp add_validation_error(changeset, errors, message) when is_list(errors) do
    if Keyword.keyword?(errors) do
      Ash.Changeset.add_error(changeset, Keyword.put(errors, :message, message))
    else
      Ash.Changeset.add_error(
        changeset,
        Enum.map(errors, &Ash.Error.override_validation_message(&1, message))
      )
    end
  end

  defp add_validation_error(changeset, _error, message) do
    Ash.Changeset.add_error(changeset, message)
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
