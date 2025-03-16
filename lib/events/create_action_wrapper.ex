defmodule AshEvents.CreateActionWrapper do
  use Ash.Resource.ManualCreate

  def create(changeset, module_opts, ctx) do
    opts = Ash.Context.to_opts(ctx)
    params = AshEvents.ActionWrapperHelpers.build_params(changeset, module_opts)
    AshEvents.ActionWrapperHelpers.create_event!(changeset, params, module_opts, opts)

    changeset.resource
    |> Ash.Changeset.for_create(module_opts[:action], params, opts)
    |> Ash.create(opts)
  end
end
