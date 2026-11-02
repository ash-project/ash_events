# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Accounts.TrackedSubscription.UpcasePlan do
  @moduledoc """
  A user change that declares itself temporal safe, so it may run on a tracked
  temporal resource.
  """
  use Ash.Resource.Change

  @impl true
  def temporal_safe?(_opts), do: true

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.fetch_change(changeset, :plan) do
      {:ok, plan} when is_binary(plan) ->
        Ash.Changeset.force_change_attribute(changeset, :plan, String.upcase(plan))

      _ ->
        changeset
    end
  end
end

defmodule AshEvents.Accounts.TrackedSubscription.UnsafeChange do
  @moduledoc """
  A user change that doesn't declare `temporal_safe?/1`, so Ash refuses to run
  it on a temporal resource.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context), do: changeset
end
