defmodule AshEventsTest do
  use AshEvents.RepoCase, async: false

  alias AshEvents.Test.Accounts
  alias AshEvents.Test.Events
  alias AshEvents.Test.Accounts.User
  alias AshEvents.Test.Events.EventResource

  require Ash.Query

  setup do
    Ash.bulk_destroy!(EventResource, :destroy, %{})
    Ash.bulk_destroy!(User, :destroy_ash_events_impl, %{})
    :ok
  end

  test "test wrapped actions & event replay" do
    user =
      Accounts.create_user!(%{
        email: "user@example.com",
        given_name: "John",
        family_name: "Doe",
        event_metadata: %{omg: "lol"}
      })

    opts = [actor: user]

    [event] = Ash.read!(EventResource)

    _user =
      Accounts.update_user!(user, %{given_name: "Jane"},
        actor: %AshEvents.Test.Events.SystemActor{name: "Some system worker"}
      )

    [_event1, _event2] = Ash.read!(EventResource)

    Ash.bulk_destroy!(User, :destroy_ash_events_impl, %{})

    [] = Ash.read!(User)

    :ok = Events.replay_events!()

    [user] = Ash.read!(User)

    assert user.given_name == "Jane"

    Accounts.destroy_user!(user, opts)

    [] = Ash.read!(User)

    events =
      EventResource
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    assert length(events) == 3

    update_event = Enum.at(events, 1)

    :ok = Events.replay_events(%{last_event_id: update_event.id})

    [user] = Ash.read!(User)

    assert user.given_name == "Jane"

    new_user =
      User
      |> AshEvents.Changeset.for_create(
        :create,
        %{email: "lol", given_name: "asfas", family_name: "omg", event_metadata: %{omg: "lol"}},
        opts
      )
      |> AshEvents.create!()

    new_user =
      new_user
      |> AshEvents.Changeset.for_update(
        :update,
        %{given_name: "lol", family_name: "omg", event_metadata: %{omg: "lol"}},
        opts
      )
      |> AshEvents.update!()

    destroyed =
      new_user
      |> AshEvents.Changeset.for_destroy(
        :destroy,
        %{},
        opts
      )
      |> AshEvents.destroy!()

    :ok = Accounts.destroy_user!(user, opts)

    [] = Ash.read!(User)
  end
end
