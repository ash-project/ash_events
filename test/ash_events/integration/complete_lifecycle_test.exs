# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Integration.CompleteLifecycleTest do
  @moduledoc """
  Integration tests for complete CRUD lifecycles with events.

  This module tests end-to-end workflows including:
  - Full CRUD cycle with events
  - Actor attribution throughout lifecycle
  - Event replay reconstructing exact state
  - Multi-user scenarios
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.EventLogs.SystemActor

  describe "full CRUD lifecycle" do
    test "create-read-update-delete generates correct events" do
      actor = %SystemActor{name: "lifecycle_test"}
      clear_records()

      # Create
      {:ok, user} =
        AshEvents.Accounts.UserUuidV7
        |> Ash.Changeset.for_create(:create, %{
          given_name: "Lifecycle",
          family_name: "User",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      user_id = user.id

      # Read (doesn't create events)
      {:ok, read_user} = Ash.get(AshEvents.Accounts.UserUuidV7, user_id, actor: actor)
      assert read_user.given_name == "Lifecycle"

      # Update
      {:ok, updated} =
        user
        |> Ash.Changeset.for_update(:update, %{given_name: "Updated"})
        |> Ash.update(actor: actor)

      assert updated.given_name == "Updated"

      # Destroy
      {:ok, _destroyed} =
        updated
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.destroy(actor: actor, return_destroyed?: true)

      # Verify events
      events = get_events_for_record(user_id)
      assert length(events) == 3

      [create_event, update_event, destroy_event] =
        Enum.sort_by(events, & &1.occurred_at, DateTime)

      assert create_event.action_type == :create
      assert update_event.action_type == :update
      assert destroy_event.action_type == :destroy
    end

    test "multiple updates create multiple events" do
      actor = %SystemActor{name: "multi_update_test"}
      clear_records()

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

      {:ok, _user} =
        user
        |> Ash.Changeset.for_update(:update, %{given_name: "V4"})
        |> Ash.update(actor: actor)

      events = get_events_for_record(user.id)
      update_events = Enum.filter(events, &(&1.action_type == :update))

      assert length(update_events) == 3
    end
  end

  describe "event replay accuracy" do
    test "replay reconstructs exact state" do
      actor = %SystemActor{name: "replay_accuracy_test"}
      clear_records()

      # Create and update user
      {:ok, user} =
        AshEvents.Accounts.UserUuidV7
        |> Ash.Changeset.for_create(:create, %{
          given_name: "Original",
          family_name: "Name",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      {:ok, updated} =
        user
        |> Ash.Changeset.for_update(:update, %{given_name: "Updated", family_name: "Family"})
        |> Ash.update(actor: actor)

      original_state = %{
        id: updated.id,
        given_name: updated.given_name,
        family_name: updated.family_name,
        email: updated.email
      }

      # Clear and replay
      clear_records()

      :ok =
        AshEvents.EventLogs.EventLogUuidV7
        |> Ash.ActionInput.for_action(:replay, %{})
        |> Ash.run_action()

      # Verify exact reconstruction
      {:ok, replayed} = Ash.get(AshEvents.Accounts.UserUuidV7, original_state.id, actor: actor)

      assert replayed.id == original_state.id
      assert replayed.given_name == original_state.given_name
      assert replayed.family_name == original_state.family_name
    end

    test "replay handles destroy correctly" do
      actor = %SystemActor{name: "replay_destroy_test"}
      clear_records()

      # Create and destroy
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

      # Clear and replay
      clear_records()

      :ok =
        AshEvents.EventLogs.EventLogUuidV7
        |> Ash.ActionInput.for_action(:replay, %{})
        |> Ash.run_action()

      # User should not exist
      assert {:error, _} = Ash.get(AshEvents.Accounts.UserUuidV7, user_id, actor: actor)
    end
  end

  describe "actor attribution workflow" do
    test "actor is tracked through entire lifecycle" do
      actor = %SystemActor{name: "actor_tracking_test"}
      clear_records()

      # Create
      {:ok, user} =
        AshEvents.Accounts.UserUuidV7
        |> Ash.Changeset.for_create(:create, %{
          given_name: "Actor",
          family_name: "Test",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      # Update with same actor
      {:ok, updated} =
        user
        |> Ash.Changeset.for_update(:update, %{given_name: "Updated"})
        |> Ash.update(actor: actor)

      # Destroy with same actor
      {:ok, _} =
        updated
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.destroy(actor: actor, return_destroyed?: true)

      # Verify all events have same actor
      events = get_events_for_record(user.id)
      assert Enum.all?(events, &(&1.system_actor == "actor_tracking_test"))
    end
  end

  describe "metadata workflow" do
    test "metadata flows through create/update" do
      actor = %SystemActor{name: "metadata_flow_test"}
      clear_records()

      # Create with metadata
      {:ok, user} =
        AshEvents.Accounts.UserUuidV7
        |> Ash.Changeset.for_create(:create, %{
          given_name: "Meta",
          family_name: "Data",
          email: unique_email()
        })
        |> Ash.Changeset.set_context(%{ash_events_metadata: %{"request_id" => "create-123"}})
        |> Ash.create(actor: actor)

      # Update with different metadata
      {:ok, _updated} =
        user
        |> Ash.Changeset.for_update(:update, %{given_name: "Updated"})
        |> Ash.Changeset.set_context(%{ash_events_metadata: %{"request_id" => "update-456"}})
        |> Ash.update(actor: actor)

      events = get_events_for_record(user.id)
      [create_event, update_event] = Enum.sort_by(events, & &1.occurred_at, DateTime)

      assert create_event.metadata["request_id"] == "create-123"
      assert update_event.metadata["request_id"] == "update-456"
    end
  end

  describe "concurrent operations" do
    test "concurrent creates on different records succeed" do
      actor = %SystemActor{name: "concurrent_test"}
      clear_records()

      # Concurrent creates
      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            AshEvents.Accounts.UserUuidV7
            |> Ash.Changeset.for_create(:create, %{
              given_name: "User #{i}",
              family_name: "Concurrent",
              email: unique_email("concurrent_#{i}")
            })
            |> Ash.create(actor: actor)
          end)
        end

      results = Task.await_many(tasks)

      # All should succeed
      assert Enum.all?(results, &match?({:ok, _}, &1))

      # Each should have exactly one create event
      for {:ok, user} <- results do
        events = get_events_for_record(user.id)
        assert length(events) == 1
        assert hd(events).action_type == :create
      end
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
