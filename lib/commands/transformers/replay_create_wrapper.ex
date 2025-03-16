defmodule AshEvents.ReplayCreateWrapper do
  use Ash.Resource.ManualCreate

  def create(changeset, module_opts, ctx) do
    opts = Ash.Context.to_opts(ctx)
    params = AshEvents.ActionWrapperHelpers.build_params(changeset, module_opts)

    changeset.resource
    |> Ash.Changeset.for_create(module_opts[:action], params, opts)
    |> Ash.create(opts)

    # An `{:error, error}` tuple should be returned if something failed
  end
end
