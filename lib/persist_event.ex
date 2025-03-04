defmodule AshEvents.PersistEvent do
  def run(input, run_opts, context) do
    action = Ash.Resource.Info.action(input.resource, run_opts[:action])
    opts = Ash.Context.to_opts(context)

    [primary_key] = Ash.Resource.Info.primary_key(input.resource)

    {metadata, params} = Map.split(input.params, [:event_metadata])

    {record, primary_key} =
      case action.type do
        :create ->
          record =
            input.resource
            |> Ash.Changeset.for_create(run_opts[:action], params, opts)
            |> Ash.create!()

          {record, Map.get(record, primary_key)}
      end

    run_opts[:event_resource]
    |> Ash.Changeset.for_create(
      :create,
      %{
        data: params,
        entity_id: primary_key,
        ash_events_resource: input.resource,
        ash_events_action: run_opts[:action],
        metadata: metadata[:event_metadata]
      },
      opts
    )
    |> Ash.create!()

    case run_opts[:on_success] do
      nil -> {:ok, record}
      {_, [fun: fun]} -> fun.(record, opts)
      {module, []} -> module.run(record, opts)
    end
  end
end
