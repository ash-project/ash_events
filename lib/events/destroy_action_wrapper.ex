defmodule AshEvents.DestroyActionWrapper do
  @moduledoc """
  Wrapper for destroy actions that enables event tracking.
  """
  use Ash.Resource.ManualDestroy
  alias AshEvents.Helpers

  def destroy(changeset, module_opts, ctx) do
    opts =
      ctx
      |> Ash.Context.to_opts()
      |> Keyword.put(:return_destroyed?, true)
      |> Keyword.put(:return_notifications?, ctx.return_notifications? || false)

    params = AshEvents.Events.ActionWrapperHelpers.build_params(changeset, module_opts)
    AshEvents.Events.ActionWrapperHelpers.create_event!(changeset, params, module_opts, opts)

    original_action_name = Helpers.build_original_action_name(module_opts[:action])

    changeset.data
    |> Ash.Changeset.new()
    |> Ash.Changeset.set_context(changeset.context)
    |> Ash.Changeset.for_destroy(
      original_action_name,
      params,
      opts
    )
    |> Ash.destroy(opts)
  end
end
