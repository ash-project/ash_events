defmodule AshEvents.Events.ActionWrapperHelpers do
  @moduledoc """
  Helper functions used by the action wrappers.
  """

  alias AshEvents.Helpers

  def build_params(changeset, module_opts) do
    original_action_name = Helpers.build_original_action_name(module_opts[:action])
    original_action = Ash.Resource.Info.action(changeset.resource, original_action_name)
    arg_names = Enum.map(original_action.arguments, & &1.name)

    attr_params =
      changeset.attributes
      |> Map.take(original_action.accept)

    arg_params =
      changeset.arguments
      |> Map.take(arg_names)

    Map.merge(attr_params, arg_params)
  end

  def create_event!(changeset, params, module_opts, opts) do
    event_log_resource = module_opts[:event_log]
    [primary_key] = Ash.Resource.Info.primary_key(changeset.resource)
    persist_actor_primary_keys = AshEvents.EventLog.Info.event_log(event_log_resource)
    actor = opts[:actor]

    record_id =
      if changeset.action_type == :create do
        Map.get(changeset.attributes, primary_key)
      else
        Map.get(changeset.data, primary_key)
      end

    event_params = %{
      data: params,
      record_id: record_id,
      resource: changeset.resource,
      action: module_opts[:action],
      action_type: changeset.action_type,
      metadata: changeset.arguments.ash_events_metadata || %{},
      version: module_opts[:version]
    }

    event_params =
      Enum.reduce(persist_actor_primary_keys, event_params, fn persist_actor_primary_key, input ->
        if is_struct(actor) and actor.__struct__ == persist_actor_primary_key.destination do
          primary_key = Map.get(actor, hd(Ash.Resource.Info.primary_key(actor.__struct__)))
          Map.put(input, persist_actor_primary_key.name, primary_key)
        else
          input
        end
      end)

    event_log_resource
    |> Ash.Changeset.for_create(:create, event_params, opts)
    |> Ash.create!()
  end
end
