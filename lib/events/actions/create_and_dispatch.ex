defmodule AshEvents.EventResource.Actions.CreateAndDispatch do
  def run(input, module_opts, ctx) do
    opts = Ash.Context.to_opts(ctx)

    input.resource
    |> Ash.Changeset.for_create(:create, input.arguments, opts)
    |> Ash.create(opts)
    |> case do
      {:ok, event} ->
        module_opts[:handlers]
        |> Enum.filter(fn %{module: _module, event_name_prefix: prefix} ->
          String.starts_with?(event.name, prefix)
        end)
        |> Enum.reduce_while({:ok, event}, fn handler, acc ->
          case handler.module.process_event(event, opts) do
            :ok -> {:cont, acc}
            {:error, reason} -> {:halt, {:error, reason}}
          end
        end)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
