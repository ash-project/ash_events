defmodule AshEvents.ReplayDestroyWrapper do
  use Ash.Resource.ManualDestroy

  def destroy(changeset, module_opts, ctx) do
    opts = Ash.Context.to_opts(ctx)
    params = AshEvents.ActionWrapperHelpers.build_params(changeset, module_opts)

    changeset.data
    |> Ash.Changeset.for_destroy(module_opts[:action], params, opts)
    |> Ash.destroy(opts)
  end
end
