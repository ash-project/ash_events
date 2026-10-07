# SPDX-FileCopyrightText: 2023 ash-project contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.TemporalAsOfTest do
  @moduledoc """
  Temporal `as_of` capture and replay (ash_events#103).

  A write on a temporal resource carries an `as_of` — the instant the write
  takes effect. It is an action option (like `tenant`), not action input, so
  before this change it was invisible to the event log: replay re-invoked
  every action at replay wall-clock, and a temporal resource's periods
  collapsed into wall-clock slivers.

  These tests pin the contract:

    * a recorded write captures its `as_of` in the event's metadata (under
      the reserved "as_of" key; events without an `as_of` carry no key, so
      their payloads are byte-compatible with earlier versions);
    * replay re-invokes the action at the captured instant, rebuilding
      temporal periods exactly — across a create, a split (update), and a
      truncate (destroy);
    * events without a captured `as_of` still replay at wall-clock
      (backward compatible).
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.EventLogs.EventLog
  alias AshEvents.EventLogs.SystemActor

  require Ash.Query

  @t1 ~U[2025-01-10 00:00:00Z]
  @t2 ~U[2025-06-01 12:00:00Z]
  @t3 ~U[2026-01-01 00:00:00Z]

  @actor %SystemActor{name: "test_runner"}

  test "a recorded write captures its as_of in the event metadata" do
    user =
      AshEvents.Accounts.User
      |> Ash.Changeset.for_create(
        :create,
        %{email: "as-of@example.com", given_name: "Temp", family_name: "Oral"},
        as_of: @t1,
        actor: @actor
      )
      |> Ash.create!()

    event = latest_event_for(user.id)
    assert event.metadata["as_of"] == DateTime.to_iso8601(@t1)
  end

  test "events recorded without an as_of carry no metadata key (backward compatible)" do
    user =
      AshEvents.Accounts.User
      |> Ash.Changeset.for_create(
        :create,
        %{email: "no-as-of@example.com", given_name: "No", family_name: "AsOf"},
        actor: @actor
      )
      |> Ash.create!()

    event = latest_event_for(user.id)
    refute Map.has_key?(event.metadata, "as_of")
  end

  test "replay rebuilds temporal periods identically across create, split and truncate" do
    coverage =
      AshEvents.Accounts.TemporalCoverage
      |> Ash.Changeset.for_create(:create, %{plan: "bronze"}, as_of: @t1, actor: @actor)
      |> Ash.create!(authorize?: false)

    # Split: bronze keeps [t1, t2), gold opens [t2, ∞).
    coverage
    |> Ash.Changeset.for_update(:update, %{plan: "gold"}, as_of: @t2, actor: @actor)
    |> Ash.update!(authorize?: false)

    # Truncate: gold ends at t3 (the destroy's as_of).
    coverage
    |> Ash.Changeset.for_destroy(:destroy, %{}, as_of: @t3, actor: @actor)
    |> Ash.destroy!(authorize?: false)

    before = periods(coverage.id)

    expected = [
      %{plan: "bronze", lower: iso(@t1), upper: iso(@t2)},
      %{plan: "gold", lower: iso(@t2), upper: iso(@t3)}
    ]

    assert normalize_periods(before) == normalize_periods(expected)

    EventLog
    |> Ash.ActionInput.for_action(:replay, %{})
    |> Ash.run_action!(authorize?: false)

    assert normalize_periods(periods(coverage.id)) == normalize_periods(before),
           "replay must rebuild temporal periods identically"
  end

  defp iso(dt), do: DateTime.to_iso8601(dt)

  # Postgres renders timestamptz text as "2025-01-10 00:00:00+00"; the
  # expectation side is ISO-8601. Same instants, both sides.
  defp normalize_periods(periods) do
    Enum.map(periods, fn
      %{lower: lower, upper: upper} = period ->
        %{
          period
          | lower: normalize_instant(lower),
            upper: normalize_instant(upper)
        }

      period ->
        period
    end)
  end

  defp normalize_instant(text) do
    text
    |> String.replace(" ", "T")
    |> String.replace("+00", "Z")
  end

  defp periods(coverage_id) do
    AshEvents.TestRepo.query!(
      """
      select plan, lower(valid_at)::text, upper(valid_at)::text
      from temporal_coverages
      where id = $1
      order by lower(valid_at)
      """,
      [Ecto.UUID.dump!(coverage_id)]
    ).rows
    |> Enum.map(fn [plan, lower, upper] ->
      %{plan: plan, lower: lower, upper: upper}
    end)
  end

  defp latest_event_for(record_id) do
    EventLog
    |> Ash.Query.filter(record_id == ^record_id)
    |> Ash.Query.sort(occurred_at: :desc)
    |> Ash.read_one!(authorize?: false)
  end
end
