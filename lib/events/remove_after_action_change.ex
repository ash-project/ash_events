defmodule AshEvents.Events.RemoveAfterActionChange do
  use Ash.Resource.Change

  def change(changeset, _opts, _ctx) do
    %{changeset | after_action: []}
  end
end
