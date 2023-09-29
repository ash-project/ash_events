defmodule AshEventSource.PersistEvent do
  def run(input, opts, context) do
    event =
      opts[:event_resource]
      |> Ash.Changeset.for_create(:create, %{input: input.params, resource: input.resource, action: opts[:action]}, actor: Ash.context_to_opts(context))
      |> input.api.create!()

    event.resource
    |> Ash.Changeset.for_create(event.action, event.input)
    |> input.api.create!()

    event =
      event
      |> Ash.Changeset.for_update(:process)
      |> input.api.update!()


    {:ok, :success}
  end

  # use Ash.Resource.ManualCreate
  # use Ash.Resource.ManualUpdate

  # @impl Ash.Resource.ManualCreate
  # def create(changeset, opts, context) do
  #   input = changeset.input


  #   # This is a hack, need to figure this out
  #   Ash.Changeset.apply_attributes(changeset, force?: true)
  # end

  # @impl Ash.Resource.ManualUpdate
  # def update(changeset, opts, context) do
  #   input = changeset.input

  #   opts[:resource]
  #   |> Ash.Changeset.for_create(:create, %{input: input}, actor: Ash.context_to_opts(context))
  #   |> changeset.api.create!()

  #   # This is a hack, need to figure this out
  #   Ash.Changeset.apply_attributes(changeset, force?: true)
  # end
end
