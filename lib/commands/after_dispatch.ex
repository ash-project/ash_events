defmodule AshEvents.Commands.AfterDispatch do
  @moduledoc """
  An implementation of a generic action.
  """


  @callback run(map(), opts :: Keyword.t()) ::
              :ok | {:ok, term()} | {:ok, [Ash.Notifier.Notification.t()]} | {:error, term()}

  defmacro __using__(_) do
    quote do
      @behaviour AshEvents.Commands.AfterDispatch
    end
  end
end
