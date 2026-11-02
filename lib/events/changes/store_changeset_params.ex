# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Events.Changes.StoreChangesetParams do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def temporal_safe?(_opts), do: true

  @impl true
  def change(cs, _opts, _ctx) do
    Ash.Changeset.set_context(cs, %{original_params: cs.params})
  end
end
