defmodule AshEvents.UpsertTest do
  alias AshEvents.Test.Events.SystemActor
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts
  alias AshEvents.Accounts.User
  alias AshEvents.Events
  alias AshEvents.Test.Events.EventLog

  require Ash.Query

  test "upsert action generates events correctly for both create and update paths" do
    # First upsert - should create a new record and generate a create event
    user1 =
      Accounts.create_user_upsert!(
        %{
          email: "upsert@example.com",
          given_name: "Initial",
          family_name: "User"
        },
        actor: %SystemActor{name: "test_upsert"}
      )

    # Second upsert with same email but different names - should update existing record
    user2 =
      Accounts.create_user_upsert!(
        %{
          email: "upsert@example.com",
          given_name: "Updated",
          family_name: "Person"
        },
        actor: %SystemActor{name: "test_upsert"}
      )

    # Both operations should return the same record ID (upsert updated the existing record)
    assert user1.id == user2.id
    assert user2.given_name == "Updated"
    assert user2.family_name == "Person"

    # Check events created - both upserts should generate create-type events
    # This is because Ash upserts are conceptually "create" actions, not update actions
    events =
      EventLog
      |> Ash.Query.filter(resource == ^User and data[:email] == "upsert@example.com")
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    # Should have exactly 2 create events (one for each upsert call)
    assert length(events) == 2

    [first_event, second_event] = events

    # First event - actual create
    assert first_event.action == :create_upsert
    assert first_event.system_actor == "test_upsert"
    assert first_event.data["given_name"] == "Initial"
    assert first_event.data["family_name"] == "User"
    assert first_event.data["email"] == "upsert@example.com"

    # Second event - upsert that updated existing record, but still shows as create action
    assert second_event.action == :create_upsert
    assert second_event.system_actor == "test_upsert"
    assert second_event.data["given_name"] == "Updated"
    assert second_event.data["family_name"] == "Person"
    assert second_event.data["email"] == "upsert@example.com"

    # Verify event replay works correctly with upserts
    :ok = Events.replay_events!()

    # After replay, should still have the updated values
    replayed_user = Accounts.get_user_by_id!(user2.id, actor: %SystemActor{name: "test_replay"})
    assert replayed_user.given_name == "Updated"
    assert replayed_user.family_name == "Person"
    assert replayed_user.email == "upsert@example.com"
  end

  test "auto-generated replay update action is created for upsert actions" do
    # Check that the auto-generated replay update action exists
    actions = User |> Ash.Resource.Info.actions()
    replay_action = Enum.find(actions, &(&1.name == :ash_events_replay_create_upsert_update))

    assert replay_action != nil
    assert replay_action.type == :update
    # Should accept the same fields as the original upsert action
    assert :email in replay_action.accept
    assert :given_name in replay_action.accept
    assert :family_name in replay_action.accept
    assert replay_action.primary? == false
  end
end
