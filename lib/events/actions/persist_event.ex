defmodule AshEvents.PersistEvent do
  def run(input, run_opts, context) do
    action = Ash.Resource.Info.action(input.resource, run_opts[:action])
    opts = Ash.Context.to_opts(context)

    [primary_key] = Ash.Resource.Info.primary_key(input.resource)

    {extras, params} = Map.split(input.params, [:event_metadata, :record])

    {record, primary_key} =
      case action.type do
        :create ->
          record =
            input.resource
            |> Ash.Changeset.for_create(run_opts[:action], params, opts)
            |> Ash.create!(opts)

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
            |> Ash.destroy!(opts ++ [return_destroyed?: true, action: run_opts[:action]])

          {record, Map.get(record, primary_key)}
      end

    run_opts[:event_resource]
    |> Ash.Changeset.for_create(
      :create,
      %{
        data: params,
        record_id: primary_key,
        ash_events_resource: input.resource,
        ash_events_action: run_opts[:action],
        ash_events_action_type: action.type,
        metadata: extras[:event_metadata] || %{}
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
