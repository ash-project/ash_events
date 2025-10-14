# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.ChangedAttributesTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias AshEvents.Accounts.UserWithAutoAttrs
  alias AshEvents.EventLogs
  alias AshEvents.EventLogs.{EventLog, SystemActor}

  require Ash.Query

  setup do
    AshEvents.TestRepo.start_link(pool: Ecto.Adapters.SQL.Sandbox)
    Ecto.Adapters.SQL.Sandbox.mode(AshEvents.TestRepo, :manual)
    Ecto.Adapters.SQL.Sandbox.checkout(AshEvents.TestRepo)

    :ok
  end

  test "changed_attributes are stored in events" do
    user =
      UserWithAutoAttrs
      |> Ash.Changeset.for_create(:create, %{
        email: "test@example.com",
        name: "John Doe"
      })
      |> Ash.create!(actor: %SystemActor{name: "test"})

    # Fetch the created event (should be the only one)
    [event] =
      EventLog
      |> Ash.read!()

    # Verify the event is for our user
    assert event.record_id == user.id
    assert event.resource == UserWithAutoAttrs
    assert event.action == :create

    # Verify changed_attributes contains the auto-generated attributes
    assert event.changed_attributes["status"] == "active"
    assert event.changed_attributes["slug"] == "john-doe"

    # Verify original data contains only the input parameters
    assert event.data["email"] == "test@example.com"
    assert event.data["name"] == "John Doe"
    # Not in original params
    refute Map.has_key?(event.data, "status")
    # Not in original params
    refute Map.has_key?(event.data, "slug")
  end

  test "changed_attributes are applied during replay with force_change mode" do
    # Create a user which will generate auto attributes
    user =
      UserWithAutoAttrs
      |> Ash.Changeset.for_create(:create, %{
        email: "test@example.com",
        name: "Jane Doe"
      })
      |> Ash.create!(actor: %SystemActor{name: "test"})

    original_id = user.id

    # Don't manually destroy - replay_events! will clear records and replay events
    # Replay events
    :ok = EventLogs.replay_events!()

    # Verify user was recreated with correct attributes
    replayed_user = Ash.get!(UserWithAutoAttrs, original_id)

    assert replayed_user.email == "test@example.com"
    assert replayed_user.name == "Jane Doe"
    # from changed_attributes
    assert replayed_user.status == "active"
    # from changed_attributes
    assert replayed_user.slug == "jane-doe"
  end

  test "changed_attributes are tracked with AshPhoenix.Form and string keys" do
    # Create form params with string keys (typical in web forms)
    form_params = %{
      "email" => "form@example.com",
      "name" => "Form User"
      # Note: status and slug are not provided, they will be auto-generated
    }

    form =
      UserWithAutoAttrs
      |> AshPhoenix.Form.for_create(:create, actor: %SystemActor{name: "test"})
      |> AshPhoenix.Form.validate(form_params)

    {:ok, user} = AshPhoenix.Form.submit(form, params: form_params)

    # Fetch the created event
    [event] =
      EventLog
      |> Ash.read!()

    # Verify the event is for our user
    assert event.record_id == user.id
    assert event.resource == UserWithAutoAttrs
    assert event.action == :create

    # Verify changed_attributes contains the auto-generated attributes
    assert event.changed_attributes["status"] == "active"
    assert event.changed_attributes["slug"] == "form-user"

    # Verify original data contains only the form input parameters (as strings)
    assert event.data["email"] == "form@example.com"
    assert event.data["name"] == "Form User"
    # Not in original form params
    refute Map.has_key?(event.data, "status")
    # Not in original form params
    refute Map.has_key?(event.data, "slug")

    # Test replay functionality with form-created data
    :ok = EventLogs.replay_events!()

    # Verify user was recreated with correct attributes including auto-generated ones
    replayed_user = Ash.get!(UserWithAutoAttrs, user.id)

    assert replayed_user.email == "form@example.com"
    assert replayed_user.name == "Form User"
    # from changed_attributes during replay
    assert replayed_user.status == "active"
    # from changed_attributes during replay
    assert replayed_user.slug == "form-user"
  end

  test "changed_attributes are captured during updates" do
    # Create a user first
    user =
      UserWithAutoAttrs
      |> Ash.Changeset.for_create(:create, %{
        email: "test@example.com",
        name: "John Doe"
      })
      |> Ash.create!(actor: %SystemActor{name: "test"})

    # Update the user - slug will be auto-changed from the new name
    _updated_user =
      user
      |> Ash.Changeset.for_update(:update, %{name: "Jane Smith"})
      |> Ash.update!(actor: %SystemActor{name: "test"})

    # Get the event for the update action
    update_event =
      EventLog
      |> Ash.Query.filter(resource == UserWithAutoAttrs and action == :update)
      |> Ash.read_one!()

    # The slug should be in changed_attributes since it's auto-generated
    assert update_event.changed_attributes["slug"] == "jane-smith"
    # The name should be in data since it was in the original params
    assert update_event.data["name"] == "Jane Smith"
    # Status shouldn't be in data since it wasn't changed in this update
    refute Map.has_key?(update_event.data, "status")
    refute Map.has_key?(update_event.changed_attributes, "status")
  end

  test "attributes present in original params are not duplicated in changed_attributes" do
    _user =
      UserWithAutoAttrs
      |> Ash.Changeset.for_create(:create, %{
        email: "test@example.com",
        name: "John Doe",
        # Explicitly set status
        status: "pending"
      })
      |> Ash.create!(actor: %SystemActor{name: "test"})

    event =
      EventLog
      |> Ash.Query.filter(resource == UserWithAutoAttrs and action == :create)
      |> Ash.read_one!()

    # Status was in original params, so it should be in data
    assert event.data["status"] == "pending"
    # Slug was auto-generated, so it should be in changed_attributes
    assert event.changed_attributes["slug"] == "john-doe"
    # Slug should NOT be in data since it wasn't in original params
    refute Map.has_key?(event.data, "slug")
  end

  test "AshPhoenix.Form with explicit auto-generated parameters" do
    # Create a form with params that include an explicit status
    form_params = %{
      "email" => "form@example.com",
      "name" => "Form User",
      # Explicitly setting status (which normally defaults to "active")
      "status" => "inactive"
    }

    form =
      UserWithAutoAttrs
      |> AshPhoenix.Form.for_create(:create, actor: %SystemActor{name: "test"})
      |> AshPhoenix.Form.validate(form_params)

    {:ok, _user} = AshPhoenix.Form.submit(form, params: form_params)

    event =
      EventLog
      |> Ash.Query.filter(resource == UserWithAutoAttrs and action == :create)
      |> Ash.read_one!()

    # Status was explicitly provided via form, should be in event data with provided value
    assert event.data["status"] == "inactive"
    # Slug was auto-generated but not in original form params, should be in changed_attributes
    assert event.changed_attributes["slug"] == "form-user"
    # Regular attributes should be present in data
    assert event.data["email"] == "form@example.com"
    assert event.data["name"] == "Form User"
  end

  test ":as_arguments strategy during replay merges changed_attributes as action arguments" do
    # Create a user first
    user =
      UserWithAutoAttrs
      |> Ash.Changeset.for_create(:create, %{
        email: "test@example.com",
        name: "John Doe"
      })
      |> Ash.create!(actor: %SystemActor{name: "test"})

    # Update the user - this will use the :as_arguments strategy
    # The slug will be auto-generated and stored in changed_attributes
    updated_user =
      user
      |> Ash.Changeset.for_update(:update, %{name: "Jane Smith"})
      |> Ash.update!(actor: %SystemActor{name: "test"})

    # Verify the update worked as expected
    assert updated_user.name == "Jane Smith"
    assert updated_user.slug == "jane-smith"

    # Get the update event to verify changed_attributes
    update_event =
      EventLog
      |> Ash.Query.filter(resource == UserWithAutoAttrs and action == :update)
      |> Ash.read_one!()

    # Verify the event structure
    assert update_event.data["name"] == "Jane Smith"
    assert update_event.changed_attributes["slug"] == "jane-smith"

    # Clear all records and replay events
    :ok = EventLogs.replay_events!()

    # Verify user was recreated with correct attributes
    replayed_user = Ash.get!(UserWithAutoAttrs, user.id)

    # With :as_arguments strategy, the changed_attributes should have been merged
    # into the update action arguments during replay
    assert replayed_user.name == "Jane Smith"
    assert replayed_user.slug == "jane-smith"
    assert replayed_user.email == "test@example.com"
  end

  test "as_arguments strategy vs force_change strategy behavior difference" do
    # First test create (uses :force_change) - auto-generated attributes go to changed_attributes
    user =
      UserWithAutoAttrs
      |> Ash.Changeset.for_create(:create, %{
        email: "test@example.com",
        name: "Test User"
      })
      |> Ash.create!(actor: %SystemActor{name: "test"})

    create_event =
      EventLog
      |> Ash.Query.filter(resource == UserWithAutoAttrs and action == :create)
      |> Ash.read_one!()

    # With create (:force_change), auto-generated attributes are in changed_attributes
    assert create_event.data["name"] == "Test User"
    assert create_event.changed_attributes["slug"] == "test-user"
    refute Map.has_key?(create_event.data, "slug")

    # Now test update (uses :as_arguments) - auto-generated attributes still go to changed_attributes
    _updated_user =
      user
      |> Ash.Changeset.for_update(:update, %{name: "Updated User"})
      |> Ash.update!(actor: %SystemActor{name: "test"})

    update_event =
      EventLog
      |> Ash.Query.filter(resource == UserWithAutoAttrs and action == :update)
      |> Ash.read_one!()

    # With update (:as_arguments), input params are in data, auto-generated in changed_attributes
    assert update_event.data["name"] == "Updated User"
    assert update_event.changed_attributes["slug"] == "updated-user"
    refute Map.has_key?(update_event.data, "slug")

    # Test replay behavior - both strategies should produce the same final result
    :ok = EventLogs.replay_events!()

    replayed_user = Ash.get!(UserWithAutoAttrs, user.id)

    # Final result should be the same regardless of strategy
    assert replayed_user.name == "Updated User"
    assert replayed_user.slug == "updated-user"
    assert replayed_user.email == "test@example.com"
  end

  test "as_arguments strategy passes changed_attributes as required arguments during replay" do
    # Generate a user ID for testing
    user_id = Ash.UUID.generate()

    # Manually create events for testing - first a create event
    create_event = %{
      action: :create,
      action_type: :create,
      resource: UserWithAutoAttrs,
      record_id: user_id,
      data: %{"email" => "test@example.com", "name" => "John Doe"},
      changed_attributes: %{"status" => "active", "slug" => "john-doe"},
      system_actor: "test",
      occurred_at: DateTime.utc_now()
    }

    # Create an update event with the required slug argument in changed_attributes
    # This simulates what would happen when using :as_arguments strategy
    update_event = %{
      action: :update_with_required_slug,
      action_type: :update,
      resource: UserWithAutoAttrs,
      record_id: user_id,
      data: %{"name" => "Jane Smith"},
      # Required argument stored here
      changed_attributes: %{"slug" => "custom-slug"},
      system_actor: "test",
      occurred_at: DateTime.utc_now()
    }

    # Insert both events
    EventLog |> Ash.Changeset.for_create(:create, create_event) |> Ash.create!()
    EventLog |> Ash.Changeset.for_create(:create, update_event) |> Ash.create!()

    # Clear records and replay events
    :ok = EventLogs.replay_events!()

    # Verify the replayed user has the correct attributes
    # This test specifically verifies that the required slug argument was passed during replay
    replayed_user = Ash.get!(UserWithAutoAttrs, user_id)
    assert replayed_user.name == "Jane Smith"
    assert replayed_user.slug == "custom-slug"
    assert replayed_user.email == "test@example.com"
  end

  test "as_arguments strategy would fail if required argument is not provided during replay" do
    # Generate a user ID for testing
    user_id = Ash.UUID.generate()

    # First create a proper create event to establish the user
    create_event = %{
      action: :create,
      action_type: :create,
      resource: UserWithAutoAttrs,
      record_id: user_id,
      data: %{"email" => "test@example.com", "name" => "John Doe"},
      changed_attributes: %{"status" => "active", "slug" => "john-doe"},
      system_actor: "test",
      occurred_at: DateTime.utc_now()
    }

    # Create an update event for the update_with_required_slug action without a slug in changed_attributes
    # This simulates what would happen if changed_attributes didn't capture the required argument
    update_event_bad = %{
      action: :update_with_required_slug,
      action_type: :update,
      resource: UserWithAutoAttrs,
      record_id: user_id,
      data: %{"name" => "Manual Update"},
      # Empty - no slug provided (this should cause failure)
      changed_attributes: %{},
      system_actor: "test",
      occurred_at: DateTime.utc_now()
    }

    # Insert both events
    EventLog |> Ash.Changeset.for_create(:create, create_event) |> Ash.create!()
    EventLog |> Ash.Changeset.for_create(:create, update_event_bad) |> Ash.create!()

    # Attempting to replay should fail because the required slug argument is missing
    assert_raise Ash.Error.Invalid, ~r/argument slug is required/, fn ->
      EventLogs.replay_events!()
    end
  end
end
