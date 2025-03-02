defmodule AshEvents.Commands.BeforeDispatch do
  @moduledoc """
  An implementation of a generic action.
  """


  @callback run(map(), opts :: Keyword.t()) ::
              :ok | {:ok, map()} | {:ok, [Ash.Notifier.Notification.t()]} | {:error, term()}

  defmacro __using__(_) do
    quote do
      @behaviour AshEvents.Commands.BeforeDispatch
    end
  end
end
