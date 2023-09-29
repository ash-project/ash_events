defmodule AshEvents.PersistEvent do
  def run(input, opts, context) do
    action = Ash.Resource.Info.action(input.resource, opts[:action])

    if action.type == :create do
      case AshEvents.Info.events_style!(input.resource) do
        :event_sourced ->
          opts[:event_resource]
          |> Ash.Changeset.for_create(
            :create,
            %{
              input: input.params,
              resource: input.resource,
              action: opts[:action],
              processed: true
            },
            actor: Ash.context_to_opts(context)
          )
          |> input.api.create!()

          {:ok, :success}

        :event_driven ->
          event =
            opts[:event_resource]
            |> Ash.Changeset.for_create(
              :create,
              %{
                input: input.params,
                resource: input.resource,
                action: opts[:action],
                processed: true
              },
              actor: Ash.context_to_opts(context)
            )
            |> input.api.create!()

          event.resource
          |> Ash.Changeset.for_create(event.action, event.input)
          |> input.api.create!()

          {:ok, :success}
      end
    else
      raise "Only create actions are currently supported"
    end
  end
end
