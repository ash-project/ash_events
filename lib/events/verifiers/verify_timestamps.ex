# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Events.Verifiers.VerifyTimestamps do
  @moduledoc """
  Verifies that timestamp configuration is valid.

  Checks that:
  - create_timestamp attribute exists on the resource (if specified) and is a valid timestamp type
  - update_timestamp attribute exists on the resource (if specified) and is a valid timestamp type
  - neither is set on a temporal resource, whose timestamps hold application time
  """
  use Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    create_timestamp =
      case AshEvents.Events.Info.events_create_timestamp(dsl_state) do
        {:ok, value} -> value
        :error -> nil
      end

    update_timestamp =
      case AshEvents.Events.Info.events_update_timestamp(dsl_state) do
        {:ok, value} -> value
        :error -> nil
      end

    resource = Spark.Dsl.Verifier.get_persisted(dsl_state, :module)
    all_attributes = Ash.Resource.Info.attributes(dsl_state)

    temporal? = Ash.Resource.Info.temporal?(dsl_state)

    with :ok <- verify_not_temporal(temporal?, create_timestamp, :create_timestamp, resource),
         :ok <- verify_not_temporal(temporal?, update_timestamp, :update_timestamp, resource),
         :ok <-
           verify_timestamp_attribute(
             create_timestamp,
             :create_timestamp,
             all_attributes,
             resource
           ) do
      verify_timestamp_attribute(
        update_timestamp,
        :update_timestamp,
        all_attributes,
        resource
      )
    end
  end

  defp verify_not_temporal(true, timestamp_attr, config_name, resource)
       when not is_nil(timestamp_attr) do
    {:error,
     Spark.Error.DslError.exception(
       message:
         "#{inspect(resource)} is a temporal resource, so it can't set `#{config_name}`. " <>
           "On a temporal resource the create and update timestamps hold application time " <>
           "(`as_of`), and an event's `occurred_at` is system time: it comes from the " <>
           "resource's `recorded_at` attribute, or the wall clock when there is none.",
       path: [:events, config_name],
       module: resource
     )}
  end

  defp verify_not_temporal(_temporal?, _timestamp_attr, _config_name, _resource), do: :ok

  defp verify_timestamp_attribute(nil, _config_name, _all_attributes, _resource), do: :ok

  defp verify_timestamp_attribute(timestamp_attr, config_name, all_attributes, resource) do
    case Enum.find(all_attributes, &(&1.name == timestamp_attr)) do
      nil ->
        {:error,
         Spark.Error.DslError.exception(
           message:
             "Attribute #{inspect(timestamp_attr)} specified in #{config_name} does not exist on resource #{resource}",
           path: [:events, config_name],
           module: resource
         )}

      attribute ->
        if valid_timestamp_type?(attribute.type) do
          :ok
        else
          {:error,
           Spark.Error.DslError.exception(
             message:
               "Attribute #{inspect(timestamp_attr)} specified in #{config_name} must be a timestamp type (e.g., :utc_datetime, :utc_datetime_usec, :datetime, :naive_datetime), got #{inspect(attribute.type)}",
             path: [:events, config_name],
             module: resource
           )}
        end
    end
  end

  defp valid_timestamp_type?(type) do
    case type do
      :utc_datetime ->
        true

      :utc_datetime_usec ->
        true

      :datetime ->
        true

      :naive_datetime ->
        true

      :naive_datetime_usec ->
        true

      Ash.Type.UtcDateTime ->
        true

      Ash.Type.UtcDatetimeUsec ->
        true

      Ash.Type.DateTime ->
        true

      Ash.Type.NaiveDatetime ->
        true

      # Allow custom types that might be timestamp-related
      module when is_atom(module) ->
        try do
          # Check if it's an Ash type that might be timestamp-related
          Code.ensure_loaded?(module) and
            function_exported?(module, :storage_type, 1) and
            valid_timestamp_type?(module.storage_type(:foo))
        rescue
          _ -> false
        end

      _ ->
        false
    end
  end
end
