defmodule AshEvents.TrackAutoChangedAttributesTest do
  use AshEvents.RepoCase, async: false

  alias AshEvents.Test.Accounts.UserWithAutoAttrs
  alias AshEvents.Test.Events
  alias AshEvents.Test.Events.EventLog
  alias AshEvents.Test.Events.SystemActor

  require Ash.Query

  test "auto-changed attributes are tracked in event data" do
    # Create a user - the status will be auto-set to "active" and slug will be generated from name
    user =
      UserWithAutoAttrs
      |> Ash.Changeset.for_create(:create, %{
        email: "test@example.com",
        name: "John Doe"
      })
      |> Ash.create!(actor: %SystemActor{name: "test"})

    event =
      EventLog
      |> Ash.Query.filter(resource == UserWithAutoAttrs and action == :create)
      |> Ash.read_one!()

    assert event.data["status"] == "active"
    assert event.data["slug"] == "john-doe"
    assert event.data["email"] == "test@example.com"
    assert event.data["name"] == "John Doe"

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

    assert update_event.data["slug"] == "jane-smith"
    assert update_event.data["name"] == "Jane Smith"
    refute Map.has_key?(update_event.data, "status")
  end

  test "attributes present in original params are not duplicated" do
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

    assert event.data["status"] == "pending"
    assert event.data["slug"] == "john-doe"
  end

  test "works with AshPhoenix.Form" do
    # Create a form with params
    form_params = %{
      "email" => "form@example.com",
      "name" => "Form User",
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
    # Slug was auto-generated but not in original form params, should be tracked
    assert event.data["slug"] == "form-user"
    # Regular attributes should be present
    assert event.data["email"] == "form@example.com"
    assert event.data["name"] == "Form User"
  end

  test "event replay works with auto-changed attributes" do
    _user =
      UserWithAutoAttrs
      |> Ash.Changeset.for_create(:create, %{
        email: "test@example.com",
        name: "John Doe"
      })
      |> Ash.create!(actor: %SystemActor{name: "test"})

    Ash.bulk_destroy!(UserWithAutoAttrs, :destroy, %{}, strategy: :stream, return_errors?: true)

    :ok = Events.replay_events!()

    replayed_user = Ash.read_one!(UserWithAutoAttrs)
    assert replayed_user.email == "test@example.com"
    assert replayed_user.name == "John Doe"
    assert replayed_user.status == "active"
    assert replayed_user.slug == "john-doe"
  end
end
