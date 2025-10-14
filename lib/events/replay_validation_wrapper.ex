# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Events.ReplayValidationWrapper do
  @moduledoc """
  Specialized wrapper for validations that preserves custom messages during event tracking.

  This wrapper ensures that custom validation messages are preserved when using AshEvents,
  while still allowing for replay-specific behavior during event replay.
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
      run_validation(changeset, validation_module, validation_opts, context, custom_message)
    end
  end

  defp run_validation(changeset, validation_module, validation_opts, context, custom_message) do
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

        case validation_module.validate(changeset, templated_opts, context) do
          :ok ->
            changeset

          {:error, error} ->
            # If we have a custom message, override the error message
            final_error =
              if custom_message do
                override_error_message(error, custom_message)
              else
                error
              end

            Ash.Changeset.add_error(changeset, final_error)
        end

      {:error, error} ->
        final_error =
          if custom_message do
            override_error_message(error, custom_message)
          else
            error
          end

        Ash.Changeset.add_error(changeset, final_error)
    end
  end

  defp override_error_message(error, custom_message) do
    case error do
      %Ash.Error.Changes.InvalidAttribute{} = error ->
        %{error | message: custom_message}

      %Ash.Error.Changes.InvalidArgument{} = error ->
        %{error | message: custom_message}

      # Handle other error types that might need message override
      error when is_struct(error) ->
        if Map.has_key?(error, :message) do
          %{error | message: custom_message}
        else
          error
        end

      _ ->
        %Ash.Error.Changes.InvalidAttribute{
          field: :unknown,
          message: custom_message,
          value: nil
        }
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
