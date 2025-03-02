defmodule AshEvents.ReadModelsResetter do
  defmacro __using__(_opts) do
    quote do
      @behaviour AshEvents.ReadModelsResetter
    end
  end

  @callback reset_read_models(opts :: keyword()) ::
              :ok | {:error, reason :: term}
end
