defmodule AshEvents.EventLog.Actions.Replay do
  @moduledoc """
  Action module used by the event log resource to replay events.
  """
  alias AshEvents.Helpers
  require Ash.Query
  require Logger

  defp create!(resource, action, input, opts) do
    resource
    |> Ash.Changeset.for_create(action, input, opts)
    |> Ash.create!()

    :ok
  end

  defp update!(resource, id, action, input, event_id, opts) do
    case Ash.get(resource, id, opts) do
      {:ok, record} ->
        record
        |> Ash.Changeset.for_update(action, input |> Map.drop([:id]), opts)
        |> Ash.update!()

        :ok

      _ ->
        Logger.warning("Record #{id} not found when processing update event #{event_id}")
    end
  end

  defp destroy!(resource, id, action, event_id, opts) do
    case Ash.get(resource, id, opts) do
      {:ok, record} ->
        record
        |> Ash.Changeset.for_destroy(action, %{}, opts)
        |> Ash.destroy!()

        :ok

      _ ->
        Logger.warning("Record #{id} not found when processing destroy event #{event_id}")
    end
  end

  defp handle_action(:create, resource, action, input, _record_id, _event_id, opts) do
    create!(resource, action, input, opts)
  end

  defp handle_action(:update, resource, action, input, record_id, event_id, opts) do
    update!(resource, record_id, action, input, event_id, opts)
  end

  defp handle_action(:destroy, resource, action, _input, record_id, event_id, opts) do
    destroy!(resource, record_id, action, event_id, opts)
  end

  def run(input, run_opts, ctx) do
    opts =
      Ash.Context.to_opts(ctx,
        authorize?: false
      )

    ctx = Map.put(opts[:context] || %{}, :ash_events_replay?, true)
    opts = Keyword.replace(opts, :context, ctx)

    case AshEvents.EventLog.Info.event_log_clear_records_for_replay(input.resource) do
      {:ok, module} ->
        module.clear_records!(opts)

      :error ->
        raise "clear_records_for_replay must be specified on #{input.resource} when doing a replay."
    end

    cloak_vault =
      case AshEvents.EventLog.Info.event_log_cloak_vault(input.resource) do
        {:ok, vault} -> vault
        :error -> nil
      end

    overrides = run_opts[:overrides]
    point_in_time = input.arguments[:point_in_time]
    last_event_id = input.arguments[:last_event_id]

    cond do
      last_event_id != nil ->
        input.resource
        |> Ash.Query.filter(id <= ^last_event_id)

      point_in_time != nil ->
        input.resource
        |> Ash.Query.filter(occurred_at <= ^point_in_time)

      true ->
        input.resource
    end
    |> Ash.Query.sort(id: :asc)
    |> then(fn query ->
      if cloak_vault,
        do: Ash.Query.load(query, [:data, :metadata]),
        else: query
    end)
    |> Ash.stream!(opts)
    |> Stream.map(fn event ->
      input = Map.put(event.data, :id, event.record_id)

      override =
        Enum.find(overrides, fn
          %{event_resource: event_resource, event_action: event_action, versions: versions} ->
            event.resource == event_resource and
              event.action == event_action and
              event.version in versions
        end)

      if override do
        Enum.each(override.route_to, fn route_to ->
          handle_action(
            event.action_type,
            route_to.resource,
            route_to.action,
            input,
            event.record_id,
            event.id,
            opts
          )
        end)
      else
        original_action_name = Helpers.build_original_action_name(event.action)

        handle_action(
          event.action_type,
          event.resource,
          original_action_name,
          input,
          event.record_id,
          event.id,
          opts
        )
      end
    end)
    |> Stream.take_while(fn
      :ok -> true
      _res -> false
    end)
    |> Enum.reduce_while(:ok, fn
      :ok, _acc -> {:cont, :ok}
      error, _acc -> {:halt, error}
    end)
  end
end
