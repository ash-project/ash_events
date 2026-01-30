# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.DestroyActionWrapper do
  @moduledoc """
  Wrapper for destroy actions that enables event tracking.
  """
  use Ash.Resource.ManualDestroy

  defdelegate update(changeset, module_opts, ctx), to: AshEvents.UpdateActionWrapper

  def destroy(changeset, module_opts, ctx) do
    merged_ctx = Map.get(ctx, :source_context) |> Map.merge(ctx)

    if Map.get(merged_ctx, :ash_events_replay?) do
      data_layer = Ash.Resource.Info.data_layer(changeset.resource)

      data_layer.destroy(changeset.resource, changeset)
      {:ok, changeset.data}
    else
      opts =
        ctx
        |> Ash.Context.to_opts()
        |> Keyword.put(:return_destroyed?, true)
        |> Keyword.put(:return_notifications?, ctx.return_notifications? || false)

      AshEvents.Events.ActionWrapperHelpers.create_event!(
        changeset,
        merged_ctx.original_params,
        DateTime.utc_now(),
        module_opts,
        opts
      )

      data_layer = Ash.Resource.Info.data_layer(changeset.resource)

      data_layer.destroy(changeset.resource, changeset)
      {:ok, changeset.data}
    end
  end
end
