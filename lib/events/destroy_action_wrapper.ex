# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.DestroyActionWrapper do
  @moduledoc """
  Wrapper for destroy actions that enables event tracking.

  This module handles both hard and soft deletes. Soft deletes (actions with `soft?: true`)
  are implemented by Ash as updates under the hood, so this module implements both
  `destroy/3` for hard deletes and `update/3` for soft deletes.
  """
  use Ash.Resource.ManualDestroy
  use Ash.Resource.ManualUpdate

  @doc """
  Handles soft destroy actions (where `soft?: true`).

  Ash implements soft deletes as updates, so it calls `update/3` on the manual module.
  """
  def update(changeset, module_opts, ctx) do
    merged_ctx = (Map.get(ctx, :source_context) || %{}) |> Map.merge(ctx)

    if Map.get(merged_ctx, :ash_events_replay?) do
      data_layer = Ash.Resource.Info.data_layer(changeset.resource)
      data_layer.update(changeset.resource, changeset)
    else
      opts =
        ctx
        |> Ash.Context.to_opts()
        |> Keyword.put(:return_notifications?, ctx.return_notifications? || false)

      original_params =
        Map.get(merged_ctx, :original_params) ||
          Map.get(changeset.context, :original_params, %{})

      AshEvents.Events.ActionWrapperHelpers.create_event!(
        changeset,
        original_params,
        DateTime.utc_now(),
        module_opts,
        opts
      )

      data_layer = Ash.Resource.Info.data_layer(changeset.resource)
      data_layer.update(changeset.resource, changeset)
    end
  end

  @doc """
  Handles bulk soft destroy actions.

  When Ash converts a bulk soft-delete destroy into a bulk update, the changeset
  context key is `:bulk_destroy` but the bulk update pipeline expects `:bulk_update`.
  Implementing `bulk_update/3` allows us to tag results with their changesets directly,
  bypassing the context key mismatch.
  """
  def bulk_update(changesets, module_opts, bulk_ctx) do
    Enum.map(changesets, fn changeset ->
      ctx = %Ash.Resource.ManualUpdate.Context{
        actor: bulk_ctx.actor,
        source_context: changeset.context,
        select: bulk_ctx.select,
        authorize?: bulk_ctx.authorize?,
        tracer: bulk_ctx.tracer,
        domain: bulk_ctx.domain,
        return_notifications?: bulk_ctx.return_notifications? || false,
        tenant: bulk_ctx.tenant
      }

      case update(changeset, module_opts, ctx) do
        {:ok, record} -> {:ok, record, changeset}
        {:ok, record, _notifications} -> {:ok, record, changeset}
        {:error, error} -> {:error, error}
      end
    end)
  end

  @doc """
  Handles hard destroy actions.
  """
  def destroy(changeset, module_opts, ctx) do
    merged_ctx = (Map.get(ctx, :source_context) || %{}) |> Map.merge(ctx)

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

      original_params =
        Map.get(merged_ctx, :original_params) ||
          Map.get(changeset.context, :original_params, %{})

      AshEvents.Events.ActionWrapperHelpers.create_event!(
        changeset,
        original_params,
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
