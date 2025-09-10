defmodule AshEvents.ActorAttributionTest do
  alias AshEvents.EventLogs.SystemActor
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts
  alias AshEvents.Accounts.User
  alias AshEvents.EventLogs.EventLog

  require Ash.Query

  def create_user do
    Accounts.create_user!(
      %{
        email: "user@example.com",
        given_name: "John",
        family_name: "Doe",
        hashed_password: "hashed_password_123"
      },
      context: %{ash_events_metadata: %{source: "Signup form"}},
      actor: %SystemActor{name: "test_runner"}
    )
  end

  test "actor primary key is persisted" do
    user = create_user()

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
      user,
      %{
        given_name: "Jason",
        family_name: "Anderson"
      },
      actor: %SystemActor{name: "External sync job"},
      context: %{ash_events_metadata: %{source: "External sync"}}
    )

    [_event, _event2, profile_event, system_event] =
      EventLog
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    assert profile_event.user_id == user.id
    assert profile_event.system_actor == nil
    assert profile_event.action == :update
    assert profile_event.resource == User

    assert system_event.user_id == nil
    assert system_event.system_actor == "External sync job"
    assert system_event.action == :update
    assert system_event.resource == User
  end
end
