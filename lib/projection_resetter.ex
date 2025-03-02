defmodule AshEvents.ProjectionsResetter do
  defmacro __using__(_opts) do
    quote do
      @behaviour AshEvents.ProjectionsResetter
    end
  end

  @callback reset_projections(opts :: keyword()) ::
              :ok | {:error, reason :: term}
end
