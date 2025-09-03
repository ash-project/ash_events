defmodule AshEvents.DefaultsTest do
  alias AshEvents.Test.Events.SystemActor
  use AshEvents.RepoCase, async: false

  alias AshEvents.Test.Accounts
  alias AshEvents.Test.Accounts.User
  alias AshEvents.Test.Events.EventLog

  require Ash.Query

  def create_user do
    Accounts.create_user!(
      %{
        email: "user@example.com",
        given_name: "John",
        family_name: "Doe"
      },
      context: %{ash_events_metadata: %{source: "Signup form"}},
      actor: %SystemActor{name: "test_runner"}
    )
  end

  test "update_default values are applied as expected" do
    user = create_user()
    initial_updated_at = user.updated_at

    updated_user =
      Accounts.update_user!(
        user,
        %{given_name: "Updated"},
        actor: %SystemActor{name: "test_update_default"}
      )

    assert updated_user.updated_at > initial_updated_at,
           "updated_at should be automatically updated by update_default, but it was not. " <>
             "Initial: #{initial_updated_at}, After update: #{updated_user.updated_at}"

    # Verify that events were created with the applied defaults
    [event] =
      EventLog
      |> Ash.Query.filter(resource == ^User and data[:given_name] == "Updated")
      |> Ash.read!()

    assert event.data["updated_at"] != nil, "Event data should contain the updated_at timestamp"
  end

  test "default values work correctly with Events extension" do
    user =
      Accounts.create_user!(
        %{
          email: "create_test@example.com",
          given_name: "Create",
          family_name: "Test"
        },
        actor: %SystemActor{name: "test_create_default"}
      )

    assert user.created_at != nil, "created_at should be automatically set by create_timestamp"
    assert is_struct(user.created_at, DateTime), "created_at should be a DateTime"

    events =
      EventLog
      |> Ash.Query.filter(resource == ^User and data[:email] == "create_test@example.com")
      |> Ash.read!()

    assert length(events) > 0, "Events should be created for user creation"
  end
end
