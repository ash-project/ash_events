defmodule AshEvents.DestroyActionWrapper do
  use Ash.Resource.ManualDestroy

  def destroy(changeset, module_opts, ctx) do
    opts =
      ctx
      |> Ash.Context.to_opts()
      |> Keyword.put(:return_destroyed?, true)
      |> Keyword.put(:return_notifications?, ctx.return_notifications? || false)

    params = AshEvents.ActionWrapperHelpers.build_params(changeset, module_opts)
    AshEvents.ActionWrapperHelpers.create_event!(changeset, params, module_opts, opts)

    changeset.data
    |> Ash.Changeset.for_destroy(
      module_opts[:action],
      params,
      opts
    )
    |> Ash.destroy(opts)
  end
end
