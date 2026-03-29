# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.ManageRelationship.BelongsToTest do
  @moduledoc """
  Tests for manage_relationship on belongs_to relationships with AshEvents.

  Uses UserRole (belongs_to :user) and Comment (belongs_to :user).
  The FK is on the child resource (user_id).
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts
  alias AshEvents.Accounts.{UserRole, Comment}
  alias AshEvents.EventLogs
  alias AshEvents.EventLogs.{EventLog, SystemActor}

  require Ash.Query

  defp create_user_without_role(attrs \\ %{}) do
    default = %{
      email: "bt-user-#{System.unique_integer([:positive])}@example.com",
      given_name: "Test",
      family_name: "User",
      hashed_password: "hash"
    }

    # Use create_with_form to avoid auto-creating a UserRole
    Accounts.create_user_with_form!(Map.merge(default, attrs), actor: %SystemActor{name: "test"})
  end

  describe "belongs_to + :append" do
    test "action creates record with FK set, event captures FK in changed_attributes" do
      user = create_user_without_role()

      role =
        Accounts.create_user_role!(%{name: "admin", user_id: user.id},
          actor: %SystemActor{name: "test"}
        )

      assert role.user_id == user.id

      event =
        EventLog
        |> Ash.read!(actor: %SystemActor{name: "test"})
        |> Enum.find(&(&1.resource == UserRole and &1.record_id == role.id))

      assert event != nil
      assert event.action == :create
      assert Map.has_key?(event.changed_attributes, "user_id")
      assert event.changed_attributes["user_id"] == user.id
    end

    test "replay correctly restores FK from changed_attributes" do
      user = create_user_without_role()

      role =
        Accounts.create_user_role!(%{name: "admin", user_id: user.id},
          actor: %SystemActor{name: "test"}
        )

      original_role_id = role.id
      original_user_id = user.id

      :ok = EventLogs.replay_events!()

      roles =
        UserRole
        |> Ash.read!(actor: %SystemActor{name: "test"})
        |> Enum.filter(&(&1.id == original_role_id))

      assert [replayed_role] = roles
      assert replayed_role.user_id == original_user_id
      assert replayed_role.name == "admin"
    end
  end

  describe "belongs_to + :append (via Comment)" do
    test "action creates comment with FK, replay restores it" do
      user = create_user_without_role()

      comment =
        Accounts.create_comment!(%{body: "Hello", user_id: user.id},
          actor: %SystemActor{name: "test"}
        )

      assert comment.user_id == user.id

      event =
        EventLog
        |> Ash.read!(actor: %SystemActor{name: "test"})
        |> Enum.find(&(&1.resource == Comment and &1.record_id == comment.id))

      assert Map.has_key?(event.changed_attributes, "user_id")

      :ok = EventLogs.replay_events!()

      [replayed] =
        Comment
        |> Ash.read!(actor: %SystemActor{name: "test"})
        |> Enum.filter(&(&1.id == comment.id))

      assert replayed.user_id == user.id
      assert replayed.body == "Hello"
    end
  end
end
