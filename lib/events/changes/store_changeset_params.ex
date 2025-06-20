defmodule AshEvents.Events.Changes.StoreChangesetParams do
  @moduledoc false
  use Ash.Resource.Change

  def change(cs, _opts, _ctx) do
    Ash.Changeset.set_context(cs, %{original_params: cs.params})
  end
end
