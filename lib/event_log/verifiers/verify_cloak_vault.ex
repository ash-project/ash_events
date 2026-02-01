# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EventLog.Verifiers.VerifyCloakVault do
  @moduledoc """
  Verifies that cloak_vault configuration is valid.

  Checks that:
  - cloak_vault module exists and implements Cloak.Vault (if specified)
  """
  use Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    cloak_vault =
      case AshEvents.EventLog.Info.event_log_cloak_vault(dsl_state) do
        {:ok, value} -> value
        :error -> nil
      end

    resource = Spark.Dsl.Verifier.get_persisted(dsl_state, :module)

    verify_cloak_vault(cloak_vault, resource)
  end

  defp verify_cloak_vault(nil, _resource), do: :ok

  defp verify_cloak_vault(vault_module, resource) do
    cond do
      not module_exists?(vault_module) ->
        {:error,
         Spark.Error.DslError.exception(
           message: "Module #{vault_module} specified in cloak_vault does not exist",
           path: [:event_log, :cloak_vault],
           module: resource
         )}

      not implements_cloak_vault?(vault_module) ->
        {:error,
         Spark.Error.DslError.exception(
           message:
             "Module #{vault_module} specified in cloak_vault does not implement Cloak.Vault behaviour",
           path: [:event_log, :cloak_vault],
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

  defp implements_cloak_vault?(module) do
    # Check if module has the behaviour attribute for Cloak.Vault
    behaviours =
      module.module_info(:attributes)
      |> Keyword.get(:behaviour, [])

    # Also check if it has the required functions for Cloak.Vault
    Cloak.Vault in behaviours or
      (function_exported?(module, :encrypt!, 1) and
         function_exported?(module, :decrypt!, 1))
  rescue
    _ -> false
  end
end
