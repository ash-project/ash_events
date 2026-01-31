# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Errors.AdvisoryLockErrorsTest do
  @moduledoc """
  Tests for advisory lock behavior during replay.

  This module tests edge cases with advisory locks using simpler event logs
  (UUIDv7 and Cloaked) that don't have complex replay overrides.
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.EventLogs.SystemActor

  describe "advisory lock during replay" do
    test "replay acquires and releases lock" do
      actor = %SystemActor{name: "test_runner"}
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      # Create a user
      {:ok, _user} =
        AshEvents.Accounts.UserUuidV7
        |> Ash.Changeset.for_create(:create, %{
          given_name: "Lock Test",
          family_name: "User",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      # Clear and replay
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      # Replay should succeed (lock is acquired and released)
      result =
        AshEvents.EventLogs.EventLogUuidV7
        |> Ash.ActionInput.for_action(:replay, %{})
        |> Ash.run_action()

      assert :ok == result
    end

    test "sequential replays work correctly" do
      actor = %SystemActor{name: "test_runner"}
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      # Create users
      {:ok, _user1} =
        AshEvents.Accounts.UserUuidV7
        |> Ash.Changeset.for_create(:create, %{
          given_name: "User1",
          family_name: "Test",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      {:ok, _user2} =
        AshEvents.Accounts.UserUuidV7
        |> Ash.Changeset.for_create(:create, %{
          given_name: "User2",
          family_name: "Test",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      # First replay
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      :ok =
        AshEvents.EventLogs.EventLogUuidV7
        |> Ash.ActionInput.for_action(:replay, %{})
        |> Ash.run_action()

      # Second replay should also work (lock was released)
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      result =
        AshEvents.EventLogs.EventLogUuidV7
        |> Ash.ActionInput.for_action(:replay, %{})
        |> Ash.run_action()

      assert :ok == result
    end
  end

  describe "lock cleanup" do
    test "lock is released after successful replay" do
      actor = %SystemActor{name: "test_runner"}
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      {:ok, _user} =
        AshEvents.Accounts.UserUuidV7
        |> Ash.Changeset.for_create(:create, %{
          given_name: "Cleanup Test",
          family_name: "User",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      # Run replay
      :ok =
        AshEvents.EventLogs.EventLogUuidV7
        |> Ash.ActionInput.for_action(:replay, %{})
        |> Ash.run_action()

      # Should be able to run another replay immediately
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      result =
        AshEvents.EventLogs.EventLogUuidV7
        |> Ash.ActionInput.for_action(:replay, %{})
        |> Ash.run_action()

      assert :ok == result
    end
  end

  describe "lock with different event logs" do
    test "UUIDv7 event log replay works with lock" do
      actor = %SystemActor{name: "test_runner"}
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      {:ok, user} =
        AshEvents.Accounts.UserUuidV7
        |> Ash.Changeset.for_create(:create, %{
          email: unique_email("v7"),
          given_name: "V7",
          family_name: "Lock Test"
        })
        |> Ash.create(actor: actor)

      user_id = user.id

      # Clear and replay
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      :ok =
        AshEvents.EventLogs.EventLogUuidV7
        |> Ash.ActionInput.for_action(:replay, %{})
        |> Ash.run_action()

      # User should be restored
      {:ok, restored} = Ash.get(AshEvents.Accounts.UserUuidV7, user_id, actor: actor)
      assert restored.given_name == "V7"
    end

    test "cloaked event log replay works with lock" do
      actor = %SystemActor{name: "test_runner"}
      AshEvents.EventLogs.ClearRecordsCloaked.clear_records!([])

      {:ok, org} =
        AshEvents.Accounts.OrgCloaked
        |> Ash.Changeset.for_create(:create, %{name: "Cloaked Lock Test"})
        |> Ash.create(actor: actor)

      org_id = org.id

      # Clear and replay
      AshEvents.EventLogs.ClearRecordsCloaked.clear_records!([])

      :ok =
        AshEvents.EventLogs.EventLogCloaked
        |> Ash.ActionInput.for_action(:replay, %{})
        |> Ash.run_action()

      # Org should be restored
      {:ok, restored} = Ash.get(AshEvents.Accounts.OrgCloaked, org_id, actor: actor)
      restored = Ash.load!(restored, [:name])
      assert restored.name == "Cloaked Lock Test"
    end
  end

  describe "empty log replay with locks" do
    test "empty event log replay still uses lock correctly" do
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      # Replay empty log
      result =
        AshEvents.EventLogs.EventLogUuidV7
        |> Ash.ActionInput.for_action(:replay, %{})
        |> Ash.run_action()

      assert :ok == result

      # Second empty replay should work
      result =
        AshEvents.EventLogs.EventLogUuidV7
        |> Ash.ActionInput.for_action(:replay, %{})
        |> Ash.run_action()

      assert :ok == result
    end
  end

  # Helper functions

  defp unique_email(prefix \\ "user") do
    "#{prefix}_#{System.unique_integer([:positive])}@example.com"
  end
end
