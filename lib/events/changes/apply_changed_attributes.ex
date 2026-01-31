# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Events.Changes.ApplyChangedAttributes do
  @moduledoc false
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
            # Filter to only include attributes that exist on the target resource
            # This is important for rerouted actions where the target resource
            # may have different attributes than the original resource
            resource_attributes =
              cs.resource
              |> Ash.Resource.Info.attributes()
              |> MapSet.new(& &1.name)

            filtered_attributes =
              changed_attributes
              |> Enum.filter(fn {key, _value} ->
                attr_name = if is_binary(key), do: String.to_existing_atom(key), else: key
                MapSet.member?(resource_attributes, attr_name)
              end)
              |> Map.new()

            if map_size(filtered_attributes) > 0 do
              Ash.Changeset.force_change_attributes(cs, filtered_attributes)
            else
              cs
            end
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
