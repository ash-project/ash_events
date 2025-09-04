defmodule AshEvents.EventLog.Verifiers.VerifyReplayOverrides do
  @moduledoc """
  Verifies that replay_overrides configuration is valid.

  Checks that:
  - route_to.resource references an existing Ash resource
  - route_to.action references an existing action on the route_to.resource

  Note: event_resource and event_action are not validated as existing since
  they may have been removed after events were created for them.
  """
  use Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    replay_overrides = AshEvents.EventLog.Info.replay_overrides(dsl_state)
    resource = Spark.Dsl.Verifier.get_persisted(dsl_state, :module)

    Enum.reduce_while(replay_overrides, :ok, fn override, acc ->
      case validate_route_to_list(override.route_to, resource) do
        :ok -> {:cont, acc}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_route_to_list(route_to_list, resource) when is_list(route_to_list) do
    Enum.reduce_while(route_to_list, :ok, fn route_to, acc ->
      case validate_route_to(route_to, resource) do
        :ok -> {:cont, acc}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_route_to_list(nil, _resource), do: :ok
  defp validate_route_to_list([], _resource), do: :ok

  defp validate_route_to(nil, _resource), do: :ok

  defp validate_route_to(route_to, resource) do
    with :ok <- validate_route_to_resource(route_to.resource, resource) do
      validate_route_to_action(route_to.resource, route_to.action, resource)
    end
  end

  defp validate_route_to_resource(route_to_resource, resource) do
    if Ash.Resource.Info.resource?(route_to_resource) do
      :ok
    else
      {:error,
       Spark.Error.DslError.exception(
         message:
           "route_to resource #{route_to_resource} in replay_override does not exist or is not an Ash resource",
         path: [:replay_overrides],
         module: resource
       )}
    end
  end

  defp validate_route_to_action(route_to_resource, route_to_action, resource) do
    if Ash.Resource.Info.action(route_to_resource, route_to_action) do
      :ok
    else
      {:error,
       Spark.Error.DslError.exception(
         message:
           "route_to action #{route_to_action} does not exist on resource #{route_to_resource} in replay_override",
         path: [:replay_overrides],
         module: resource
       )}
    end
  end
end
