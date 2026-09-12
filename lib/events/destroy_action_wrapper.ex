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

      data_layer = Ash.Resource.Info.data_layer(changeset.resource)

      with :ok <- reject_atomics(changeset),
           {:ok, record} <- data_layer.update(changeset.resource, changeset) do
        notifications = create_event!(changeset, merged_ctx, module_opts, opts)

        AshEvents.Events.ActionWrapperHelpers.notifications_result(
          changeset,
          record,
          notifications
        )
      end
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
        {:ok, record} ->
          {:ok, record, changeset}

        {:ok, record, notifications} ->
          # Returning the changeset-tagged form would drop the notifications, so
          # hand them back instead and let Ash re-associate the changeset. It
          # looks the changeset up by the `:bulk_action_ref` metadata first, which
          # sidesteps the `:bulk_destroy`/`:bulk_update` index key mismatch.
          # `process_bulk_results/9` accepts both the bare list and the
          # `%{notifications: ...}` form, so pass whatever `update/3` produced
          # through untouched.
          {:ok, tag_bulk_ref(record, changeset), notifications}

        {:error, error} ->
          {:error, error}
      end
    end)
  end

  @doc """
  Handles hard destroy actions.
  """
  def destroy(changeset, module_opts, ctx) do
    merged_ctx = (Map.get(ctx, :source_context) || %{}) |> Map.merge(ctx)

    if Map.get(merged_ctx, :ash_events_replay?) do
      destroy_record(changeset)
    else
      opts =
        ctx
        |> Ash.Context.to_opts()
        |> Keyword.put(:return_destroyed?, true)
        |> Keyword.put(:return_notifications?, ctx.return_notifications? || false)

      with :ok <- reject_atomics(changeset),
           {:ok, record} <- destroy_record(changeset) do
        notifications = create_event!(changeset, merged_ctx, module_opts, opts)
        destroy_result(changeset, record, notifications)
      end
    end
  end

  # Ash's single-record destroy pipeline cannot carry notifications out of a
  # manual destroy. `Ash.Actions.Destroy.validate_manual_action_return_result!/3`
  # only accepts a bare list, but the `manage_relationships/4` clauses and the
  # notify step after them only match `%{notifications: ...}`, so a 3-tuple
  # falls straight through `other -> other` and every notification is lost --
  # including the ones Ash itself accumulated for the destroyed record.
  # Returning the 2-tuple keeps those working; the event's own notification
  # stays dropped.
  #
  # The bulk pipeline is fine: it hands the third element to
  # `Ash.Actions.Helpers.Bulk.store_notification/3`, which takes a bare list.
  #
  # This does NOT resolve itself when Ash is fixed -- `notifications` is
  # discarded here. Once `Ash.Actions.Destroy` normalises the bare-list form,
  # drop this function and return `{:ok, record, notifications}` directly (both
  # pipelines then want the same shape), and update the
  # "single destroy still delivers the record's own notification" test in
  # test/ash_events/notifications_test.exs to expect the event log
  # notification too. Verified against a locally patched Ash.
  defp destroy_result(changeset, record, notifications) do
    if AshEvents.Events.ActionWrapperHelpers.bulk_changeset?(changeset) do
      {:ok, record, notifications}
    else
      {:ok, record}
    end
  end

  defp tag_bulk_ref(record, %{context: %{bulk_destroy: %{ref: ref}}}) when not is_nil(ref),
    do: Ash.Resource.put_metadata(record, :bulk_action_ref, ref)

  defp tag_bulk_ref(record, _changeset), do: record

  # Atomic changes cannot be recorded, so refuse them before touching the data
  # layer rather than discovering it after the row is gone.
  defp reject_atomics(%{atomics: []}), do: :ok

  defp reject_atomics(_changeset),
    do: {:error, AshEvents.Events.ActionWrapperHelpers.atomics_error()}

  # The event is written only after the data layer call succeeds. Bulk actions
  # with a manual action do not roll back the batch on a per-record error, so
  # writing first would commit a destroy event for a row that still exists.
  #
  # original_params can be missing from the merged context when a nested bulk
  # operation (for example a cascading soft delete) builds the changeset, so
  # fall back to the changeset context and then to an empty map.
  defp create_event!(changeset, merged_ctx, module_opts, opts) do
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
  end

  # Data layer failures (stale record, FK restrict, permission errors) must
  # propagate so no destroy event is recorded for a surviving row.
  defp destroy_record(changeset) do
    data_layer = Ash.Resource.Info.data_layer(changeset.resource)

    case data_layer.destroy(changeset.resource, changeset) do
      :ok -> {:ok, changeset.data}
      {:error, _} = error -> error
      {:error, :no_rollback, _} = error -> error
    end
  end
end
