defmodule AshEvents.AdvisoryLockKeyGenerator do
  @moduledoc """
    Behaviour for generating advisory lock keys when inserting events for a given Ash-changeset.
    Must return a signed 64-bit integer, or two signed 32-bit integers in a list.
  """
  defmacro __using__(_opts) do
    quote do
      @behaviour AshEvents.AdvisoryLockKeyGenerator
    end
  end

  @callback generate_key!(resource :: Ash.Resource.t(), default_value :: integer()) ::
              integer() | list(integer())
end
