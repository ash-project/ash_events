# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Features.NonWritableIdReplayTest do
  @moduledoc """
  Tests that replay works correctly when a resource has:
  - uuid_primary_key with writable?: false (the default)
  - create action that does NOT accept :id

  This tests the exact scenario reported in the issue:
  https://github.com/ash-project/ash_events/issues/XX

  The reported error was:
    "No such input `id` for action MyApp.MyResource.create"

  The fix is that during replay, the changed_attributes (including :id)
  are applied via force_change_attributes, which bypasses the accept list
  and writable? restrictions.
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts.UserNonWritableId
  alias AshEvents.EventLogs
  alias AshEvents.EventLogs.EventLog
  alias AshEvents.EventLogs.SystemActor

  require Ash.Query

  describe "replay with non-writable primary key" do
    test "event stores auto-generated id in changed_attributes" do
      user =
        UserNonWritableId
        |> Ash.Changeset.for_create(:create, %{
          email: "test@example.com",
          name: "John Doe"
        })
        |> Ash.create!(actor: %SystemActor{name: "test"})

      # Fetch the event
      event =
        EventLog
        |> Ash.Query.filter(record_id == ^user.id and resource == ^UserNonWritableId)
        |> Ash.read_one!()

      # The auto-generated id should be in changed_attributes, NOT in data
      # because it wasn't in the original action input
      assert event.changed_attributes["id"] == user.id
      refute Map.has_key?(event.data, "id")

      # Data should contain only the inputs that were passed to the action
      assert event.data["email"] == "test@example.com"
      assert event.data["name"] == "John Doe"
    end

    test "replay succeeds with non-writable id using force_change strategy" do
      # This tests the exact scenario from the issue report
      user =
        UserNonWritableId
        |> Ash.Changeset.for_create(:create, %{
          email: "test@example.com",
          name: "John Doe"
        })
        |> Ash.create!(actor: %SystemActor{name: "test"})

      original_id = user.id

      # Verify the resource attribute is indeed not writable
      id_attr = Ash.Resource.Info.attribute(UserNonWritableId, :id)
      refute id_attr.writable?

      # Verify the create action does NOT accept :id
      create_action = Ash.Resource.Info.action(UserNonWritableId, :create)
      refute :id in create_action.accept

      # Replay events - this would fail with the old code because
      # it would try to pass :id as an action input
      :ok = EventLogs.replay_events!()

      # Verify user was recreated with the same id
      replayed_user = Ash.get!(UserNonWritableId, original_id)

      assert replayed_user.id == original_id
      assert replayed_user.email == "test@example.com"
      assert replayed_user.name == "John Doe"
    end

    test "replay with updates preserves correct state" do
      # Create user
      user =
        UserNonWritableId
        |> Ash.Changeset.for_create(:create, %{
          email: "test@example.com",
          name: "John Doe"
        })
        |> Ash.create!(actor: %SystemActor{name: "test"})

      original_id = user.id

      # Update user
      _updated =
        user
        |> Ash.Changeset.for_update(:update, %{name: "Jane Doe"})
        |> Ash.update!(actor: %SystemActor{name: "test"})

      # Replay all events
      :ok = EventLogs.replay_events!()

      # Verify final state
      replayed_user = Ash.get!(UserNonWritableId, original_id)

      assert replayed_user.id == original_id
      assert replayed_user.email == "test@example.com"
      assert replayed_user.name == "Jane Doe"
    end

    test "replay to point-in-time works with non-writable id" do
      # Create user
      user =
        UserNonWritableId
        |> Ash.Changeset.for_create(:create, %{
          email: "test@example.com",
          name: "John Doe"
        })
        |> Ash.create!(actor: %SystemActor{name: "test"})

      original_id = user.id

      # Get the create event's timestamp
      create_event =
        EventLog
        |> Ash.Query.filter(record_id == ^original_id and action_type == :create)
        |> Ash.read_one!()

      # Update user
      _updated =
        user
        |> Ash.Changeset.for_update(:update, %{name: "Jane Doe"})
        |> Ash.update!(actor: %SystemActor{name: "test"})

      # Replay to just after create event
      :ok = EventLogs.replay_events!(%{point_in_time: create_event.occurred_at})

      # Verify we got the state after create, before update
      replayed_user = Ash.get!(UserNonWritableId, original_id)

      assert replayed_user.id == original_id
      assert replayed_user.name == "John Doe"
    end

    test "multiple replays are idempotent with non-writable id" do
      user =
        UserNonWritableId
        |> Ash.Changeset.for_create(:create, %{
          email: "test@example.com",
          name: "John Doe"
        })
        |> Ash.create!(actor: %SystemActor{name: "test"})

      original_id = user.id

      # Multiple replays should all succeed and produce the same result
      :ok = EventLogs.replay_events!()
      first_user = Ash.get!(UserNonWritableId, original_id)

      :ok = EventLogs.replay_events!()
      second_user = Ash.get!(UserNonWritableId, original_id)

      :ok = EventLogs.replay_events!()
      third_user = Ash.get!(UserNonWritableId, original_id)

      assert first_user.id == original_id
      assert second_user.id == original_id
      assert third_user.id == original_id

      assert first_user.email == second_user.email
      assert second_user.email == third_user.email
    end
  end
end
