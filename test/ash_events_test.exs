defmodule AshEventsTest do
  use AshEvents.RepoCase, async: false

  alias AshEvents.Test.Accounts
  alias AshEvents.Test.Events
  alias AshEvents.Test.Accounts.User
  alias AshEvents.Test.Accounts.Commands
  alias AshEvents.Test.Events.EventResource

  import Ash.Test

  setup do
    Ash.bulk_destroy!(EventResource, :destroy, %{})
    Ash.bulk_destroy!(User, :destroy, %{})
    :ok
  end

  test "test wrapped create action & event replay" do
    actions = Ash.Resource.Info.actions(User)

    user =
      Accounts.create_user!(%{
        email: "user@example.com",
        given_name: "John",
        family_name: "Doe",
        event_metadata: %{omg: "lol"}
      })

    [event] = Ash.read!(EventResource)

    Ash.bulk_destroy!(User, :destroy, %{})

    [] = Ash.read!(User)

    Events.replay_events!()

    [user] = Ash.read!(User)
  end
end
