defmodule AshEvents.UpdateActionWrapper do
  @moduledoc """
  Wrapper for update actions that enables event tracking.
  """
  use Ash.Resource.ManualUpdate

  def update(changeset, module_opts, ctx) do
    merged_ctx = Map.get(ctx, :source_context) |> Map.merge(ctx)

    if Map.get(merged_ctx, :ash_events_replay?) do
      data_layer = Ash.Resource.Info.data_layer(changeset.resource)
      data_layer.update(changeset.resource, changeset)
    else
      opts =
        ctx
        |> Ash.Context.to_opts()
        |> Keyword.put(:return_notifications?, ctx.return_notifications? || false)

      update_timestamp_attr = AshEvents.Events.Info.events_update_timestamp!(changeset.resource)

      occurred_at =
        AshEvents.Events.ActionWrapperHelpers.get_occurred_at(changeset, update_timestamp_attr)

      params =
        if update_timestamp_attr do
          Map.put(merged_ctx.original_params, update_timestamp_attr, occurred_at)
        else
          merged_ctx.original_params
        end

      AshEvents.Events.ActionWrapperHelpers.create_event!(
        changeset,
        params,
        occurred_at,
        module_opts,
        opts
      )

      data_layer = Ash.Resource.Info.data_layer(changeset.resource)
      data_layer.update(changeset.resource, changeset)
    end
  end
end
