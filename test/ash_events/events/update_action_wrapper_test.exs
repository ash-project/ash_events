# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Events.UpdateActionWrapperTest do
  @moduledoc """
  Tests for the UpdateActionWrapper module.

  This wrapper intercepts update actions to:
  - Create events for tracking changes
  - Record changed attributes
  - Skip event creation during replay mode
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.EventLogs.SystemActor

  describe "basic update operations" do
    test "creates event when record is updated" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Original", email: unique_email()})
        |> Ash.create(actor: actor)

      {:ok, updated_user} =
        created_user
        |> Ash.Changeset.for_update(:update, %{given_name: "Updated"})
        |> Ash.update(actor: actor)

      events = events_for_record(updated_user.id)
      update_events = Enum.filter(events, &(&1.action_type == :update))

      assert length(update_events) == 1
    end

    test "event contains updated params as data" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Original", email: unique_email()})
        |> Ash.create(actor: actor)

      {:ok, updated_user} =
        created_user
        |> Ash.Changeset.for_update(:update, %{given_name: "New Name"})
        |> Ash.update(actor: actor)

      events = events_for_record(updated_user.id)
      update_event = Enum.find(events, &(&1.action_type == :update))

      assert update_event.data["given_name"] == "New Name"
    end

    test "preserves record_id across updates" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Original", email: unique_email()})
        |> Ash.create(actor: actor)

      {:ok, updated_user} =
        created_user
        |> Ash.Changeset.for_update(:update, %{given_name: "Updated"})
        |> Ash.update(actor: actor)

      events = events_for_record(updated_user.id)
      update_event = Enum.find(events, &(&1.action_type == :update))

      assert update_event.record_id == created_user.id
      assert update_event.record_id == updated_user.id
    end

    test "creates event with correct action name" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Original", email: unique_email()})
        |> Ash.create(actor: actor)

      {:ok, updated_user} =
        created_user
        |> Ash.Changeset.for_update(:update, %{given_name: "Updated"})
        |> Ash.update(actor: actor)

      events = events_for_record(updated_user.id)
      update_event = Enum.find(events, &(&1.action_type == :update))

      assert update_event.action == :update
      assert update_event.action_type == :update
    end
  end

  describe "multiple updates" do
    test "each update creates a separate event" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "V1", email: unique_email()})
        |> Ash.create(actor: actor)

      {:ok, user_v2} =
        created_user
        |> Ash.Changeset.for_update(:update, %{given_name: "V2"})
        |> Ash.update(actor: actor)

      {:ok, user_v3} =
        user_v2
        |> Ash.Changeset.for_update(:update, %{given_name: "V3"})
        |> Ash.update(actor: actor)

      events = events_for_record(user_v3.id)
      update_events = Enum.filter(events, &(&1.action_type == :update))

      assert length(update_events) == 2
    end

    test "events are ordered chronologically" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "First", email: unique_email()})
        |> Ash.create(actor: actor)

      {:ok, updated_user} =
        created_user
        |> Ash.Changeset.for_update(:update, %{given_name: "Second"})
        |> Ash.update(actor: actor)

      events =
        events_for_record(updated_user.id)
        |> Enum.sort_by(& &1.occurred_at, DateTime)

      [first_event, second_event] = events

      assert first_event.action_type == :create
      assert second_event.action_type == :update
      assert DateTime.compare(first_event.occurred_at, second_event.occurred_at) in [:lt, :eq]
    end
  end

  describe "replay mode" do
    test "skips event creation during replay" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Original", email: unique_email()})
        |> Ash.create(actor: actor)

      initial_count = event_count()

      # Update with replay context
      {:ok, _updated_user} =
        created_user
        |> Ash.Changeset.for_update(:update, %{given_name: "Replay Update"})
        |> Ash.Changeset.set_context(%{ash_events_replay?: true})
        |> Ash.update(actor: actor)

      # Event count should not increase
      assert event_count() == initial_count
    end

    test "still updates record during replay" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Original", email: unique_email()})
        |> Ash.create(actor: actor)

      {:ok, updated_user} =
        created_user
        |> Ash.Changeset.for_update(:update, %{given_name: "Replay Updated"})
        |> Ash.Changeset.set_context(%{ash_events_replay?: true})
        |> Ash.update(actor: actor)

      assert updated_user.given_name == "Replay Updated"
    end
  end

  describe "timestamp handling" do
    test "uses update timestamp for occurred_at" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Original", email: unique_email()})
        |> Ash.create(actor: actor)

      Process.sleep(10)

      {:ok, updated_user} =
        created_user
        |> Ash.Changeset.for_update(:update, %{given_name: "Updated"})
        |> Ash.update(actor: actor)

      events = events_for_record(updated_user.id)
      update_event = Enum.find(events, &(&1.action_type == :update))

      # Should be within 1 second of updated_at
      assert DateTime.diff(update_event.occurred_at, updated_user.updated_at, :second) <= 1
    end

    test "update event occurred_at is after create event occurred_at" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Original", email: unique_email()})
        |> Ash.create(actor: actor)

      Process.sleep(10)

      {:ok, updated_user} =
        created_user
        |> Ash.Changeset.for_update(:update, %{given_name: "Updated"})
        |> Ash.update(actor: actor)

      events = events_for_record(updated_user.id)
      create_event = Enum.find(events, &(&1.action_type == :create))
      update_event = Enum.find(events, &(&1.action_type == :update))

      assert DateTime.compare(create_event.occurred_at, update_event.occurred_at) in [:lt, :eq]
    end
  end

  describe "actor attribution" do
    test "user updating themselves has actor recorded" do
      # Users can only update themselves (policy: id == actor.id)
      system_actor = %SystemActor{name: "test_runner"}

      {:ok, user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Self Updater", email: unique_email()})
        |> Ash.create(actor: system_actor)

      # User updates themselves
      {:ok, updated_user} =
        user
        |> Ash.Changeset.for_update(:update, %{given_name: "Updated"})
        |> Ash.update(actor: user)

      events = events_for_record(updated_user.id)
      update_event = Enum.find(events, &(&1.action_type == :update))

      assert update_event.user_id == user.id
    end

    test "system actor does not set user_id on update" do
      system_actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Original", email: unique_email()})
        |> Ash.create(actor: system_actor)

      {:ok, updated_user} =
        created_user
        |> Ash.Changeset.for_update(:update, %{given_name: "Updated"})
        |> Ash.update(actor: system_actor)

      events = events_for_record(updated_user.id)
      update_event = Enum.find(events, &(&1.action_type == :update))

      # SystemActor doesn't match User type, so user_id should be nil
      assert update_event.user_id == nil
      assert update_event.system_actor == "test_runner"
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
