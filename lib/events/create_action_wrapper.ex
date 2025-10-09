# SPDX-FileCopyrightText: 2024 Torkild G. Kjevik
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

          create_timestamp_attr =
            AshEvents.Events.Info.events_create_timestamp!(changeset.resource)

          occurred_at =
            AshEvents.Events.ActionWrapperHelpers.get_occurred_at(
              changeset,
              create_timestamp_attr
            )

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
end
