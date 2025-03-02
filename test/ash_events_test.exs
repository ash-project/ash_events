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

  test "executing commands creates event & dispatches to event-handlers" do
    user =
      Commands.create_user!(%{
        data: %{
          email: "user@example.com",
          given_name: "John",
          family_name: "Doe"
        },
        metadata: %{
          source: "Manual registration"
        }
      })

    assert user.id
    assert user.email == "user@example.com"
    assert user.given_name == "John"
    assert user.family_name == "Doe"

    [event] = Ash.read!(EventResource)

    assert event.name == "accounts_user_created"
    assert event.version == "1.0"

    assert event.data == %{
             "email" => "user@example.com",
             "given_name" => "John",
             "family_name" => "Doe"
           }

    assert(
      event.metadata == %{
        "some_value" => "something",
        "command_resource" => "AshEvents.Test.Accounts.Commands",
        "command_name" => "create_user",
        "source" => "Manual registration"
      }
    )
  end

  test "error from event-handlers causes rollback" do
    result =
      Commands.create_user(%{
        data: %{
          email: "user@example.com",
          given_name: "John"
        },
        metadata: %{
          source: "Manual registration"
        }
      })

    assert_has_error(result, fn
      %Ash.Error.Changes.Required{field: :family_name} -> true
    end)
  end

  test "error in command's before_dispatch causes rollback" do
    {:error, %{errors: [%{error: "Ooops"}]}} =
      Commands.create_user_before_fail(%{
        data: %{
          email: "user@example.com",
          given_name: "John"
        },
        metadata: %{
          source: "Manual registration"
        }
      })
  end

  test "updates on entities work as expected" do
    user =
      Commands.create_user!(%{
        data: %{
          email: "user@example.com",
          given_name: "John",
          family_name: "Doe"
        },
        metadata: %{
          source: "Manual registration"
        }
      })

    assert user.id
    assert user.email == "user@example.com"
    assert user.given_name == "John"
    assert user.family_name == "Doe"

    updated_user =
      Commands.update_user!(%{
        entity_id: user.id,
        data: %{
          given_name: "Jane"
        }
      })

    assert updated_user.id == user.id

    [event1, event2] =
      EventResource
      |> Ash.Query.sort([{:occurred_at, :asc}])
      |> Ash.read!()

    assert event1.name == "accounts_user_created"
    assert event2.name == "accounts_user_updated"

    assert event2.id == event1.id + 1
  end

  test "event replay works as expected" do
    user =
      Commands.create_user!(%{
        data: %{
          email: "user@example.com",
          given_name: "John",
          family_name: "Doe"
        },
        metadata: %{
          source: "Manual registration"
        }
      })

    assert user.id
    assert user.email == "user@example.com"
    assert user.given_name == "John"
    assert user.family_name == "Doe"

    updated_user =
      Commands.update_user!(%{
        entity_id: user.id,
        data: %{
          given_name: "Jane"
        }
      })

    Ash.bulk_destroy!(User, :destroy, %{})

    {:error, %Ash.Error.Query.NotFound{}} = Accounts.get_user_by_id(user.id)

    :ok = Events.replay_events()

    user = Accounts.get_user_by_id!(user.id)

    assert user.id == updated_user.id
  end
end
