defmodule AshEvents.Events.Verifiers.VerifyStoreSensitiveAttributes do
  @moduledoc """
  Verifies that store_sensitive_attributes configuration is valid.

  Checks that:
  - All attribute names reference existing attributes on the resource
  - All specified attributes are actually marked as sensitive
  - store_sensitive_attributes is not configured when using a cloaked event log
  """
  use Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    store_sensitive_attributes =
      AshEvents.Events.Info.events_store_sensitive_attributes!(dsl_state)

    resource = Spark.Dsl.Verifier.get_persisted(dsl_state, :module)

    # First check if store_sensitive_attributes is configured with a cloaked event log
    with {:ok, event_log_resource} <- AshEvents.Events.Info.events_event_log(dsl_state),
         true <- AshEvents.EventLog.Info.cloaked?(event_log_resource),
         false <- Enum.empty?(store_sensitive_attributes) do
      {:error,
       Spark.Error.DslError.exception(
         message:
           "store_sensitive_attributes should not be configured when using a cloaked event log. Cloaked event logs automatically store all sensitive attributes because they are encrypted.",
         path: [:events, :store_sensitive_attributes],
         module: resource
       )}
    else
      _ ->
        # Continue with existing validation
        all_attributes = Ash.Resource.Info.attributes(dsl_state)
        all_attribute_names = Enum.map(all_attributes, & &1.name)

        Enum.reduce_while(store_sensitive_attributes, :ok, fn attribute_name, acc ->
          if attribute_name in all_attribute_names do
            attribute = Enum.find(all_attributes, &(&1.name == attribute_name))

            if attribute.sensitive? do
              {:cont, acc}
            else
              {:halt,
               {:error,
                Spark.Error.DslError.exception(
                  message:
                    "Attribute #{inspect(attribute_name)} in store_sensitive_attributes is not marked as sensitive on resource #{resource}. Only sensitive attributes should be listed here.",
                  path: [:events, :store_sensitive_attributes],
                  module: resource
                )}}
            end
          else
            {:halt,
             {:error,
              Spark.Error.DslError.exception(
                message:
                  "Attribute #{inspect(attribute_name)} in store_sensitive_attributes does not exist on resource #{resource}",
                path: [:events, :store_sensitive_attributes],
                module: resource
              )}}
          end
        end)
    end
  end
end
