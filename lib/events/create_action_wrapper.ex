# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.CreateActionWrapper do
  @moduledoc """
  Wrapper for create actions that enables event tracking.
  """
  use Ash.Resource.ManualCreate

  def create(changeset, module_opts, %{upsert?: upsert?, upsert_keys: upsert_keys} = ctx) do
    merged_ctx = Map.get(ctx, :source_context) |> Map.merge(ctx)

    if Map.get(merged_ctx, :ash_events_replay?) do
      data_layer = Ash.Resource.Info.data_layer(changeset.resource)
      data_layer.create(changeset.resource, changeset)
    else
      opts =
        ctx
        |> Ash.Context.to_opts()
        |> Keyword.put(:return_notifications?, ctx.return_notifications? || false)

      data_layer = Ash.Resource.Info.data_layer(changeset.resource)

      result =
        if upsert? do
          upsert_identity =
            if changeset.action.upsert_identity do
              Ash.Resource.Info.identity(changeset.resource, changeset.action.upsert_identity)
            else
              nil
            end

          data_layer.upsert(changeset.resource, changeset, upsert_keys, upsert_identity)
        else
          data_layer.create(changeset.resource, changeset)
        end

      case result do
        {:ok, record} ->
          [primary_key] = Ash.Resource.Info.primary_key(changeset.resource)
          actual_id = Map.get(record, primary_key)

          changeset = %{
            changeset
            | attributes: Map.put(changeset.attributes, primary_key, actual_id)
          }

          occurred_at = get_occurred_at_for_create(changeset, record, upsert?)

          AshEvents.Events.ActionWrapperHelpers.create_event!(
            changeset,
            merged_ctx.original_params,
            occurred_at,
            module_opts,
            opts
          )

          result

        error ->
          error
      end
    end
  end

  # For upserts, determine if the operation was an insert or update by comparing timestamps.
  # If update_timestamp > create_timestamp, it was an update, so use update_timestamp.
  # Otherwise (insert or no update_timestamp configured), use create_timestamp.
  defp get_occurred_at_for_create(changeset, record, true = _upsert?) do
    create_timestamp_attr =
      AshEvents.Events.Info.events_create_timestamp!(changeset.resource)

    update_timestamp_attr =
      AshEvents.Events.Info.events_update_timestamp!(changeset.resource)

    create_ts = get_timestamp_from_record(record, create_timestamp_attr)
    update_ts = get_timestamp_from_record(record, update_timestamp_attr)

    cond do
      create_ts && update_ts && DateTime.compare(update_ts, create_ts) == :gt ->
        update_ts

      create_ts ->
        create_ts

      true ->
        DateTime.utc_now()
    end
  end

  # For regular creates (not upserts), always use create_timestamp
  defp get_occurred_at_for_create(changeset, _record, false = _upsert?) do
    create_timestamp_attr =
      AshEvents.Events.Info.events_create_timestamp!(changeset.resource)

    AshEvents.Events.ActionWrapperHelpers.get_occurred_at(changeset, create_timestamp_attr)
  end

  defp get_timestamp_from_record(_record, nil), do: nil
  defp get_timestamp_from_record(record, attr), do: Map.get(record, attr)
end
