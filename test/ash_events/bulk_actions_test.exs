# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.BulkActionsTest do
  alias AshEvents.EventLogs.SystemActor
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts
  alias AshEvents.Accounts.User
  alias AshEvents.EventLogs.EventLog

  require Ash.Query

  test "bulk actions works as expected" do
    result =
      1..2
      |> Enum.map(fn _i ->
        %{
          email: Faker.Internet.email(),
          given_name: Faker.Person.first_name(),
          family_name: Faker.Person.last_name(),
          hashed_password: "hashed_password_123"
        }
      end)
      |> Ash.bulk_create!(User, :create,
        actor: %AshEvents.EventLogs.SystemActor{name: "system"},
        return_notifications?: true,
        return_errors?: true,
        return_records?: true
      )

    assert result.error_count == 0
    assert Enum.count(result.records) == 2
    assert Enum.count(result.notifications) == 2

    events =
      EventLog
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    assert Enum.count(events) == 4

    update_result =
      result.records
      |> Ash.bulk_update!(
        :update,
        %{
          given_name: "Updated",
          family_name: "Name"
        },
        actor: %AshEvents.EventLogs.SystemActor{name: "system"},
        return_notifications?: true,
        return_errors?: true,
        return_records?: true,
        strategy: :stream
      )

    assert update_result.error_count == 0
    assert Enum.count(update_result.records) == 2
    assert Enum.count(update_result.notifications) == 2

    events =
      EventLog
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    assert Enum.count(events) == 6

    users = Accounts.User |> Ash.read!(actor: %SystemActor{name: "system"})

    Enum.each(users, fn user ->
      assert user.given_name == "Updated"
      assert user.family_name == "Name"
    end)

    user_roles = Accounts.UserRole |> Ash.read!()

    destroy_roles_result =
      user_roles
      |> Ash.bulk_destroy!(:destroy, %{},
        return_errors?: true,
        return_notifications?: true,
        return_records?: true,
        strategy: :stream
      )

    assert destroy_roles_result.error_count == 0
    assert Enum.count(destroy_roles_result.records) == 2
    assert Enum.count(destroy_roles_result.notifications) == 2

    [] = Accounts.UserRole |> Ash.read!()

    events =
      EventLog
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    assert Enum.count(events) == 8

    destroy_users_result =
      update_result.records
      |> Ash.bulk_destroy!(:destroy, %{},
        return_errors?: true,
        return_notifications?: true,
        return_records?: true,
        strategy: :stream,
        actor: %SystemActor{name: "system"}
      )

    assert destroy_users_result.error_count == 0
    assert Enum.count(destroy_users_result.records) == 2
    assert Enum.count(destroy_users_result.notifications) == 2

    [] = Accounts.User |> Ash.read!(actor: %SystemActor{name: "system"})

    events =
      EventLog
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    assert Enum.count(events) == 10
  end
end
