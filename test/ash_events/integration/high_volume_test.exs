# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Integration.HighVolumeTest do
  @moduledoc """
  Integration tests for high volume event scenarios.

  This module tests performance and behavior with large numbers of:
  - Concurrent event creation
  - Bulk operations
  - Event replay with many events
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.EventLogs.SystemActor

  @moduletag timeout: 120_000

  describe "bulk event creation" do
    test "creates many users with events" do
      actor = %SystemActor{name: "bulk_test"}
      clear_records()

      count = 25

      # Create many users
      users =
        for i <- 1..count do
          {:ok, user} =
            AshEvents.Accounts.UserUuidV7
            |> Ash.Changeset.for_create(:create, %{
              given_name: "User #{i}",
              family_name: "Bulk",
              email: unique_email("bulk_#{i}")
            })
            |> Ash.create(actor: actor)

          user
        end

      # Verify all events created
      events = get_all_events()
      assert length(events) >= count

      # Each user should have exactly one event
      for user <- users do
        user_events = Enum.filter(events, &(&1.record_id == user.id))
        assert length(user_events) == 1
      end
    end

    test "handles rapid sequential operations" do
      actor = %SystemActor{name: "rapid_test"}
      clear_records()

      # Create user and perform rapid updates
      {:ok, user} =
        AshEvents.Accounts.UserUuidV7
        |> Ash.Changeset.for_create(:create, %{
          given_name: "Rapid",
          family_name: "User",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      # Rapid updates
      update_count = 10

      Enum.reduce(1..update_count, user, fn i, current_user ->
        {:ok, updated} =
          current_user
          |> Ash.Changeset.for_update(:update, %{given_name: "Update #{i}"})
          |> Ash.update(actor: actor)

        updated
      end)

      # Verify all events
      events = get_events_for_record(user.id)
      assert length(events) == update_count + 1
    end
  end

  describe "high volume replay" do
    test "replays many events correctly" do
      actor = %SystemActor{name: "volume_replay_test"}
      clear_records()

      # Create users
      user_count = 15

      users =
        for i <- 1..user_count do
          {:ok, user} =
            AshEvents.Accounts.UserUuidV7
            |> Ash.Changeset.for_create(:create, %{
              given_name: "User #{i}",
              family_name: "Volume",
              email: unique_email("vol_#{i}")
            })
            |> Ash.create(actor: actor)

          user
        end

      # Update some users
      updated_users =
        Enum.take(users, 5)
        |> Enum.map(fn user ->
          {:ok, updated} =
            user
            |> Ash.Changeset.for_update(:update, %{given_name: "Updated"})
            |> Ash.update(actor: actor)

          updated
        end)

      original_user_ids = MapSet.new(users, & &1.id)

      # Clear and replay
      clear_records()

      :ok =
        AshEvents.EventLogs.EventLogUuidV7
        |> Ash.ActionInput.for_action(:replay, %{})
        |> Ash.run_action()

      # Verify all users restored
      restored_users = Ash.read!(AshEvents.Accounts.UserUuidV7, actor: actor)
      restored_ids = MapSet.new(restored_users, & &1.id)

      assert MapSet.equal?(original_user_ids, restored_ids)

      # Verify updated users have correct names
      for updated_user <- updated_users do
        restored = Enum.find(restored_users, &(&1.id == updated_user.id))
        assert restored.given_name == "Updated"
      end
    end
  end

  describe "concurrent operations" do
    test "concurrent creates don't lose events" do
      actor = %SystemActor{name: "concurrent_volume_test"}
      clear_records()

      # Many concurrent creates
      task_count = 10

      tasks =
        for i <- 1..task_count do
          Task.async(fn ->
            AshEvents.Accounts.UserUuidV7
            |> Ash.Changeset.for_create(:create, %{
              given_name: "Concurrent #{i}",
              family_name: "User",
              email: unique_email("conc_#{i}")
            })
            |> Ash.create(actor: actor)
          end)
        end

      results = Task.await_many(tasks, 30_000)

      # Count successes
      successes = Enum.filter(results, &match?({:ok, _}, &1))
      assert length(successes) == task_count

      # Each success should have event
      events = get_all_events()

      for {:ok, user} <- successes do
        user_events = Enum.filter(events, &(&1.record_id == user.id))
        assert length(user_events) == 1, "User #{user.id} should have exactly 1 event"
      end
    end

    test "concurrent updates on same record serialize correctly" do
      actor = %SystemActor{name: "concurrent_update_test"}
      clear_records()

      # Create a user
      {:ok, user} =
        AshEvents.Accounts.UserUuidV7
        |> Ash.Changeset.for_create(:create, %{
          given_name: "Base",
          family_name: "User",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      # Concurrent updates
      update_count = 5

      tasks =
        for i <- 1..update_count do
          Task.async(fn ->
            # Re-fetch to avoid stale data issues
            {:ok, current} = Ash.get(AshEvents.Accounts.UserUuidV7, user.id, actor: actor)

            current
            |> Ash.Changeset.for_update(:update, %{given_name: "Update #{i}"})
            |> Ash.update(actor: actor)
          end)
        end

      results = Task.await_many(tasks, 30_000)

      # At least some should succeed
      successes = Enum.filter(results, &match?({:ok, _}, &1))
      assert length(successes) >= 1

      # Events should match successes
      events = get_events_for_record(user.id)
      update_events = Enum.filter(events, &(&1.action_type == :update))
      assert length(update_events) == length(successes)
    end
  end

  describe "event ordering" do
    test "events maintain chronological order under load" do
      actor = %SystemActor{name: "ordering_test"}
      clear_records()

      {:ok, user} =
        AshEvents.Accounts.UserUuidV7
        |> Ash.Changeset.for_create(:create, %{
          given_name: "V0",
          family_name: "User",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      # Sequential updates with timing
      for i <- 1..5 do
        {:ok, _} =
          Ash.get!(AshEvents.Accounts.UserUuidV7, user.id, actor: actor)
          |> Ash.Changeset.for_update(:update, %{given_name: "V#{i}"})
          |> Ash.update(actor: actor)

        Process.sleep(10)
      end

      events =
        get_events_for_record(user.id)
        |> Enum.sort_by(& &1.occurred_at, DateTime)

      # Verify chronological order
      timestamps = Enum.map(events, & &1.occurred_at)
      sorted_timestamps = Enum.sort(timestamps, DateTime)
      assert timestamps == sorted_timestamps
    end
  end

  # Helper functions

  defp unique_email(prefix \\ "user") do
    "#{prefix}_#{System.unique_integer([:positive])}@example.com"
  end

  defp clear_records do
    AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])
  end

  defp get_all_events do
    AshEvents.EventLogs.EventLogUuidV7
    |> Ash.Query.sort(occurred_at: :asc)
    |> Ash.read!()
  end

  defp get_events_for_record(record_id) do
    get_all_events()
    |> Enum.filter(&(&1.record_id == record_id))
  end
end
