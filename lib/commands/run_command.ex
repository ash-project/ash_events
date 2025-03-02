defmodule AshEvents.Commands.Resource.RunCommand do
  def run(input, module_opts, ctx) do
    opts = Ash.Context.to_opts(ctx)
    command = module_opts[:command]

    with {:ok, arguments} <- do_before_dispatch(input.arguments, command.before_dispatch, opts),
         event <- build_event(arguments, input.resource, command),
         {:ok, event} <- do_create_and_dispatch(event, module_opts[:event_resource], opts) do
      do_after_dispatch(event, command.after_dispatch, opts)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_event(arguments, input_resource, command) do
    resource = input_resource |> to_string() |> String.trim("Elixir.")

    arguments
    |> Map.merge(%{
      name: command.event_name,
      version: command.event_version
    })
    |> put_in([:metadata, :command_resource], resource)
    |> put_in([:metadata, :command_name], command.name)
  end

  defp do_before_dispatch(arguments, before_dispatch, opts) do
    case before_dispatch do
      nil -> {:ok, arguments}
      {_, [fun: fun]} -> fun.(arguments, opts)
      {module, []} -> module.run(arguments, opts)
    end
  end

  defp do_create_and_dispatch(event, event_resource, opts) do
    event_resource
    |> Ash.ActionInput.for_action(:create_and_dispatch, event, opts)
    |> Ash.run_action(opts)
  end

  defp do_after_dispatch(event, after_dispatch, opts) do
    case after_dispatch do
      nil -> {:ok, event}
      {_, [fun: fun]} -> fun.(event, opts)
      {module, []} -> module.run(event, opts)
    end
  end
end
