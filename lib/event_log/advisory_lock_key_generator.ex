# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

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

  @callback generate_key!(
              changeset :: Ash.Changeset.t(),
              default_value :: integer() | [integer()]
            ) ::
              integer() | list(integer())
end
