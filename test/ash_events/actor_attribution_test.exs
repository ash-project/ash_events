# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

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

  describe "actions without actor" do
    alias AshEvents.Accounts.Org

    test "create action works without an actor" do
      org = Accounts.create_org!(%{name: "Test Org"})

      assert org.name == "Test Org"

      [event] =
        EventLog
        |> Ash.Query.filter(resource == Org)
        |> Ash.read!()

      assert event.action == :create
      assert event.resource == Org
      assert event.user_id == nil
      assert event.system_actor == nil
    end

    test "update action works without an actor" do
      org = Accounts.create_org!(%{name: "Test Org"})

      updated_org =
        org
        |> Ash.Changeset.for_update(:update, %{name: "Updated Org"})
        |> Ash.update!()

      assert updated_org.name == "Updated Org"

      [_create_event, update_event] =
        EventLog
        |> Ash.Query.filter(resource == Org)
        |> Ash.Query.sort({:id, :asc})
        |> Ash.read!()

      assert update_event.action == :update
      assert update_event.resource == Org
      assert update_event.user_id == nil
      assert update_event.system_actor == nil
    end

    test "create action works with actor explicitly set to nil" do
      org = Accounts.create_org!(%{name: "Nil Actor Org"}, actor: nil)

      assert org.name == "Nil Actor Org"

      [event] =
        EventLog
        |> Ash.Query.filter(resource == Org)
        |> Ash.read!()

      assert event.action == :create
      assert event.user_id == nil
      assert event.system_actor == nil
    end
  end
end
