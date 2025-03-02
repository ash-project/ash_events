defmodule AshEvents.Events.Actions.Replay do
  require Ash.Query

  def run(input, module_opts, ctx) do
    opts = Ash.Context.to_opts(ctx)

    handlers = module_opts[:handlers]

    process_event_func = fn event, opts ->
      Enum.reduce_while(handlers, :ok, fn handler, :ok ->
        case handler.process_event(event, opts) do
          {:ok, _} -> {:cont, :ok}
          {:error, error} -> {:halt, {:error, error}}
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
