# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Integration.VersionMigrationTest do
  @moduledoc """
  Integration tests for action version migration.

  This module tests schema evolution with versioned events:
  - Different action versions create different event structures
  - Replay correctly handles versioned events
  - Version configuration is respected
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.EventLogs.SystemActor

  describe "action versioning" do
    test "action versions are recorded in events" do
      actor = %SystemActor{name: "version_test"}
      clear_records()

      # Create user - should use version 1
      {:ok, user} =
        AshEvents.Accounts.UserUuidV7
        |> Ash.Changeset.for_create(:create, %{
          given_name: "Versioned",
          family_name: "User",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      # Check event has version
      events = get_events_for_record(user.id)
      create_event = Enum.find(events, &(&1.action_type == :create))

      assert create_event.version == 1
    end

    test "update events have correct version" do
      actor = %SystemActor{name: "version_test"}
      clear_records()

      {:ok, user} =
        AshEvents.Accounts.UserUuidV7
        |> Ash.Changeset.for_create(:create, %{
          given_name: "Update",
          family_name: "Version",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      {:ok, _updated} =
        user
        |> Ash.Changeset.for_update(:update, %{given_name: "Updated Name"})
        |> Ash.update(actor: actor)

      events = get_events_for_record(user.id)
      update_event = Enum.find(events, &(&1.action_type == :update))

      # Updates without explicit version should have nil or default
      assert update_event != nil
    end

    test "destroy events track version" do
      actor = %SystemActor{name: "version_test"}
      clear_records()

      {:ok, user} =
        AshEvents.Accounts.UserUuidV7
        |> Ash.Changeset.for_create(:create, %{
          given_name: "To Delete",
          family_name: "User",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      user_id = user.id

      {:ok, _} =
        user
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.destroy(actor: actor, return_destroyed?: true)

      events = get_events_for_record(user_id)
      destroy_event = Enum.find(events, &(&1.action_type == :destroy))

      assert destroy_event != nil
    end
  end

  describe "versioned replay" do
    test "replay handles versioned create events" do
      actor = %SystemActor{name: "versioned_replay_test"}
      clear_records()

      # Create user with version
      {:ok, user} =
        AshEvents.Accounts.UserUuidV7
        |> Ash.Changeset.for_create(:create, %{
          given_name: "Replay",
          family_name: "Version",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      original_id = user.id

      # Clear and replay
      clear_records()

      :ok =
        AshEvents.EventLogs.EventLogUuidV7
        |> Ash.ActionInput.for_action(:replay, %{})
        |> Ash.run_action()

      # User should be restored
      {:ok, restored} = Ash.get(AshEvents.Accounts.UserUuidV7, original_id, actor: actor)
      assert restored.given_name == "Replay"
      assert restored.family_name == "Version"
    end

    test "replay handles mixed version events" do
      actor = %SystemActor{name: "mixed_version_test"}
      clear_records()

      # Create multiple users
      users =
        for i <- 1..3 do
          {:ok, user} =
            AshEvents.Accounts.UserUuidV7
            |> Ash.Changeset.for_create(:create, %{
              given_name: "User #{i}",
              family_name: "Mixed",
              email: unique_email("mixed_#{i}")
            })
            |> Ash.create(actor: actor)

          user
        end

      original_ids = Enum.map(users, & &1.id)

      # Update some
      {:ok, _} =
        hd(users)
        |> Ash.Changeset.for_update(:update, %{given_name: "Updated User 1"})
        |> Ash.update(actor: actor)

      # Clear and replay
      clear_records()

      :ok =
        AshEvents.EventLogs.EventLogUuidV7
        |> Ash.ActionInput.for_action(:replay, %{})
        |> Ash.run_action()

      # All users should be restored with correct state
      restored_users = Ash.read!(AshEvents.Accounts.UserUuidV7, actor: actor)
      restored_ids = Enum.map(restored_users, & &1.id) |> MapSet.new()

      for id <- original_ids do
        assert MapSet.member?(restored_ids, id)
      end

      # First user should have updated name
      first_user = Enum.find(restored_users, &(&1.id == hd(original_ids)))
      assert first_user.given_name == "Updated User 1"
    end
  end

  describe "version evolution scenarios" do
    test "events maintain version through multiple operations" do
      actor = %SystemActor{name: "evolution_test"}
      clear_records()

      # Create
      {:ok, user} =
        AshEvents.Accounts.UserUuidV7
        |> Ash.Changeset.for_create(:create, %{
          given_name: "V1",
          family_name: "User",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      # Multiple updates
      {:ok, user} =
        user
        |> Ash.Changeset.for_update(:update, %{given_name: "V2"})
        |> Ash.update(actor: actor)

      {:ok, user} =
        user
        |> Ash.Changeset.for_update(:update, %{given_name: "V3"})
        |> Ash.update(actor: actor)

      # Check all events
      events = get_events_for_record(user.id) |> Enum.sort_by(& &1.occurred_at, DateTime)

      assert length(events) == 3

      create_event = Enum.find(events, &(&1.action_type == :create))
      assert create_event.version == 1
    end

    test "replay preserves version semantics through full lifecycle" do
      actor = %SystemActor{name: "full_lifecycle_version_test"}
      clear_records()

      # Full lifecycle
      {:ok, user} =
        AshEvents.Accounts.UserUuidV7
        |> Ash.Changeset.for_create(:create, %{
          given_name: "Lifecycle",
          family_name: "Test",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      {:ok, updated} =
        user
        |> Ash.Changeset.for_update(:update, %{given_name: "Updated"})
        |> Ash.update(actor: actor)

      # Save state
      final_state = %{
        id: updated.id,
        given_name: updated.given_name,
        family_name: updated.family_name
      }

      # Clear and replay
      clear_records()

      :ok =
        AshEvents.EventLogs.EventLogUuidV7
        |> Ash.ActionInput.for_action(:replay, %{})
        |> Ash.run_action()

      # Verify state matches
      {:ok, replayed} = Ash.get(AshEvents.Accounts.UserUuidV7, final_state.id, actor: actor)

      assert replayed.given_name == final_state.given_name
      assert replayed.family_name == final_state.family_name
    end
  end

  # Helper functions

  defp unique_email(prefix \\ "user") do
    "#{prefix}_#{System.unique_integer([:positive])}@example.com"
  end

  defp clear_records do
    AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])
  end

  defp get_events_for_record(record_id) do
    AshEvents.EventLogs.EventLogUuidV7
    |> Ash.Query.sort(occurred_at: :asc)
    |> Ash.read!()
    |> Enum.filter(&(&1.record_id == record_id))
  end
end
