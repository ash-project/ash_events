# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Events.Changes.StoreChangesetParams do
  @moduledoc false
  use Ash.Resource.Change

  def change(cs, _opts, _ctx) do
    Ash.Changeset.set_context(cs, %{original_params: cs.params})
  end
    # Temporal safety (ash_events#103): this change only captures/moves
    # changeset state — it never reads the wall clock and has no now-assuming
    # side effects, so it is safe on writes made as of any instant.
    @impl true
    def temporal_safe?(_opts), do: true
end
