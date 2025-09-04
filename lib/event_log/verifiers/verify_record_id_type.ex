defmodule AshEvents.EventLog.Verifiers.VerifyRecordIdType do
  @moduledoc """
  Verifies that record_id_type configuration is valid.

  Checks that:
  - record_id_type is a valid Ash type
  """
  use Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    record_id_type = AshEvents.EventLog.Info.event_log_record_id_type!(dsl_state)
    resource = Spark.Dsl.Verifier.get_persisted(dsl_state, :module)

    if valid_ash_type?(record_id_type) do
      :ok
    else
      {:error,
       Spark.Error.DslError.exception(
         message: "record_id_type #{inspect(record_id_type)} is not a valid Ash type",
         path: [:event_log, :record_id_type],
         module: resource
       )}
    end
  end

  defp valid_ash_type?(type) when is_atom(type) do
    # Common built-in Elixir/Ash types
    built_in_types = [
      :string,
      :integer,
      :uuid
    ]

    cond do
      type in built_in_types ->
        true

      String.starts_with?(to_string(type), "Elixir.Ash.Type") ->
        module_exists?(type)

      module_exists?(type) ->
        implements_ash_type?(type)

      true ->
        false
    end
  end

  defp valid_ash_type?(_), do: false

  defp module_exists?(module) do
    Code.ensure_loaded?(module)
  rescue
    _ -> false
  end

  defp implements_ash_type?(module) do
    behaviours =
      module.module_info(:attributes)
      |> Keyword.get(:behaviour, [])

    Ash.Type in behaviours or
      (function_exported?(module, :storage_type, 1) and
         function_exported?(module, :cast_input, 2))
  rescue
    _ -> false
  end
end
