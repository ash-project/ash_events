defmodule AshEvents.UpdateActionWrapper do
  use Ash.Resource.ManualUpdate

  def update(changeset, module_opts, ctx) do
    opts = Ash.Context.to_opts(ctx)
    params = AshEvents.ActionWrapperHelpers.build_params(changeset, module_opts)
    AshEvents.ActionWrapperHelpers.create_event!(changeset, params, module_opts, opts)

    changeset.data
    |> Ash.Changeset.for_update(module_opts[:action], params, opts)
    |> Ash.update(opts)
  end
end
