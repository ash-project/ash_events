# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Events.DestroyActionWrapperTest do
  @moduledoc """
  Tests for the DestroyActionWrapper module.

  This wrapper intercepts destroy actions to:
  - Create events for tracking deletions
  - Return the destroyed record
  - Skip event creation during replay mode

  Note: Tests use `create_with_form` action to avoid UserRole dependencies
  that would cause FK constraint violations on destroy.
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.EventLogs.SystemActor

  describe "basic destroy operations" do
    test "creates event when record is destroyed" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create_with_form, %{
          given_name: "To Delete",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      record_id = created_user.id

      {:ok, _destroyed} =
        created_user
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.destroy(actor: actor, return_destroyed?: true)

      events = events_for_record(record_id)
      destroy_events = Enum.filter(events, &(&1.action_type == :destroy))

      assert length(destroy_events) == 1
    end

    test "event contains correct record_id" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create_with_form, %{
          given_name: "To Delete",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      record_id = created_user.id

      {:ok, _destroyed} =
        created_user
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.destroy(actor: actor, return_destroyed?: true)

      events = events_for_record(record_id)
      destroy_event = Enum.find(events, &(&1.action_type == :destroy))

      assert destroy_event.record_id == record_id
    end

    test "event contains correct action type" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create_with_form, %{
          given_name: "To Delete",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      record_id = created_user.id

      {:ok, _destroyed} =
        created_user
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.destroy(actor: actor, return_destroyed?: true)

      events = events_for_record(record_id)
      destroy_event = Enum.find(events, &(&1.action_type == :destroy))

      assert destroy_event.action == :destroy
      assert destroy_event.action_type == :destroy
    end

    test "returns destroyed record" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create_with_form, %{
          given_name: "To Delete",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      {:ok, destroyed} =
        created_user
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.destroy(actor: actor, return_destroyed?: true)

      assert destroyed.id == created_user.id
      assert destroyed.given_name == "To Delete"
    end

    test "record is actually deleted" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create_with_form, %{
          given_name: "To Delete",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      record_id = created_user.id

      {:ok, _destroyed} =
        created_user
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.destroy(actor: actor, return_destroyed?: true)

      # Should not be able to find the record
      result = Ash.get(AshEvents.Accounts.User, record_id, actor: actor)
      assert {:error, _} = result
    end
  end

  describe "full lifecycle" do
    test "create, update, destroy creates three events" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create_with_form, %{
          given_name: "Lifecycle Test",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      {:ok, updated_user} =
        created_user
        |> Ash.Changeset.for_update(:update, %{given_name: "Updated Name"})
        |> Ash.update(actor: actor)

      record_id = updated_user.id

      {:ok, _destroyed} =
        updated_user
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.destroy(actor: actor, return_destroyed?: true)

      events = events_for_record(record_id)

      assert length(events) == 3

      action_types = Enum.map(events, & &1.action_type)
      assert :create in action_types
      assert :update in action_types
      assert :destroy in action_types
    end

    test "events are in chronological order" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create_with_form, %{
          given_name: "Lifecycle Test",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      Process.sleep(10)

      {:ok, updated_user} =
        created_user
        |> Ash.Changeset.for_update(:update, %{given_name: "Updated"})
        |> Ash.update(actor: actor)

      Process.sleep(10)

      record_id = updated_user.id

      {:ok, _destroyed} =
        updated_user
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.destroy(actor: actor, return_destroyed?: true)

      events =
        events_for_record(record_id)
        |> Enum.sort_by(& &1.occurred_at, DateTime)

      [first, second, third] = events

      assert first.action_type == :create
      assert second.action_type == :update
      assert third.action_type == :destroy

      assert DateTime.compare(first.occurred_at, second.occurred_at) in [:lt, :eq]
      assert DateTime.compare(second.occurred_at, third.occurred_at) in [:lt, :eq]
    end
  end

  describe "replay mode" do
    test "skips event creation during replay" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create_with_form, %{
          given_name: "To Delete",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      initial_count = event_count()

      # Destroy with replay context
      {:ok, _destroyed} =
        created_user
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.Changeset.set_context(%{ash_events_replay?: true})
        |> Ash.destroy(actor: actor, return_destroyed?: true)

      # Event count should not increase
      assert event_count() == initial_count
    end

    test "still destroys record during replay" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create_with_form, %{
          given_name: "To Delete",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      record_id = created_user.id

      {:ok, _destroyed} =
        created_user
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.Changeset.set_context(%{ash_events_replay?: true})
        |> Ash.destroy(actor: actor, return_destroyed?: true)

      # Should not be able to find the record
      result = Ash.get(AshEvents.Accounts.User, record_id, actor: actor)
      assert {:error, _} = result
    end
  end

  describe "actor attribution" do
    test "user can destroy themselves and actor is recorded" do
      # Users can only destroy themselves (policy: id == actor.id)
      # So we test that a user destroying themselves has their id recorded
      system_actor = %SystemActor{name: "test_runner"}

      {:ok, user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create_with_form, %{
          given_name: "Self Destroyer",
          email: unique_email()
        })
        |> Ash.create(actor: system_actor)

      record_id = user.id

      # User destroys themselves
      {:ok, _destroyed} =
        user
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.destroy(actor: user, return_destroyed?: true)

      events = events_for_record(record_id)
      destroy_event = Enum.find(events, &(&1.action_type == :destroy))

      assert destroy_event.user_id == user.id
    end

    test "system actor does not set user_id on destroy" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create_with_form, %{
          given_name: "To Delete",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      record_id = created_user.id

      {:ok, _destroyed} =
        created_user
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.destroy(actor: actor, return_destroyed?: true)

      events = events_for_record(record_id)
      destroy_event = Enum.find(events, &(&1.action_type == :destroy))

      # SystemActor doesn't match User type, so user_id should be nil
      assert destroy_event.user_id == nil
      assert destroy_event.system_actor == "test_runner"
    end
  end

  describe "timestamp handling" do
    test "destroy uses current timestamp for occurred_at" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create_with_form, %{
          given_name: "To Delete",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      record_id = created_user.id
      before_destroy = DateTime.utc_now()

      {:ok, _destroyed} =
        created_user
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.destroy(actor: actor, return_destroyed?: true)

      after_destroy = DateTime.utc_now()

      events = events_for_record(record_id)
      destroy_event = Enum.find(events, &(&1.action_type == :destroy))

      # occurred_at should be between before and after destroy
      assert DateTime.compare(destroy_event.occurred_at, before_destroy) in [:eq, :gt]
      assert DateTime.compare(destroy_event.occurred_at, after_destroy) in [:eq, :lt]
    end
  end

  describe "resource tracking" do
    test "destroy event stores correct resource" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create_with_form, %{
          given_name: "To Delete",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      record_id = created_user.id

      {:ok, _destroyed} =
        created_user
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.destroy(actor: actor, return_destroyed?: true)

      events = events_for_record(record_id)
      destroy_event = Enum.find(events, &(&1.action_type == :destroy))

      assert destroy_event.resource == AshEvents.Accounts.User
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
