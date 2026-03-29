# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Events.Validations.Never do
  @moduledoc """
  A validation that always fails. Used as a `where` condition to create
  non-executing changes that exist only for introspection by other libraries
  (e.g., AshPhoenix nested form detection).
  """
  use Ash.Resource.Validation

  @impl true
  def validate(_changeset, _opts, _context) do
    {:error, "never runs"}
  end
end
