defmodule AshEvents.DestroyActionWrapper do
  use Ash.Resource.ManualDestroy

  def destroy(changeset, module_opts, ctx) do
    opts = Ash.Context.to_opts(ctx)

    params = AshEvents.ActionWrapperHelpers.build_params(changeset, module_opts)

    action_result =
      changeset.data
      |> Ash.Changeset.for_destroy(
        module_opts[:action],
        params,
        opts
      )
      |> Ash.destroy(opts ++ [return_destroyed?: true])

    case action_result do
      {:error, error} ->
        {:error, error}

      {:ok, record} ->
        AshEvents.ActionWrapperHelpers.create_event!(changeset, params, record, module_opts, opts)
        {:ok, record}
    end

    # An `{:error, error}` tuple should be returned if something failed
  end

  def bulk_destroy(changesets, opts, context) do
    Enum.map(changesets, fn changeset ->
      destroy(changeset, opts, context)
    end)
  end
end
