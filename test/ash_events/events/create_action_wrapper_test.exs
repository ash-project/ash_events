# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Events.CreateActionWrapperTest do
  @moduledoc """
  Tests for the CreateActionWrapper module.

  This wrapper intercepts create actions to:
  - Create events for tracking
  - Handle upsert operations
  - Skip event creation during replay mode
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.EventLogs.SystemActor

  describe "basic create operations" do
    test "creates event when record is created" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Create Test", email: unique_email()})
        |> Ash.create(actor: actor)

      events = events_for_record(created_user.id)

      assert length(events) == 1
      assert hd(events).action_type == :create
    end

    test "event contains correct record_id" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "ID Test", email: unique_email()})
        |> Ash.create(actor: actor)

      events = events_for_record(created_user.id)
      event = hd(events)

      assert event.record_id == created_user.id
    end

    test "event contains action params as data" do
      actor = %SystemActor{name: "test_runner"}
      email = unique_email()

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Params Test", email: email})
        |> Ash.create(actor: actor)

      events = events_for_record(created_user.id)
      event = hd(events)

      assert event.data["given_name"] == "Params Test"
      assert event.data["email"] == email
    end

    test "returns created record on success" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Return Test", email: unique_email()})
        |> Ash.create(actor: actor)

      assert created_user.given_name == "Return Test"
      assert created_user.id != nil
    end

    test "creates event with correct resource module" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Resource Test", email: unique_email()})
        |> Ash.create(actor: actor)

      events = events_for_record(created_user.id)
      event = hd(events)

      assert event.resource == AshEvents.Accounts.User
    end

    test "creates event with correct action name" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Action Test", email: unique_email()})
        |> Ash.create(actor: actor)

      events = events_for_record(created_user.id)
      event = hd(events)

      assert event.action == :create
    end
  end

  describe "upsert operations" do
    test "upsert creates event for new record" do
      actor = %SystemActor{name: "test_runner"}
      email = unique_email("upsert")

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create_upsert, %{given_name: "Upsert New", email: email})
        |> Ash.create(actor: actor, upsert?: true)

      events = events_for_record(created_user.id)

      assert length(events) == 1
      assert hd(events).action == :create_upsert
    end

    test "upsert creates event for updated record" do
      actor = %SystemActor{name: "test_runner"}
      email = unique_email("upsert")

      # First create
      {:ok, first_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create_upsert, %{given_name: "First Name", email: email})
        |> Ash.create(actor: actor, upsert?: true)

      # Second upsert - should update
      {:ok, second_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create_upsert, %{given_name: "Updated Name", email: email})
        |> Ash.create(actor: actor, upsert?: true)

      # Same record
      assert first_user.id == second_user.id
      assert second_user.given_name == "Updated Name"

      events = events_for_record(second_user.id)

      # Should have two events (create + update)
      assert length(events) == 2
    end
  end

  describe "replay mode" do
    test "skips event creation during replay" do
      actor = %SystemActor{name: "test_runner"}

      initial_count = user_event_count()

      # Create with replay context
      {:ok, _replayed_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{
          given_name: "Replay Create",
          email: unique_email(),
          id: Ash.UUID.generate()
        })
        |> Ash.Changeset.set_context(%{ash_events_replay?: true})
        |> Ash.create(actor: actor)

      # User event count should not increase (UserRole events may still be created)
      assert user_event_count() == initial_count
    end

    test "still creates record during replay" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, replayed_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{
          given_name: "Replay Create",
          email: unique_email(),
          id: Ash.UUID.generate()
        })
        |> Ash.Changeset.set_context(%{ash_events_replay?: true})
        |> Ash.create(actor: actor)

      assert replayed_user.given_name == "Replay Create"
      assert replayed_user.id != nil
    end
  end

  describe "error handling" do
    test "does not create event when validation fails" do
      actor = %SystemActor{name: "test_runner"}

      initial_count = event_count()

      # Create without required fields
      result =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{})
        |> Ash.create(actor: actor)

      assert {:error, _} = result
      assert event_count() == initial_count
    end
  end

  describe "timestamp handling" do
    test "uses insert timestamp for occurred_at" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{
          given_name: "Timestamp Test",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      events = events_for_record(created_user.id)
      event = hd(events)

      # Should be within 1 second of each other
      assert DateTime.diff(event.occurred_at, created_user.created_at, :second) <= 1
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

  defp user_event_count do
    get_all_events()
    |> Enum.filter(&(&1.resource == AshEvents.Accounts.User))
    |> length()
  end

  defp events_for_record(record_id) do
    get_all_events()
    |> Enum.filter(&(&1.record_id == record_id))
  end
end
