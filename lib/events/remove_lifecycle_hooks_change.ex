defmodule AshEvents.Events.RemoveLifecycleHooksChange do
  @moduledoc """
  Removes all lifecycle hooks for an action.
  This change will be added during event replay, in order to disable
  any side-effects in the action.
  """
  use Ash.Resource.Change

  def change(changeset, _opts, _ctx) do
    AshEvents.Helpers.remove_changeset_lifecycle_hooks(changeset)
  end
end
