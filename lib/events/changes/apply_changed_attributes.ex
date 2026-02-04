# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Events.Changes.ApplyChangedAttributes do
  @moduledoc """
  A change that runs LAST during replay to apply changed_attributes.

  This ensures that any attributes set by business logic changes (like set_attribute)
  are overwritten with the exact values from when the original event was created.

  The primary key is handled separately by ApplyReplayPrimaryKey which runs first.
  """
  use Ash.Resource.Change

  def change(cs, opts, _ctx) do
    ash_events_replay? = cs.context[:ash_events_replay?] || false

    if ash_events_replay? do
      changed_attributes = cs.context[:changed_attributes] || %{}
      replay_config = Keyword.get(opts, :replay_config, [])
      action_name = cs.action.name

      replay_strategy = Keyword.get(replay_config, action_name, :force_change)

      case replay_strategy do
        :force_change ->
          if map_size(changed_attributes) > 0 do
            atomized_attrs =
              Map.new(changed_attributes, fn
                {key, value} when is_binary(key) -> {String.to_existing_atom(key), value}
                {key, value} -> {key, value}
              end)

            # Exclude primary key (handled by ApplyReplayPrimaryKey) and filter to
            # attributes on this resource (replay_overrides may route to different schemas)
            [primary_key] = Ash.Resource.Info.primary_key(cs.resource)

            resource_attr_names =
              cs.resource |> Ash.Resource.Info.attributes() |> Enum.map(& &1.name) |> MapSet.new()

            filtered_attrs =
              Map.filter(atomized_attrs, fn {key, _value} ->
                key != primary_key and MapSet.member?(resource_attr_names, key)
              end)

            Ash.Changeset.force_change_attributes(cs, filtered_attrs)
          else
            cs
          end

        :as_arguments ->
          cs
      end
    else
      cs
    end
  end
end
