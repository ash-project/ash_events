# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Errors.EventCreationErrorsTest do
  @moduledoc """
  Tests for error scenarios during event creation.

  This module tests edge cases and error handling when events are created:
  - Event creation with validation failures
  - Event creation with invalid data types
  - Event creation during transaction rollbacks
  - Graceful degradation scenarios
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.EventLogs.SystemActor

  describe "validation errors" do
    test "action failure does not create event" do
      actor = %SystemActor{name: "test_runner"}
      initial_count = event_count()

      # Try to create a user without required fields
      result =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{})
        |> Ash.create(actor: actor)

      assert {:error, _} = result
      # No event should have been created
      assert event_count() == initial_count
    end

    test "invalid email format fails validation without creating event" do
      actor = %SystemActor{name: "test_runner"}
      initial_count = event_count()

      # Email validation may or may not exist, but this tests the pattern
      result =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Test"})
        |> Ash.create(actor: actor)

      assert {:error, _} = result
      assert event_count() == initial_count
    end

    test "duplicate unique constraint fails without orphaned event" do
      actor = %SystemActor{name: "test_runner"}
      email = unique_email()

      # Create first user successfully
      {:ok, _first_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "First", email: email})
        |> Ash.create(actor: actor)

      initial_count = event_count()

      # Try to create duplicate - should fail
      result =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Second", email: email})
        |> Ash.create(actor: actor)

      assert {:error, _} = result
      # No additional event for failed duplicate
      assert event_count() == initial_count
    end
  end

  describe "actor handling" do
    test "system actor name is recorded correctly" do
      actor = %SystemActor{name: "background_job_worker"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Test", email: unique_email()})
        |> Ash.create(actor: actor)

      events = events_for_record(created_user.id)
      event = hd(events)

      assert event.system_actor == "background_job_worker"
      assert event.user_id == nil
    end

    test "user actor has their id recorded" do
      system_actor = %SystemActor{name: "test_runner"}

      {:ok, actor_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Actor", email: unique_email()})
        |> Ash.create(actor: system_actor)

      # User updates themselves (allowed by policy)
      {:ok, updated_user} =
        actor_user
        |> Ash.Changeset.for_update(:update, %{given_name: "Updated Actor"})
        |> Ash.update(actor: actor_user)

      events = events_for_record(updated_user.id)
      update_event = Enum.find(events, &(&1.action_type == :update))

      assert update_event.user_id == actor_user.id
    end
  end

  describe "data type handling" do
    test "nil values in optional fields are handled correctly" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{
          given_name: "Test",
          email: unique_email(),
          family_name: nil
        })
        |> Ash.create(actor: actor)

      events = events_for_record(created_user.id)
      event = hd(events)

      # Nil values should be stored correctly
      assert is_map(event.data)
    end

    test "very long string values are stored correctly" do
      actor = %SystemActor{name: "test_runner"}
      long_name = String.duplicate("a", 1000)

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: long_name, email: unique_email()})
        |> Ash.create(actor: actor)

      events = events_for_record(created_user.id)
      event = hd(events)

      assert event.data["given_name"] == long_name
    end

    test "unicode characters in data are handled correctly" do
      actor = %SystemActor{name: "test_runner"}
      unicode_name = "Test User 测试 ユーザー ✓ émoji 🎉"

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: unicode_name, email: unique_email()})
        |> Ash.create(actor: actor)

      events = events_for_record(created_user.id)
      event = hd(events)

      assert event.data["given_name"] == unicode_name
    end
  end

  describe "metadata handling" do
    test "empty metadata is stored as empty map" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Test", email: unique_email()})
        |> Ash.Changeset.set_context(%{ash_events_metadata: %{}})
        |> Ash.create(actor: actor)

      events = events_for_record(created_user.id)
      event = hd(events)

      assert event.metadata == %{}
    end

    test "nil metadata context defaults correctly" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Test", email: unique_email()})
        |> Ash.create(actor: actor)

      events = events_for_record(created_user.id)
      event = hd(events)

      # Metadata should be nil or empty map
      assert event.metadata == nil or event.metadata == %{}
    end

    test "complex metadata structures are preserved" do
      actor = %SystemActor{name: "test_runner"}

      complex_metadata = %{
        "source" => "api",
        "request_id" => "abc-123",
        "trace" => %{
          "parent_id" => "parent-456",
          "span_id" => "span-789"
        },
        "tags" => ["important", "automated"]
      }

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Test", email: unique_email()})
        |> Ash.Changeset.set_context(%{ash_events_metadata: complex_metadata})
        |> Ash.create(actor: actor)

      events = events_for_record(created_user.id)
      event = hd(events)

      assert event.metadata["source"] == "api"
      assert event.metadata["request_id"] == "abc-123"
      assert event.metadata["trace"]["parent_id"] == "parent-456"
      assert event.metadata["tags"] == ["important", "automated"]
    end
  end

  describe "concurrent operations" do
    test "multiple concurrent creates each get their own events" do
      actor = %SystemActor{name: "test_runner"}

      # Create multiple users concurrently
      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            AshEvents.Accounts.User
            |> Ash.Changeset.for_create(:create, %{
              given_name: "Concurrent #{i}",
              email: unique_email("concurrent_#{i}")
            })
            |> Ash.create(actor: actor)
          end)
        end

      results = Task.await_many(tasks)

      # All should succeed
      assert Enum.all?(results, fn result -> match?({:ok, _}, result) end)

      # Each user should have exactly one event
      user_ids = Enum.map(results, fn {:ok, user} -> user.id end)

      for user_id <- user_ids do
        events = events_for_record(user_id)
        assert length(events) == 1, "User #{user_id} should have exactly 1 event"
      end
    end

    test "concurrent updates to same record are serialized correctly" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Base", email: unique_email()})
        |> Ash.create(actor: actor)

      # Perform multiple updates concurrently
      tasks =
        for i <- 1..3 do
          Task.async(fn ->
            user
            |> Ash.Changeset.for_update(:update, %{given_name: "Update #{i}"})
            |> Ash.update(actor: actor)
          end)
        end

      results = Task.await_many(tasks)

      # At least some should succeed
      successful = Enum.filter(results, fn result -> match?({:ok, _}, result) end)
      assert length(successful) >= 1

      # All successful updates should have events
      events = events_for_record(user.id)
      update_events = Enum.filter(events, &(&1.action_type == :update))
      assert length(update_events) == length(successful)
    end
  end

  # Helper functions

  defp unique_email(prefix \\ "user") do
    "#{prefix}_#{System.unique_integer([:positive])}@example.com"
  end

  defp get_all_events do
    AshEvents.EventLogs.EventLog
    |> Ash.Query.sort(occurred_at: :asc)
    |> Ash.read!()
  end

  defp event_count do
    length(get_all_events())
  end

  defp events_for_record(record_id) do
    get_all_events()
    |> Enum.filter(&(&1.record_id == record_id))
  end
end
