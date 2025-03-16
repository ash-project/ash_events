defmodule AshEvents.PersistEvent do
  def run(input, run_opts, context) do
    action = Ash.Resource.Info.action(input.resource, run_opts[:action])
    opts = Ash.Context.to_opts(context)
    actor = opts[:actor]
    event_resource = run_opts[:event_resource]

    persist_actor_ids = AshEvents.EventResource.Info.event_resource(event_resource)

    [primary_key] = Ash.Resource.Info.primary_key(input.resource)

    {extras, params} = Map.split(input.params, [:event_metadata, :record])

    {record, primary_key} =
      case action.type do
        :create ->
          record =
            input.resource
            |> Ash.Changeset.for_create(run_opts[:action], params, opts)
            |> Ash.create!()

          {record, Map.get(record, primary_key)}

        :update ->
          record =
            extras[:record]
            |> Ash.Changeset.for_update(run_opts[:action], params, opts)
            |> Ash.update!(opts)

          {record, Map.get(record, primary_key)}

        :destroy ->
          record =
            extras[:record]
            |> Ash.destroy!(opts ++ [action: run_opts[:action]])

          {record, Map.get(extras[:record], primary_key)}
      end

    event_params = %{
      data: params,
      record_id: primary_key,
      ash_events_resource: input.resource,
      ash_events_action: run_opts[:action],
      ash_events_action_type: action.type,
      metadata: extras[:event_metadata] || %{}
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

    event =
      run_opts[:event_resource]
      |> Ash.Changeset.for_create(:create, event_params, opts)
      |> Ash.create!()

    case {action.type, run_opts[:on_success]} do
      {:destroy, nil} -> :ok
      {_action_type, nil} -> {:ok, record}
      {_action_type, {_, [fun: fun]}} -> fun.(record, event, opts)
      {_action_type, {module, []}} -> module.run(record, event, opts)
    end
  end
end
