defmodule AshEvents.ClearRecordsForReplay do
  defmacro __using__(_opts) do
    quote do
      @behaviour AshEvents.ClearRecordsForReplay
    end
  end

  @callback clear_records!(opts :: keyword()) ::
              :ok | {:error, reason :: term}
end
