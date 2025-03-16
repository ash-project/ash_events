defmodule AshEvents.CreateActionWrapper do
  use Ash.Resource.ManualCreate

  def create(changeset, module_opts, ctx) do
    opts = Ash.Context.to_opts(ctx)
    params = AshEvents.ActionWrapperHelpers.build_params(changeset, module_opts)

    action_result =
      changeset.resource
      |> Ash.Changeset.for_create(module_opts[:action], params, opts)
      |> Ash.create(opts)

    case action_result do
      {:error, error} ->
        {:error, error}

      {:ok, record} ->
        AshEvents.ActionWrapperHelpers.create_event!(changeset, params, record, module_opts, opts)
        {:ok, record}
    end

    # An `{:error, error}` tuple should be returned if something failed
  end
end
