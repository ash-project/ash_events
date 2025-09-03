defmodule AshEvents.ReplayTest do
  use AshEvents.RepoCase, async: false
  alias AshEvents.Test.Accounts.User
  alias AshEvents.Test.Events.EventLogUuidV7
  alias AshEvents.Test.Events.SystemActor

  alias AshEvents.Test.Accounts
  alias AshEvents.Test.Events
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

  def create_user_uuidv7 do
    Accounts.create_user_uuidv7!(
      %{
        email: "user@example.com",
        given_name: "John",
        family_name: "Doe"
      },
      context: %{ash_events_metadata: %{source: "Signup form"}},
      actor: %SystemActor{name: "test_runner"}
    )
  end

  test "replay works as expected and skips lifecycle hooks" do
    user = create_user()

    updated_user =
      Accounts.update_user!(
        user,
        %{
          given_name: "Jack",
          family_name: "Smith"
        },
        actor: user,
        context: %{ash_events_metadata: %{source: "Profile update"}}
      )

    Accounts.update_user!(
      updated_user,
      %{
        given_name: "Jason",
        family_name: "Anderson",
        role: "admin"
      },
      actor: %SystemActor{name: "External sync job"},
      context: %{ash_events_metadata: %{source: "External sync"}}
    )
    |> Ash.load!([:user_role])

    events =
      EventLog
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    [
      create_user_event,
      create_user_role_event,
      update_user_event_1,
      _update_user_event_2,
      _update_user_role_event
    ] = events

    :ok = Events.replay_events!(%{last_event_id: update_user_event_1.id})

    user = Accounts.get_user_by_id!(user.id, load: [:user_role], actor: user)

    assert user.given_name == "Jack"
    assert user.family_name == "Smith"
    assert user.user_role.name == "user"

    :ok =
      Events.replay_events!(%{
        point_in_time: create_user_role_event.occurred_at
      })

    user = Accounts.get_user_by_id!(user.id, load: [:user_role], actor: user)

    assert user.given_name == "John"
    assert user.family_name == "Doe"
    assert user.user_role.name == "user"

    :ok =
      Events.replay_events!(%{
        point_in_time: create_user_event.occurred_at
      })

    user = Accounts.get_user_by_id!(user.id, load: [:user_role], actor: user)

    assert user.given_name == "John"
    assert user.family_name == "Doe"
    assert user.user_role == nil

    :ok = Events.replay_events!()

    user = Accounts.get_user_by_id!(user.id, load: [:user_role], actor: user)

    assert user.given_name == "Jason"
    assert user.family_name == "Anderson"
    assert user.user_role.name == "admin"
  end

  test "replay works as expected and skips lifecycle hooks with uuidv7" do
    user = create_user_uuidv7()

    updated_user =
      Accounts.update_user_uuidv7!(
        user,
        %{
          given_name: "Jack",
          family_name: "Smith"
        },
        actor: user,
        context: %{ash_events_metadata: %{source: "Profile update"}}
      )

    Accounts.update_user_uuidv7!(
      updated_user,
      %{
        given_name: "Jason",
        family_name: "Anderson"
      },
      actor: %SystemActor{name: "External sync job"},
      context: %{ash_events_metadata: %{source: "External sync"}}
    )

    events =
      EventLogUuidV7
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    [
      create_user_event,
      update_user_event_1,
      _update_user_event_2
    ] = events

    :ok = Events.replay_events_uuidv7!(%{last_event_id: update_user_event_1.id})

    user = Accounts.get_user_uuidv7_by_id!(user.id, actor: user)

    assert user.given_name == "Jack"
    assert user.family_name == "Smith"

    :ok =
      Events.replay_events_uuidv7!(%{
        point_in_time: create_user_event.occurred_at
      })

    user = Accounts.get_user_uuidv7_by_id!(user.id, actor: user)

    assert user.given_name == "John"
    assert user.family_name == "Doe"

    :ok = Events.replay_events_uuidv7!()

    user = Accounts.get_user_uuidv7_by_id!(user.id, actor: user)

    assert user.given_name == "Jason"
    assert user.family_name == "Anderson"
  end
end
