# SPDX-FileCopyrightText: 2024 Torkild G. Kjevik
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EventLog.Verifiers.VerifyAdvisoryLockConfig do
  @moduledoc """
  Verifies that advisory lock configuration is valid.

  Checks that:
  - advisory_lock_key_generator module exists and implements AshEvents.AdvisoryLockKeyGenerator
  - advisory_lock_key_default is a valid integer or list of two 32-bit integers
  """
  use Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    advisory_lock_key_generator =
      AshEvents.EventLog.Info.event_log_advisory_lock_key_generator!(dsl_state)

    advisory_lock_key_default =
      AshEvents.EventLog.Info.event_log_advisory_lock_key_default!(dsl_state)

    resource = Spark.Dsl.Verifier.get_persisted(dsl_state, :module)

    with :ok <- verify_advisory_lock_key_generator(advisory_lock_key_generator, resource) do
      verify_advisory_lock_key_default(advisory_lock_key_default, resource)
    end
  end

  defp verify_advisory_lock_key_generator(generator_module, resource) do
    cond do
      not module_exists?(generator_module) ->
        {:error,
         Spark.Error.DslError.exception(
           message:
             "Module #{generator_module} specified in advisory_lock_key_generator does not exist",
           path: [:event_log, :advisory_lock_key_generator],
           module: resource
         )}

      not implements_behaviour?(generator_module, AshEvents.AdvisoryLockKeyGenerator) ->
        {:error,
         Spark.Error.DslError.exception(
           message:
             "Module #{generator_module} specified in advisory_lock_key_generator does not implement the AshEvents.AdvisoryLockKeyGenerator behaviour",
           path: [:event_log, :advisory_lock_key_generator],
           module: resource
         )}

      true ->
        :ok
    end
  end

  defp verify_advisory_lock_key_default(lock_key, resource) when is_integer(lock_key) do
    if valid_32bit_integer?(lock_key) do
      :ok
    else
      {:error,
       Spark.Error.DslError.exception(
         message:
           "advisory_lock_key_default must be a 32-bit integer (#{-2_147_483_648} to #{2_147_483_647}), got #{lock_key}",
         path: [:event_log, :advisory_lock_key_default],
         module: resource
       )}
    end
  end

  defp verify_advisory_lock_key_default(lock_key, resource) when is_list(lock_key) do
    cond do
      length(lock_key) != 2 ->
        {:error,
         Spark.Error.DslError.exception(
           message:
             "advisory_lock_key_default when specified as a list must contain exactly two integers, got #{inspect(lock_key)}",
           path: [:event_log, :advisory_lock_key_default],
           module: resource
         )}

      not Enum.all?(lock_key, &is_integer/1) ->
        {:error,
         Spark.Error.DslError.exception(
           message:
             "advisory_lock_key_default when specified as a list must contain only integers, got #{inspect(lock_key)}",
           path: [:event_log, :advisory_lock_key_default],
           module: resource
         )}

      not Enum.all?(lock_key, &valid_32bit_integer?/1) ->
        {:error,
         Spark.Error.DslError.exception(
           message:
             "advisory_lock_key_default when specified as a list must contain only 32-bit integers (#{-2_147_483_648} to #{2_147_483_647}), got #{inspect(lock_key)}",
           path: [:event_log, :advisory_lock_key_default],
           module: resource
         )}

      true ->
        :ok
    end
  end

  defp valid_32bit_integer?(value) when is_integer(value) do
    value >= -2_147_483_648 and value <= 2_147_483_647
  end

  defp valid_32bit_integer?(_), do: false

  defp module_exists?(module) do
    Code.ensure_loaded?(module)
  rescue
    _ -> false
  end

  defp implements_behaviour?(module, behaviour) do
    module.module_info(:attributes)
    |> Keyword.get(:behaviour, [])
    |> Enum.member?(behaviour)
  rescue
    _ -> false
  end
end
