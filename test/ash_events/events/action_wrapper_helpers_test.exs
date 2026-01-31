# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Events.ActionWrapperHelpersTest do
  @moduledoc """
  Tests for the ActionWrapperHelpers module.

  This module provides helper functions used by the action wrappers:
  - dump_value/2 for converting values to storable format
  - get_occurred_at/2 for determining event timestamps
  - create_event!/5 for creating event records
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.Events.ActionWrapperHelpers
  alias AshEvents.EventLogs.SystemActor

  describe "dump_value/2" do
    test "returns nil for nil values" do
      # Create a mock attribute
      attribute = %{type: :string, constraints: []}

      assert ActionWrapperHelpers.dump_value(nil, attribute) == nil
    end

    test "dumps string values correctly" do
      attributes = Ash.Resource.Info.attributes(AshEvents.Accounts.User)
      given_name_attr = Enum.find(attributes, &(&1.name == :given_name))

      dumped = ActionWrapperHelpers.dump_value("John", given_name_attr)

      assert dumped == "John"
    end

    test "dumps integer values correctly" do
      # Create an integer attribute mock
      attribute = %{type: :integer, constraints: []}

      dumped = ActionWrapperHelpers.dump_value(42, attribute)

      assert dumped == 42
    end

    test "dumps UUID values correctly" do
      attributes = Ash.Resource.Info.attributes(AshEvents.Accounts.User)
      id_attr = Enum.find(attributes, &(&1.name == :id))

      uuid = Ash.UUID.generate()
      dumped = ActionWrapperHelpers.dump_value(uuid, id_attr)

      assert is_binary(dumped)
    end

    test "dumps datetime values correctly" do
      attributes = Ash.Resource.Info.attributes(AshEvents.Accounts.User)
      created_at_attr = Enum.find(attributes, &(&1.name == :created_at))

      now = DateTime.utc_now()
      dumped = ActionWrapperHelpers.dump_value(now, created_at_attr)

      assert %DateTime{} = dumped
    end

    test "dumps array types correctly" do
      # Create an array attribute mock
      attribute = %{type: {:array, :string}, constraints: [items: []]}

      values = ["one", "two", "three"]
      dumped = ActionWrapperHelpers.dump_value(values, attribute)

      assert dumped == ["one", "two", "three"]
    end

    test "dumps array of integers correctly" do
      attribute = %{type: {:array, :integer}, constraints: [items: []]}

      values = [1, 2, 3]
      dumped = ActionWrapperHelpers.dump_value(values, attribute)

      assert dumped == [1, 2, 3]
    end

    test "dumps empty array correctly" do
      attribute = %{type: {:array, :string}, constraints: [items: []]}

      dumped = ActionWrapperHelpers.dump_value([], attribute)

      assert dumped == []
    end
  end

  describe "get_occurred_at/2" do
    test "returns timestamp from changeset when present" do
      actor = %SystemActor{name: "test_runner"}

      # Create with explicit timestamp
      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Test", email: unique_email()})
        |> Ash.create(actor: actor)

      # The timestamp should be from the created_at attribute
      assert created_user.created_at != nil
    end

    test "returns current time when changeset attribute is nil" do
      before = DateTime.utc_now(:microsecond)

      # Create a changeset without a timestamp
      changeset =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Test", email: unique_email()})

      occurred_at = ActionWrapperHelpers.get_occurred_at(changeset, :nonexistent_field)
      after_time = DateTime.utc_now(:microsecond)

      assert DateTime.compare(occurred_at, before) in [:eq, :gt]
      assert DateTime.compare(occurred_at, after_time) in [:eq, :lt]
    end
  end

  describe "event creation through wrappers" do
    test "create action wrapper creates event with correct data" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Event Test", email: unique_email()})
        |> Ash.create(actor: actor)

      events = get_all_events()
      event = Enum.find(events, &(&1.record_id == created_user.id))

      assert event != nil
      assert event.resource == AshEvents.Accounts.User
      assert event.action == :create
      assert event.action_type == :create
      assert event.data["given_name"] == "Event Test"
    end

    test "update action wrapper creates event with correct data" do
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

      assert update_event != nil
      assert update_event.resource == AshEvents.Accounts.User
      assert update_event.action == :update
      assert update_event.data["given_name"] == "Updated"
    end

    test "destroy action wrapper creates event" do
      actor = %SystemActor{name: "test_runner"}

      # Use create_with_form to avoid UserRole dependency
      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create_with_form, %{
          given_name: "To Delete",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      record_id = created_user.id

      {:ok, _} =
        created_user
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.destroy(actor: actor, return_destroyed?: true)

      events = events_for_record(record_id)
      destroy_event = Enum.find(events, &(&1.action_type == :destroy))

      assert destroy_event != nil
      assert destroy_event.resource == AshEvents.Accounts.User
      assert destroy_event.action == :destroy
    end
  end

  describe "event data handling" do
    test "params are properly dumped to storable format" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Dump Test", email: unique_email()})
        |> Ash.create(actor: actor)

      events = events_for_record(created_user.id)
      event = hd(events)

      # Event data should be serializable (no Elixir structs)
      assert is_map(event.data)
      assert is_binary(event.data["given_name"])
      assert is_binary(event.data["email"])
    end

    test "string keys are converted to atoms when matching attributes" do
      actor = %SystemActor{name: "test_runner"}

      # Create with string keys (as would come from a form)
      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{
          "given_name" => "String Key",
          "email" => unique_email()
        })
        |> Ash.create(actor: actor)

      events = events_for_record(created_user.id)
      event = hd(events)

      # Params should be stored with atom keys
      assert event.data["given_name"] == "String Key"
    end

    test "changed_attributes excludes params that were explicitly provided" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Test", email: unique_email()})
        |> Ash.create(actor: actor)

      events = events_for_record(created_user.id)
      event = hd(events)

      # given_name and email were in original params, so shouldn't be in changed_attributes
      refute Map.has_key?(event.changed_attributes, :given_name) or
               Map.has_key?(event.changed_attributes, "given_name")

      refute Map.has_key?(event.changed_attributes, :email) or
               Map.has_key?(event.changed_attributes, "email")
    end

    test "metadata is included in event" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Metadata Test", email: unique_email()})
        |> Ash.Changeset.set_context(%{ash_events_metadata: %{source: "test", request_id: "123"}})
        |> Ash.create(actor: actor)

      events = events_for_record(created_user.id)
      event = hd(events)

      assert event.metadata["source"] == "test"
      assert event.metadata["request_id"] == "123"
    end
  end

  describe "actor attribution" do
    test "actor primary key is stored when user updates themselves" do
      # Create a user with SystemActor, then have them update themselves
      # This works because the policy allows users to update themselves (id == actor.id)
      system_actor = %SystemActor{name: "test_runner"}

      {:ok, user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Self Updater", email: unique_email()})
        |> Ash.create(actor: system_actor)

      # User updates themselves - this should record user.id as the actor
      {:ok, updated_user} =
        user
        |> Ash.Changeset.for_update(:update, %{given_name: "Updated Name"})
        |> Ash.update(actor: user)

      events = events_for_record(updated_user.id)
      update_event = Enum.find(events, &(&1.action_type == :update))

      # Should have actor's ID stored since they match the persist_actor_primary_key type
      assert update_event.user_id == user.id
    end

    test "actor field is nil when actor doesn't match configured type" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "No Actor", email: unique_email()})
        |> Ash.create(actor: actor)

      events = events_for_record(created_user.id)
      event = hd(events)

      # Actor field should be nil since the actor type doesn't match User
      assert event.user_id == nil
      # But system_actor should be recorded
      assert event.system_actor == "test_runner"
    end
  end

  describe "version tracking" do
    test "events include correct version number" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Version Test", email: unique_email()})
        |> Ash.create(actor: actor)

      events = events_for_record(created_user.id)
      event = hd(events)

      # Version should match the configured version for create action
      create_version =
        AshEvents.Events.Info.events_current_action_versions!(AshEvents.Accounts.User)
        |> Keyword.get(:create, 1)

      assert event.version == create_version
    end
  end

  describe "replay mode" do
    test "events are not created during replay mode" do
      actor = %SystemActor{name: "test_runner"}

      initial_user_event_count = user_event_count()

      # Simulate replay mode by setting context - no event should be created
      {:ok, _replayed_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{
          given_name: "Replayed User",
          email: unique_email(),
          id: Ash.UUID.generate()
        })
        |> Ash.Changeset.set_context(%{ash_events_replay?: true})
        |> Ash.create(actor: actor)

      # User event count should not change during replay (UserRole events may still be created)
      assert user_event_count() == initial_user_event_count
    end
  end

  describe "timestamp handling" do
    test "create timestamp uses configured attribute" do
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

      # occurred_at should be close to created_at
      assert DateTime.diff(event.occurred_at, created_user.created_at, :second) <= 1
    end

    test "update timestamp uses configured attribute" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, created_user} =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(:create, %{given_name: "Update Time", email: unique_email()})
        |> Ash.create(actor: actor)

      # Small delay to ensure different timestamps
      Process.sleep(10)

      {:ok, updated_user} =
        created_user
        |> Ash.Changeset.for_update(:update, %{given_name: "Updated"})
        |> Ash.update(actor: actor)

      events = events_for_record(updated_user.id)
      update_event = Enum.find(events, &(&1.action_type == :update))

      # occurred_at should be close to updated_at
      assert DateTime.diff(update_event.occurred_at, updated_user.updated_at, :second) <= 1
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
