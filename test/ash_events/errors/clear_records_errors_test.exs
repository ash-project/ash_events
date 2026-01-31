# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Errors.ClearRecordsErrorsTest do
  @moduledoc """
  Tests for clear_records_for_replay error scenarios.

  This module tests edge cases when clearing records:
  - Clearing empty tables
  - Clearing tables with relationships
  - Proper order of clearing with foreign key constraints
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.EventLogs.SystemActor

  describe "clear records functionality" do
    test "clear records handles empty tables" do
      # Start with fresh state
      AshEvents.EventLogs.ClearRecords.clear_records!([])

      # Should succeed even with empty tables
      assert :ok == AshEvents.EventLogs.ClearRecords.clear_records!([])
    end

    test "clear records removes all user records" do
      actor = %SystemActor{name: "test_runner"}

      # Create some users
      for i <- 1..3 do
        {:ok, _user} =
          AshEvents.Accounts.User
          |> Ash.Changeset.for_create(:create, %{
            given_name: "User #{i}",
            email: unique_email("clear_#{i}")
          })
          |> Ash.create(actor: actor)
      end

      # Verify users exist
      users = Ash.read!(AshEvents.Accounts.User, actor: actor)
      assert length(users) >= 3

      # Clear records
      AshEvents.EventLogs.ClearRecords.clear_records!([])

      # Verify users are cleared
      users_after = Ash.read!(AshEvents.Accounts.User, actor: actor)
      assert length(users_after) == 0
    end

    test "clear records handles relationships correctly" do
      actor = %SystemActor{name: "test_runner"}

      # Create a user which auto-creates a UserRole
      {:ok, _user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Rel Test", email: unique_email("rel")})
        |> Ash.create(actor: actor)

      # Clear records - should clear UserRoles first due to FK order
      AshEvents.EventLogs.ClearRecords.clear_records!([])

      # Both should be empty
      users = Ash.read!(AshEvents.Accounts.User, actor: actor)
      user_roles = Ash.read!(AshEvents.Accounts.UserRole, actor: actor)

      assert length(users) == 0
      assert length(user_roles) == 0
    end
  end

  describe "multiple resource types" do
    test "clear records handles all tracked resource types" do
      actor = %SystemActor{name: "test_runner"}

      # Create user (with UserRole)
      {:ok, _user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Multi Test", email: unique_email()})
        |> Ash.create(actor: actor)

      # Clear all
      AshEvents.EventLogs.ClearRecords.clear_records!([])

      # All tracked resources should be cleared
      users = Ash.read!(AshEvents.Accounts.User, actor: actor)
      user_roles = Ash.read!(AshEvents.Accounts.UserRole, actor: actor)

      assert length(users) == 0
      assert length(user_roles) == 0
    end
  end

  describe "clear records with UUIDv7 event log" do
    test "clear records for UUIDv7 works correctly" do
      actor = %SystemActor{name: "test_runner"}

      # Create users
      {:ok, _user} =
        AshEvents.Accounts.UserUuidV7
        |> Ash.Changeset.for_create(:create, %{
          given_name: "V7 User",
          family_name: "Test",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      # Verify user exists
      users = Ash.read!(AshEvents.Accounts.UserUuidV7, actor: actor)
      assert length(users) >= 1

      # Clear records
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      # Verify users are cleared
      users_after = Ash.read!(AshEvents.Accounts.UserUuidV7, actor: actor)
      assert length(users_after) == 0
    end
  end

  # Helper functions

  defp unique_email(prefix \\ "user") do
    "#{prefix}_#{System.unique_integer([:positive])}@example.com"
  end
end
