defmodule AshEvents.UpdateActionWrapper do
  use Ash.Resource.ManualUpdate

  def update(changeset, module_opts, ctx) do
    opts = Ash.Context.to_opts(ctx)

    params = AshEvents.ActionWrapperHelpers.build_params(changeset, module_opts)

    action_result =
      changeset.data
      |> Ash.Changeset.for_update(module_opts[:action], params, opts)
      |> Ash.update(opts)

    case action_result do
      {:error, error} ->
        {:error, error}

      {:ok, record} ->
        AshEvents.ActionWrapperHelpers.create_event!(changeset, params, record, module_opts, opts)
        {:ok, record}
    end
  end
end
