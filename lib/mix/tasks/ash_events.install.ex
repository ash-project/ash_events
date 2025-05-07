if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshEvents.Install do
    @shortdoc "Installs AshEvents into a project. Should be called with `mix igniter.install ash_events`"

    @moduledoc """
    #{@shortdoc}
    """

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _source) do
      %Igniter.Mix.Task.Info{
        group: :ash
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      igniter
      |> Igniter.Project.Formatter.import_dep(:ash_events)
    end
  end
else
  defmodule Mix.Tasks.AshEvents.Install do
    @moduledoc "Installs AshEvents into a project. Should be called with `mix igniter.install ash_events`"

    @shortdoc @moduledoc

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'ash_events.install' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end
