defmodule AshEvents.CreateActionWrapper do
  use Ash.Resource.ManualCreate
  alias AshEvents.Helpers

  def create(changeset, module_opts, ctx) do
    opts =
      ctx
      |> Ash.Context.to_opts()
      |> Keyword.put(:return_notifications?, ctx.return_notifications? || false)

    params = AshEvents.Events.ActionWrapperHelpers.build_params(changeset, module_opts)
    AshEvents.Events.ActionWrapperHelpers.create_event!(changeset, params, module_opts, opts)

    original_action_name = Helpers.build_original_action_name(module_opts[:action])

    changeset.resource
    |> Ash.Changeset.for_create(original_action_name, params, opts)
    |> Ash.create(opts)
  end
end
