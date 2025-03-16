defmodule AshEvents.ActionWrapperHelpers do
  def build_params(changeset, module_opts) do
    replaced_action = Ash.Resource.Info.action(changeset.resource, module_opts[:action])
    arg_names = Enum.map(replaced_action.arguments, & &1.name)

    attr_params =
      changeset.attributes
      |> Map.take(replaced_action.accept)

    arg_params =
      changeset.attributes
      |> Map.take(arg_names)

    Map.merge(attr_params, arg_params)
  end

  def create_event!(changeset, params, record, module_opts, opts) do
    event_resource = module_opts[:event_resource]
    [primary_key] = Ash.Resource.Info.primary_key(changeset.resource)
    persist_actor_ids = AshEvents.EventResource.Info.event_resource(event_resource)
    actor = opts[:actor]

    event_params = %{
      data: params,
      record_id: Map.get(record, primary_key),
      ash_events_resource: changeset.resource,
      ash_events_action: module_opts[:replay_action],
      ash_events_action_type: changeset.action_type,
      metadata: changeset.arguments.event_metadata
    }

    event_params =
      Enum.reduce(persist_actor_ids, event_params, fn persist_actor_id, input ->
        if is_struct(actor) and actor.__struct__ == persist_actor_id.destination do
          primary_key = Map.get(actor, hd(Ash.Resource.Info.primary_key(actor.__struct__)))
          Map.put(input, persist_actor_id.name, primary_key)
        else
          input
        end
      end)

    event_resource
    |> Ash.Changeset.for_create(:create, event_params, opts)
    |> Ash.create!()
  end
end
