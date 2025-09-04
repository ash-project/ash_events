defmodule AshEvents.EventLog.Verifiers.VerifyPrimaryKeyType do
  @moduledoc """
  Verifies that primary_key_type configuration is valid.

  Checks that:
  - primary_key_type is either :integer or Ash.Type.UUIDv7
  """
  use Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    primary_key_type = AshEvents.EventLog.Info.event_log_primary_key_type!(dsl_state)
    resource = Spark.Dsl.Verifier.get_persisted(dsl_state, :module)

    if valid_primary_key_type?(primary_key_type) do
      :ok
    else
      {:error,
       Spark.Error.DslError.exception(
         message:
           "primary_key_type must be either :integer or Ash.Type.UUIDv7, got #{inspect(primary_key_type)}",
         path: [:event_log, :primary_key_type],
         module: resource
       )}
    end
  end

  defp valid_primary_key_type?(:integer), do: true
  defp valid_primary_key_type?(Ash.Type.UUIDv7), do: true
  defp valid_primary_key_type?(_), do: false
end
