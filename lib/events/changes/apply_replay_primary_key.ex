# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Events.Changes.ApplyReplayPrimaryKey do
  @moduledoc """
  A change that runs FIRST during replay to set the primary key.

  This ensures the correct ID is available for any changes that need to reference it
  (like managed relationships that create related records).

  Other changed attributes are handled by ApplyChangedAttributes which runs last.
  """
  use Ash.Resource.Change

  def change(cs, _opts, _ctx) do
    ash_events_replay? = cs.context[:ash_events_replay?] || false

    if ash_events_replay? do
      changed_attributes = cs.context[:changed_attributes] || %{}
      [primary_key] = Ash.Resource.Info.primary_key(cs.resource)
      pk_string_key = to_string(primary_key)

      pk_value =
        Map.get(changed_attributes, primary_key) ||
          Map.get(changed_attributes, pk_string_key)

      if pk_value do
        Ash.Changeset.force_change_attribute(cs, primary_key, pk_value)
      else
        cs
      end
    else
      cs
    end
  end
end
