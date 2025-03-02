defmodule AshEvents.EventHandler do
  @moduledoc """
    Declares an event handler, that can be used by an Ash.Resource with the
    `AshEvents.EventResource`-extension.

    When an EventResource creates an event, it will simultaneously call the
    `process_event/2`-function in all the event handlers it has been configured with.

    This will all take place inside the same transaction, so returning
    `{:error, reason}` will cause the transaction to be rolled back.

    ## Example:
        defmodule MyApp.Accounts.EventHandler do
          use AshEvents.EventHandler

          alias MyApp.Accounts

          @impl true
          def process_event(%{name: "user_created", version: "1." <> _} = event, opts) do
            case Accounts.create_user(event.data, opts) do
              {:ok, user} -> :ok
              {:error, reason} -> {:error, reason}
            end
          end

          # Fallback for all other events that should be ignored by this handler
          @impl true
          def process_event(_event, _opts), do: :ok
        end
  """
  defmacro __using__(_opts) do
    quote do
      @behaviour AshEvents.EventHandler
    end
  end

  @callback process_event(event :: struct(), opts :: keyword()) ::
              :ok | {:error, reason :: term}
end
