defmodule AshEvents.ChangedAttributesTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias AshEvents.Test.Accounts.UserWithAutoAttrs
  alias AshEvents.Test.Events
  alias AshEvents.Test.Events.{EventLog, SystemActor}

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
    :ok = Events.replay_events!()

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
    :ok = Events.replay_events!()

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
end
