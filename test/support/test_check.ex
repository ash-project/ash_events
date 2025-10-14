# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Checks.TestCheck do
  alias AshEvents.EventLogs.SystemActor
  @moduledoc false
  use Ash.Policy.SimpleCheck

  @impl Ash.Policy.Check
  def describe(_) do
    "SystemActor or test user is performing this interaction"
  end

  @impl true
  def match?(%SystemActor{}, _ctx, _opts), do: true
  def match?(%{email: "user@example.com"}, _ctx, _opts), do: true
  def match?(_, _, _), do: false
end
