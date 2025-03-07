defmodule AshEvents.Changeset do
  def for_create(resource, action, params, opts) do
    create_action = "#{action}_ash_events_impl" |> String.to_atom()
    Ash.Changeset.for_create(resource, create_action, params, opts)
  end

  def for_update(record, action, params, opts) do
    update_action = "#{action}_ash_events_impl" |> String.to_atom()
    Ash.Changeset.for_update(record, update_action, params, opts)
  end

  def for_destroy(record, action, params, opts) do
    destroy_action = "#{action}_ash_events_impl" |> String.to_atom()
    Ash.Changeset.for_destroy(record, destroy_action, params, opts)
  end
end
