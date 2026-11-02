# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.TemporalResourceTest do
  @moduledoc """
  Pins down how Ash temporal writes behave on PostgreSQL, on a resource that is
  not tracked by AshEvents:

    * which columns a backfilled write (`as_of` in the past) fills with
      application time, and which with system time;
    * how updates, range updates and destroys reshape the period.

  Versions are read with SQL, because Ash only reads one instant at a time.
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts.TemporalSubscription
  alias AshEvents.TestRepo

  @t1 ~U[2025-01-01 00:00:00.000000Z]
  @t2 ~U[2025-03-01 00:00:00.000000Z]
  @t3 ~U[2025-06-01 00:00:00.000000Z]
  @t4 ~U[2025-09-01 00:00:00.000000Z]

  test "a backfilled create, printed" do
    subscription =
      AshEvents.Accounts.TemporalSubscription
      |> Ash.Changeset.for_create(:create, %{plan: "bronze"},
        as_of: ~U[2025-01-01 00:00:00.000000Z]
      )
      |> Ash.create!()

    %{columns: columns, rows: rows} =
      AshEvents.TestRepo.query!(
        """
        SELECT plan, valid_at, inserted_at, updated_at, recorded_at
        FROM temporal_subscriptions
        WHERE id = $1
        ORDER BY lower(valid_at)
        """,
        [Ecto.UUID.dump!(subscription.id)]
      )

    for row <- rows do
      IO.puts("row: " <> inspect(Enum.zip(columns, row), pretty: true))
    end
  end

  describe "backfilled create" do
    test "opens [as_of, ∞); inserted_at and updated_at are as_of, recorded_at is the wall clock" do
      before = DateTime.utc_now()
      sub = create!("bronze", @t1)
      after_write = DateTime.utc_now()

      assert [version] = versions(sub.id)
      assert version.plan == "bronze"
      assert version.valid_at == {@t1, nil}
      assert version.inserted_at == @t1
      assert version.updated_at == @t1
      assert_wall_clock(version.recorded_at, before, after_write)
    end

    test "without as_of, the period, the timestamps and recorded_at share one instant" do
      before = DateTime.utc_now()
      sub = create!("bronze", nil)
      after_write = DateTime.utc_now()

      assert [version] = versions(sub.id)
      {lower, nil} = version.valid_at
      assert_wall_clock(lower, before, after_write)
      assert version.inserted_at == lower
      assert version.updated_at == lower
      assert version.recorded_at == lower
    end
  end

  describe "backfilled update" do
    for action <- [:update, :update_non_atomic] do
      test "#{action} splits at as_of; the new version's updated_at is as_of and recorded_at is the wall clock" do
        sub = create!("bronze", @t1)

        before = DateTime.utc_now()
        update!(sub, unquote(action), "gold", @t2)
        after_write = DateTime.utc_now()

        assert [bronze, gold] = versions(sub.id)

        assert bronze.plan == "bronze"
        assert bronze.valid_at == {@t1, @t2}
        assert bronze.inserted_at == @t1
        assert bronze.updated_at == @t1

        assert gold.plan == "gold"
        assert gold.valid_at == {@t2, nil}
        assert gold.inserted_at == @t1
        assert gold.updated_at == @t2
        assert_wall_clock(gold.recorded_at, before, after_write)
      end
    end
  end

  describe "range writes and destroys" do
    test "an update over [t2, t3) leaves a leftover from t3 that keeps the original updated_at" do
      sub = create!("bronze", @t1)
      update!(sub, :update, "gold", range(@t2, @t3))

      assert [
               %{plan: "bronze", valid_at: {@t1, @t2}, updated_at: @t1},
               %{plan: "gold", valid_at: {@t2, @t3}, updated_at: @t2},
               %{plan: "bronze", valid_at: {@t3, nil}, updated_at: @t1}
             ] = versions(sub.id)
    end

    test "a destroy at t4 ends the period and leaves updated_at alone" do
      sub = create!("bronze", @t1)
      silver = update!(sub, :update, "silver", @t3)

      destroy!(silver, @t4)

      assert [
               %{plan: "bronze", valid_at: {@t1, @t3}, updated_at: @t1},
               %{plan: "silver", valid_at: {@t3, @t4}, updated_at: @t3}
             ] = versions(sub.id)
    end

    test "an update over a range spanning two versions acts on each (holding the current version)" do
      sub = create!("bronze", @t1)
      silver = update!(sub, :update, "silver", @t3)

      update!(silver, :update, "gold", range(@t2, @t4))

      assert [
               %{plan: "bronze", valid_at: {@t1, @t2}},
               %{plan: "gold", valid_at: {@t2, @t3}, updated_at: @t2},
               %{plan: "gold", valid_at: {@t3, @t4}, updated_at: @t2},
               %{plan: "silver", valid_at: {@t4, nil}, updated_at: @t3}
             ] = versions(sub.id)
    end

    test "an update over a range spanning two versions acts on each (holding the earlier version)" do
      sub = create!("bronze", @t1)
      update!(sub, :update, "silver", @t3)
      bronze = Ash.get!(TemporalSubscription, sub.id, as_of: @t2)

      update!(bronze, :update, "gold", range(@t2, @t4))

      assert [
               %{plan: "bronze", valid_at: {@t1, @t2}},
               %{plan: "gold", valid_at: {@t2, @t3}, updated_at: @t2},
               %{plan: "gold", valid_at: {@t3, @t4}, updated_at: @t2},
               %{plan: "silver", valid_at: {@t4, nil}, updated_at: @t3}
             ] = versions(sub.id)
    end

    # These two pin ash_postgres's current non-atomic behaviour: `update/2`
    # scopes the write to the version valid at the range's lower bound
    # (`valid_at @> lower`, deps/ash_postgres/lib/data_layer.ex around line 4699),
    # unlike the atomic path above, which acts on every version the range
    # overlaps. Tracked AshEvents updates are non-atomic, so they behave the same
    # way. If ash_postgres changes this, these tests fail.
    test "a non-atomic update over a range spanning two versions acts only on the version valid at the lower bound" do
      sub = create!("bronze", @t1)
      silver = update!(sub, :update, "silver", @t3)

      update!(silver, :update_non_atomic, "gold", range(@t2, @t4))

      assert [
               %{plan: "bronze", valid_at: {@t1, @t2}, updated_at: @t1},
               %{plan: "gold", valid_at: {@t2, @t3}, updated_at: @t2},
               %{plan: "silver", valid_at: {@t3, nil}, updated_at: @t3}
             ] = versions(sub.id)
    end

    test "a non-atomic range update with nothing valid at the lower bound is a StaleRecord" do
      sub = create!("bronze", @t2)

      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Changes.StaleRecord{}]}} =
               sub
               |> Ash.Changeset.for_update(:update_non_atomic, %{plan: "gold"},
                 as_of: range(@t1, @t3)
               )
               |> Ash.update()

      assert [%{plan: "bronze", valid_at: {@t2, nil}}] = versions(sub.id)
    end
  end

  defp create!(plan, as_of) do
    TemporalSubscription
    |> Ash.Changeset.for_create(:create, %{plan: plan}, as_of: as_of)
    |> Ash.create!()
  end

  defp update!(record, action, plan, as_of) do
    record
    |> Ash.Changeset.for_update(action, %{plan: plan}, as_of: as_of)
    |> Ash.update!()
  end

  defp destroy!(record, as_of) do
    record
    |> Ash.Changeset.for_destroy(:destroy, %{}, as_of: as_of)
    |> Ash.destroy!()
  end

  defp range(lower, upper), do: %Ash.Range{lower: lower, upper: upper, bounds: :"[)"}

  defp assert_wall_clock(value, before, after_write) do
    assert DateTime.compare(value, before) != :lt and DateTime.compare(value, after_write) != :gt,
           "expected #{value} to be the wall clock of the write (between #{before} and #{after_write})"
  end

  defp versions(id) do
    """
    SELECT plan, valid_at, inserted_at, updated_at, recorded_at
    FROM temporal_subscriptions
    WHERE id = $1
    ORDER BY lower(valid_at)
    """
    |> TestRepo.query!([Ecto.UUID.dump!(id)])
    |> Map.fetch!(:rows)
    |> Enum.map(fn [plan, valid_at, inserted_at, updated_at, recorded_at] ->
      assert valid_at.lower_inclusive and not valid_at.upper_inclusive

      %{
        plan: plan,
        valid_at: {bound(valid_at.lower), bound(valid_at.upper)},
        inserted_at: utc(inserted_at),
        updated_at: utc(updated_at),
        recorded_at: utc(recorded_at)
      }
    end)
  end

  defp bound(value) when value in [nil, :unbound], do: nil
  defp bound(value), do: utc(value)

  defp utc(%NaiveDateTime{} = value), do: DateTime.from_naive!(value, "Etc/UTC")
  defp utc(%DateTime{} = value), do: DateTime.shift_zone!(value, "Etc/UTC")
end
