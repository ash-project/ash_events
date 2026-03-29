# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.ManageRelationship.HasOneTest do
  @moduledoc """
  Tests for manage_relationship on has_one relationships with AshEvents.

  Uses User (has_one :user_role) managing UserRole creation.
  The FK (user_id) is on the child resource (UserRole).
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts
  alias AshEvents.Accounts.{User, UserRole}
  alias AshEvents.EventLogs
  alias AshEvents.EventLogs.{EventLog, SystemActor}

  require Ash.Query

  @actor %SystemActor{name: "test"}

  describe "has_one + :direct_control" do
    test "creates parent and child, separate events for each" do
      user =
        User
        |> Ash.Changeset.for_create(:create_with_nested_role, %{
          email: "ho-dc@example.com",
          given_name: "Jane",
          family_name: "Doe",
          hashed_password: "hash",
          user_role: %{name: "admin"}
        }, actor: @actor)
        |> Ash.create!(actor: @actor)
        |> Ash.load!(:user_role, actor: @actor)

      assert user.user_role != nil
      assert user.user_role.name == "admin"

      events =
        EventLog
        |> Ash.read!(actor: @actor)
        |> Enum.filter(&(&1.action_type == :create))

      user_event = Enum.find(events, &(&1.resource == User and &1.record_id == user.id))
      role_event = Enum.find(events, &(&1.resource == UserRole and &1.record_id == user.user_role.id))

      assert user_event != nil
      assert user_event.action == :create_with_nested_role

      assert role_event != nil
      assert role_event.action == :create_from_parent
    end

    test "replay does not duplicate child — child is recreated from its own event" do
      user =
        User
        |> Ash.Changeset.for_create(:create_with_nested_role, %{
          email: "ho-dc-replay@example.com",
          given_name: "Jane",
          family_name: "Doe",
          hashed_password: "hash",
          user_role: %{name: "editor"}
        }, actor: @actor)
        |> Ash.create!(actor: @actor)
        |> Ash.load!(:user_role, actor: @actor)

      original_user_id = user.id
      original_role_id = user.user_role.id

      :ok = EventLogs.replay_events!()

      user = Accounts.get_user_by_id!(original_user_id, load: [:user_role], actor: @actor)
      assert user.user_role != nil
      assert user.user_role.id == original_role_id
      assert user.user_role.name == "editor"

      # Verify no duplicate roles were created
      all_roles = Ash.read!(UserRole, actor: @actor)
      assert length(Enum.filter(all_roles, &(&1.user_id == original_user_id))) == 1
    end
  end

  describe "has_one + :create" do
    test "creates parent and child, replay works correctly" do
      user =
        User
        |> Ash.Changeset.for_create(:create_with_role_create, %{
          email: "ho-create@example.com",
          given_name: "Bob",
          family_name: "Smith",
          hashed_password: "hash",
          user_role: %{name: "viewer"}
        }, actor: @actor)
        |> Ash.create!(actor: @actor)
        |> Ash.load!(:user_role, actor: @actor)

      assert user.user_role.name == "viewer"
      original_user_id = user.id
      original_role_id = user.user_role.id

      :ok = EventLogs.replay_events!()

      user = Accounts.get_user_by_id!(original_user_id, load: [:user_role], actor: @actor)
      assert user.user_role.id == original_role_id
      assert user.user_role.name == "viewer"
    end
  end
end
