# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.ReplayTest do
  use AshEvents.RepoCase, async: false
  alias AshEvents.EventLogs.EventLogUuidV7
  alias AshEvents.EventLogs.SystemActor

  alias AshEvents.Accounts
  alias AshEvents.EventLogs
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

  def create_user_uuidv7 do
    Accounts.create_user_uuidv7!(
      %{
        email: "user@example.com",
        given_name: "John",
        family_name: "Doe"
      },
      context: %{ash_events_metadata: %{source: "Signup form"}},
      actor: %SystemActor{name: "test_runner"}
    )
  end

  test "replay works as expected and skips lifecycle hooks" do
    user = create_user()

    updated_user =
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
      updated_user,
      %{
        given_name: "Jason",
        family_name: "Anderson",
        role: "admin"
      },
      actor: %SystemActor{name: "External sync job"},
      context: %{ash_events_metadata: %{source: "External sync"}}
    )
    |> Ash.load!([:user_role])

    events =
      EventLog
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    [
      create_user_event,
      create_user_role_event,
      update_user_event_1,
      _update_user_event_2,
      _update_user_role_event
    ] = events

    :ok = EventLogs.replay_events!(%{last_event_id: update_user_event_1.id})

    user = Accounts.get_user_by_id!(user.id, load: [:user_role], actor: user)

    assert user.given_name == "Jack"
    assert user.family_name == "Smith"
    assert user.user_role.name == "user"

    :ok =
      EventLogs.replay_events!(%{
        point_in_time: create_user_role_event.occurred_at
      })

    user = Accounts.get_user_by_id!(user.id, load: [:user_role], actor: user)

    assert user.given_name == "John"
    assert user.family_name == "Doe"
    assert user.user_role.name == "user"

    :ok =
      EventLogs.replay_events!(%{
        point_in_time: create_user_event.occurred_at
      })

    user = Accounts.get_user_by_id!(user.id, load: [:user_role], actor: user)

    assert user.given_name == "John"
    assert user.family_name == "Doe"
    assert user.user_role == nil

    :ok = EventLogs.replay_events!()

    user = Accounts.get_user_by_id!(user.id, load: [:user_role], actor: user)

    assert user.given_name == "Jason"
    assert user.family_name == "Anderson"
    assert user.user_role.name == "admin"
  end

  test "replay works as expected and skips lifecycle hooks with uuidv7" do
    user = create_user_uuidv7()

    updated_user =
      Accounts.update_user_uuidv7!(
        user,
        %{
          given_name: "Jack",
          family_name: "Smith"
        },
        actor: user,
        context: %{ash_events_metadata: %{source: "Profile update"}}
      )

    Accounts.update_user_uuidv7!(
      updated_user,
      %{
        given_name: "Jason",
        family_name: "Anderson"
      },
      actor: %SystemActor{name: "External sync job"},
      context: %{ash_events_metadata: %{source: "External sync"}}
    )

    events =
      EventLogUuidV7
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    [
      create_user_event,
      update_user_event_1,
      _update_user_event_2
    ] = events

    :ok = EventLogs.replay_events_uuidv7!(%{last_event_id: update_user_event_1.id})

    user = Accounts.get_user_uuidv7_by_id!(user.id, actor: user)

    assert user.given_name == "Jack"
    assert user.family_name == "Smith"

    :ok =
      EventLogs.replay_events_uuidv7!(%{
        point_in_time: create_user_event.occurred_at
      })

    user = Accounts.get_user_uuidv7_by_id!(user.id, actor: user)

    assert user.given_name == "John"
    assert user.family_name == "Doe"

    :ok = EventLogs.replay_events_uuidv7!()

    user = Accounts.get_user_uuidv7_by_id!(user.id, actor: user)

    assert user.given_name == "Jason"
    assert user.family_name == "Anderson"
  end

  describe "replay idempotency" do
    test "running replay multiple times produces consistent results" do
      actor = %SystemActor{name: "idempotency_test"}
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      # Create and update user
      {:ok, user} =
        AshEvents.Accounts.UserUuidV7
        |> Ash.Changeset.for_create(:create, %{
          given_name: "Idempotent",
          family_name: "User",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      {:ok, _} =
        user
        |> Ash.Changeset.for_update(:update, %{given_name: "Updated"})
        |> Ash.update(actor: actor)

      user_id = user.id

      # First replay
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])
      :ok = EventLogs.replay_events_uuidv7!()

      {:ok, first_replay} = Ash.get(AshEvents.Accounts.UserUuidV7, user_id, actor: actor)
      first_state = %{given_name: first_replay.given_name, family_name: first_replay.family_name}

      # Second replay
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])
      :ok = EventLogs.replay_events_uuidv7!()

      {:ok, second_replay} = Ash.get(AshEvents.Accounts.UserUuidV7, user_id, actor: actor)

      second_state = %{
        given_name: second_replay.given_name,
        family_name: second_replay.family_name
      }

      # Third replay
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])
      :ok = EventLogs.replay_events_uuidv7!()

      {:ok, third_replay} = Ash.get(AshEvents.Accounts.UserUuidV7, user_id, actor: actor)
      third_state = %{given_name: third_replay.given_name, family_name: third_replay.family_name}

      # All should match
      assert first_state == second_state
      assert second_state == third_state
      assert first_state.given_name == "Updated"
    end

    test "replay is idempotent when run without clearing" do
      actor = %SystemActor{name: "no_clear_idempotency"}
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      # Create user
      {:ok, user} =
        AshEvents.Accounts.UserUuidV7
        |> Ash.Changeset.for_create(:create, %{
          given_name: "No Clear",
          family_name: "Test",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      user_id = user.id

      # Multiple replays without clearing should be safe
      # (replay should handle existing records gracefully)
      result1 = EventLogs.replay_events_uuidv7!()
      result2 = EventLogs.replay_events_uuidv7!()

      assert result1 == :ok
      assert result2 == :ok

      # User should still exist with correct state
      {:ok, final_user} = Ash.get(AshEvents.Accounts.UserUuidV7, user_id, actor: actor)
      assert final_user.given_name == "No Clear"
    end
  end

  describe "point-in-time replay edge cases" do
    test "replay to point before any events returns empty state" do
      actor = %SystemActor{name: "before_events_test"}
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      # Create user
      {:ok, user} =
        AshEvents.Accounts.UserUuidV7
        |> Ash.Changeset.for_create(:create, %{
          given_name: "Point In Time",
          family_name: "User",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      user_id = user.id

      # Get earliest event
      events = EventLogUuidV7 |> Ash.Query.sort({:occurred_at, :asc}) |> Ash.read!()
      earliest = hd(events)

      # Replay to 1 second before earliest event
      point_before = DateTime.add(earliest.occurred_at, -1, :second)

      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])
      :ok = EventLogs.replay_events_uuidv7!(%{point_in_time: point_before})

      # User should not exist
      assert {:error, _} = Ash.get(AshEvents.Accounts.UserUuidV7, user_id, actor: actor)
    end

    test "replay to exact event timestamp includes that event" do
      actor = %SystemActor{name: "exact_timestamp_test"}
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      # Create user
      {:ok, user} =
        AshEvents.Accounts.UserUuidV7
        |> Ash.Changeset.for_create(:create, %{
          given_name: "Exact",
          family_name: "Timestamp",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      user_id = user.id

      # Get create event timestamp
      events = EventLogUuidV7 |> Ash.read!()
      create_event = Enum.find(events, &(&1.record_id == user_id && &1.action_type == :create))

      # Replay to exact timestamp
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])
      :ok = EventLogs.replay_events_uuidv7!(%{point_in_time: create_event.occurred_at})

      # User should exist
      {:ok, restored} = Ash.get(AshEvents.Accounts.UserUuidV7, user_id, actor: actor)
      assert restored.given_name == "Exact"
    end

    test "replay with both last_event_id and point_in_time uses last_event_id" do
      actor = %SystemActor{name: "combined_params_test"}
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      # Create and update user
      {:ok, user} =
        AshEvents.Accounts.UserUuidV7
        |> Ash.Changeset.for_create(:create, %{
          given_name: "Combined",
          family_name: "Test",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      # Add delay to ensure different timestamps
      Process.sleep(10)

      {:ok, updated} =
        user
        |> Ash.Changeset.for_update(:update, %{given_name: "Updated Combined"})
        |> Ash.update(actor: actor)

      user_id = updated.id

      # Get events
      events =
        EventLogUuidV7
        |> Ash.Query.sort({:occurred_at, :asc})
        |> Ash.read!()
        |> Enum.filter(&(&1.record_id == user_id))

      [create_event, update_event] = events

      # Replay with last_event_id pointing to create, but point_in_time after update
      # last_event_id should take precedence
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      :ok =
        EventLogs.replay_events_uuidv7!(%{
          last_event_id: create_event.id,
          point_in_time: DateTime.add(update_event.occurred_at, 1, :second)
        })

      {:ok, restored} = Ash.get(AshEvents.Accounts.UserUuidV7, user_id, actor: actor)

      # Should have original name since we replayed up to create event only
      assert restored.given_name == "Combined"
    end
  end

  describe "empty event log replay" do
    test "replay with no events succeeds" do
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      # Ensure no events
      events = EventLogUuidV7 |> Ash.read!()
      assert Enum.empty?(events)

      # Replay should succeed
      result = EventLogs.replay_events_uuidv7!()
      assert result == :ok
    end

    test "replay with only destroyed records results in empty state" do
      actor = %SystemActor{name: "destroyed_replay_test"}
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])

      # Create and destroy user
      {:ok, user} =
        AshEvents.Accounts.UserUuidV7
        |> Ash.Changeset.for_create(:create, %{
          given_name: "To Destroy",
          family_name: "User",
          email: unique_email()
        })
        |> Ash.create(actor: actor)

      user_id = user.id

      {:ok, _} =
        user
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.destroy(actor: actor, return_destroyed?: true)

      # Clear and replay
      AshEvents.EventLogs.ClearRecordsUuidV7.clear_records!([])
      :ok = EventLogs.replay_events_uuidv7!()

      # User should not exist after replay
      assert {:error, _} = Ash.get(AshEvents.Accounts.UserUuidV7, user_id, actor: actor)
    end
  end

  # Helper functions

  defp unique_email(prefix \\ "replay") do
    "#{prefix}_#{System.unique_integer([:positive])}@example.com"
  end
end
