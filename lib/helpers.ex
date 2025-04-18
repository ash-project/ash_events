defmodule AshEvents.Helpers do
  @moduledoc """
  Internal helpers for AshEvents.
  """
  def build_original_action_name(action_name) do
    :"#{action_name}_ash_events_orig_impl"
  end

  def remove_changeset_lifecycle_hooks(changeset) do
    %{
      changeset
      | around_transaction: [],
        before_transaction: [],
        after_transaction: [],
        around_action: [],
        before_action: [],
        after_action: []
    }
  end
end
