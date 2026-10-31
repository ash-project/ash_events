# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.UpdateActionWrapper do
  @moduledoc """
  Wrapper for update actions that enables event tracking.
  """
  use Ash.Resource.ManualUpdate

  def update(changeset, module_opts, ctx) do
    merged_ctx = (Map.get(ctx, :source_context) || %{}) |> Map.merge(ctx)

    cond do
      Map.get(merged_ctx, :ash_events_replay?) ->
        data_layer = Ash.Resource.Info.data_layer(changeset.resource)
        data_layer.update(changeset.resource, changeset)

      unchanged?(changeset) ->
        # Ash skips the data layer write for an update that changes nothing, but
        # for manual actions it adds the update defaults (such as the update
        # timestamp) before calling us. Those defaults alone must not produce an
        # event or a write.
        AshEvents.Events.ActionWrapperHelpers.notifications_result(
          changeset,
          changeset.data,
          []
        )

      true ->
        record_and_update(changeset, module_opts, ctx, merged_ctx)
    end
  end

  # `changed?` is computed by Ash before it adds the update defaults. Updates
  # that manage relationships or carry a filter still go through the event and
  # the data layer: the former keeps the action in the event log, the latter
  # keeps returning a stale record error when the filter does not match.
  defp unchanged?(changeset) do
    Map.get(changeset.context, :changed?) == false and
      changeset.relationships == %{} and
      is_nil(changeset.filter)
  end

  defp record_and_update(changeset, module_opts, ctx, merged_ctx) do
    opts =
      ctx
      |> Ash.Context.to_opts()
      |> Keyword.put(:return_notifications?, ctx.return_notifications? || false)

    update_timestamp_attr = AshEvents.Events.Info.events_update_timestamp!(changeset.resource)

    occurred_at =
      AshEvents.Events.ActionWrapperHelpers.get_occurred_at(changeset, update_timestamp_attr)

    notifications =
      AshEvents.Events.ActionWrapperHelpers.create_event!(
        changeset,
        merged_ctx.original_params,
        occurred_at,
        module_opts,
        opts
      )

    data_layer = Ash.Resource.Info.data_layer(changeset.resource)

    with {:ok, record} <- data_layer.update(changeset.resource, changeset) do
      AshEvents.Events.ActionWrapperHelpers.notifications_result(
        changeset,
        record,
        notifications
      )
    end
  end
end
