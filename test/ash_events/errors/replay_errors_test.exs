# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Errors.ReplayErrorsTest do
  @moduledoc """
  Tests for error scenarios during event replay.

  This module tests edge cases and error handling when replaying events.
  Uses the UUIDv7 event log which has simpler configuration for testing.
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.EventLogs.SystemActor

  describe "empty event log" do
    test "replay with no events completes successfully" do
      # Clear everything first
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      # Replay should work with empty log
      result =
        AshEvents.EventLogs.EventLogUuidV7
        |> Ash.ActionInput.for_action(:replay, %{})
        |> Ash.run_action()

      assert :ok == result
    end

    test "point in time replay with no matching events completes" do
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      # Replay to a point before any events
      past_time = DateTime.add(DateTime.utc_now(), -3600, :second)

      result =
        AshEvents.EventLogs.EventLogUuidV7
        |> Ash.ActionInput.for_action(:replay, %{point_in_time: past_time})
        |> Ash.run_action()

      assert :ok == result
    end
  end

  describe "point in time replay" do
    test "replay stops at point_in_time" do
      actor = %SystemActor{name: "test_runner"}
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      # Create initial user
      {:ok, user} =
        AshEvents.Accounts.UserUuidV7
        |> Ash.Changeset.for_create(:create, %{
          given_name: "Initial",
          family_name: "Test",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      Process.sleep(50)
      midpoint = DateTime.utc_now()
      Process.sleep(50)

      # Update user after midpoint
      {:ok, _updated} =
        user
        |> Ash.Changeset.for_update(:update, %{given_name: "Updated"})
        |> Ash.update(actor: actor)

      user_id = user.id

      # Clear records and replay to midpoint
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      :ok =
        AshEvents.EventLogs.EventLogUuidV7
        |> Ash.ActionInput.for_action(:replay, %{point_in_time: midpoint})
        |> Ash.run_action()

      # User should exist with initial name (update happened after midpoint)
      {:ok, replayed_user} = Ash.get(AshEvents.Accounts.UserUuidV7, user_id, actor: actor)
      assert replayed_user.given_name == "Initial"
    end
  end

  describe "replay idempotency" do
    test "replaying same events twice produces same result" do
      actor = %SystemActor{name: "test_runner"}
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      # Create a user
      {:ok, user} =
        AshEvents.Accounts.UserUuidV7
        |> Ash.Changeset.for_create(:create, %{
          given_name: "Idempotent",
          family_name: "Test",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      user_id = user.id
      original_name = user.given_name

      # First replay
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      :ok =
        AshEvents.EventLogs.EventLogUuidV7
        |> Ash.ActionInput.for_action(:replay, %{})
        |> Ash.run_action()

      {:ok, after_first} = Ash.get(AshEvents.Accounts.UserUuidV7, user_id, actor: actor)

      # Second replay (should produce same state)
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      :ok =
        AshEvents.EventLogs.EventLogUuidV7
        |> Ash.ActionInput.for_action(:replay, %{})
        |> Ash.run_action()

      {:ok, after_second} = Ash.get(AshEvents.Accounts.UserUuidV7, user_id, actor: actor)

      assert after_first.given_name == original_name
      assert after_second.given_name == original_name
      assert after_first.id == after_second.id
    end
  end

  describe "full lifecycle replay" do
    test "create-update-destroy cycle replays correctly" do
      actor = %SystemActor{name: "test_runner"}
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      # Create a user
      {:ok, user} =
        AshEvents.Accounts.UserUuidV7
        |> Ash.Changeset.for_create(:create, %{
          given_name: "Lifecycle",
          family_name: "Test",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      # Update
      {:ok, updated} =
        user
        |> Ash.Changeset.for_update(:update, %{given_name: "Updated Lifecycle"})
        |> Ash.update(actor: actor)

      # Destroy
      {:ok, _} =
        updated
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.destroy(actor: actor, return_destroyed?: true)

      user_id = user.id

      # Clear and replay
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      :ok =
        AshEvents.EventLogs.EventLogUuidV7
        |> Ash.ActionInput.for_action(:replay, %{})
        |> Ash.run_action()

      # User should not exist after replay (was destroyed)
      assert {:error, _} = Ash.get(AshEvents.Accounts.UserUuidV7, user_id, actor: actor)
    end
  end

  describe "event ordering" do
    test "events are replayed in chronological order" do
      actor = %SystemActor{name: "test_runner"}
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      # Create user and update multiple times
      {:ok, user} =
        AshEvents.Accounts.UserUuidV7
        |> Ash.Changeset.for_create(:create, %{
          given_name: "V1",
          family_name: "Test",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      Process.sleep(10)

      {:ok, user} =
        user
        |> Ash.Changeset.for_update(:update, %{given_name: "V2"})
        |> Ash.update(actor: actor)

      Process.sleep(10)

      {:ok, _user} =
        user
        |> Ash.Changeset.for_update(:update, %{given_name: "V3"})
        |> Ash.update(actor: actor)

      user_id = user.id

      # Clear and replay
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      :ok =
        AshEvents.EventLogs.EventLogUuidV7
        |> Ash.ActionInput.for_action(:replay, %{})
        |> Ash.run_action()

      # User should have final name
      {:ok, replayed_user} = Ash.get(AshEvents.Accounts.UserUuidV7, user_id, actor: actor)
      assert replayed_user.given_name == "V3"
    end
  end

  # Helper functions

  defp unique_email(prefix \\ "user") do
    "#{prefix}_#{System.unique_integer([:positive])}@example.com"
  end
end
