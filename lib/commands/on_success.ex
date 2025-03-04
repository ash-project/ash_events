defmodule AshEvents.Commands.OnSuccess do
  @moduledoc """
  An implementation of a command's on success handler.
  """

  @callback run(map(), opts :: Keyword.t()) ::
              {:ok, term()} | {:ok, [Ash.Notifier.Notification.t()]} | {:error, term()}

  defmacro __using__(_) do
    quote do
      @behaviour AshEvents.Commands.OnSuccess
    end
  end
end
