# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.ReplayNonWritableIdTest do
  @moduledoc """
  Tests replay functionality with resources that have non-writable UUID primary keys.

  This tests the common pattern where UUIDs are auto-generated and NOT accepted by actions.
  The bug being tested: replay was incorrectly trying to pass the primary key as an action
  input, causing "No such input `id`" errors.
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts
  alias AshEvents.EventLogs
  alias AshEvents.EventLogs.EventLog
  alias AshEvents.EventLogs.SystemActor

  require Ash.Query

  test "replay works with non-writable UUID primary key" do
    # Create a user - the ID is auto-generated and NOT accepted by the action
    user =
      Accounts.create_user_non_writable_id!(
        %{email: "test@example.com", name: "Test User"},
        actor: %SystemActor{name: "test_runner"}
      )

    original_id = user.id

    # Verify event was created with changed_attributes containing the auto-generated ID
    events =
      EventLog
      |> Ash.Query.filter(resource == AshEvents.Accounts.UserNonWritableId)
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    assert [create_event] = events
    assert create_event.action == :create
    assert create_event.record_id == original_id

    # The auto-generated ID should be in changed_attributes (stored as string keys)
    assert Map.has_key?(create_event.changed_attributes, "id")
    assert create_event.changed_attributes["id"] == original_id

    # Replay events - this should work without "No such input `id`" error
    :ok = EventLogs.replay_events!()

    # Verify the user was recreated with the same ID
    user = Accounts.get_user_non_writable_id_by_id!(original_id, actor: user)
    assert user.id == original_id
    assert user.email == "test@example.com"
    assert user.name == "Test User"
  end

  test "replay works with non-writable UUID after update and destroy" do
    # Create
    user =
      Accounts.create_user_non_writable_id!(
        %{email: "test@example.com", name: "Original Name"},
        actor: %SystemActor{name: "test_runner"}
      )

    original_id = user.id

    # Update
    updated_user =
      Accounts.update_user_non_writable_id!(
        user,
        %{name: "Updated Name"},
        actor: %SystemActor{name: "test_runner"}
      )

    assert updated_user.name == "Updated Name"

    # Replay all events
    :ok = EventLogs.replay_events!()

    # Verify the user was recreated with updated state
    user = Accounts.get_user_non_writable_id_by_id!(original_id, actor: user)
    assert user.id == original_id
    assert user.name == "Updated Name"
  end
end
