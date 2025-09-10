defmodule AshEvents.EventCreationTest do
  alias AshEvents.Accounts.User
  alias AshEvents.Accounts.UserRole
  alias AshEvents.EventLogs.SystemActor
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts
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

  test "events are created as expected" do
    create_user()

    # Events are inserted in the correct order
    [event, event2] =
      EventLog
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    assert event.metadata == %{"source" => "Signup form"}
    assert event.user_id == nil
    assert event.system_actor == "test_runner"
    assert event.action == :create
    assert event.resource == User

    assert %{
             "email" => "user@example.com",
             "given_name" => "John",
             "family_name" => "Doe"
           } = event.data

    assert event2.metadata == %{}
    assert event2.user_id == nil
    assert event2.system_actor == "test_runner"
    assert event2.action == :create
    assert event2.resource == UserRole

    assert %{
             "name" => "user",
             "user_id" => _user_id
           } = event2.data
  end

  test "can be used just like normal actions/changesets" do
    opts = [actor: %AshEvents.EventLogs.SystemActor{name: "Some system worker"}]

    user =
      User
      |> Ash.Changeset.for_create(
        :create,
        %{
          email: "email@email.com",
          given_name: "Given",
          family_name: "Family",
          hashed_password: "hashed_password_123"
        },
        opts ++ [context: %{ash_events_metadata: %{meta_field: "meta_value"}}]
      )
      |> Ash.create!()

    user =
      user
      |> Ash.Changeset.for_update(
        :update,
        %{
          given_name: "Updated given",
          family_name: "Updated family"
        },
        opts ++ [context: %{ash_events_metadata: %{meta_field: "meta_value"}}]
      )
      |> Ash.update!(load: [:user_role])

    events = Ash.read!(EventLog)
    assert Enum.count(events) == 3

    user.user_role
    |> Ash.Changeset.for_destroy(
      :destroy,
      %{},
      opts
    )
    |> Ash.destroy!()

    user
    |> Ash.Changeset.for_destroy(
      :destroy,
      %{},
      opts
    )
    |> Ash.destroy!()

    [] = Ash.read!(User, opts)

    events = Ash.read!(EventLog)
    assert Enum.count(events) == 5
  end
end
