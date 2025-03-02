defmodule AshEvents.EventResource.Actions.Replay do
  require Ash.Query

  def run(input, module_opts, ctx) do
    opts = Ash.Context.to_opts(ctx)

    handlers = module_opts[:handlers]

    process_event_func = fn event, opts ->
      Enum.reduce_while(handlers, :ok, fn %{module: handler, event_name_prefix: prefix}, :ok ->
        if String.starts_with?(event.name, prefix) do
          case handler.process_event(event, opts) do
            :ok -> {:cont, :ok}
            {:error, error} -> {:halt, {:error, error}}
          end
        else
          {:cont, :ok}
        end
      end)
    end

    input.resource
    |> Ash.stream!(opts)
    |> Stream.map(fn event ->
      process_event_func.(event, opts)
    end)
    |> Stream.take_while(fn
      :ok -> true
      _res -> false
    end)
    |> Enum.reduce_while(:ok, fn
      :ok, _acc -> {:cont, :ok}
      error, _acc -> {:halt, error}
    end)
  end
end
