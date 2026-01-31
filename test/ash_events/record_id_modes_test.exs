# SPDX-FileCopyrightText: 2024 Torkild G. Kjevik
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.RecordIdModesTest do
  @moduledoc """
  Tests for configurable record_id handling modes in rerouted replay.

  The record_id option on route_to controls how the event's record_id is handled:
  - :force_change_attribute (default) - Force changes the target resource's primary key
  - :as_argument - Passes record_id as an argument to the action
  - :ignore - Doesn't pass record_id at all (for projections/counters)
  """
  use AshEvents.RepoCase

  require Ash.Query

  alias AshEvents.Accounts
  alias AshEvents.Accounts.UserCountProjection
  alias AshEvents.EventLogs.SystemActor
  alias AshEvents.TestRepo

  setup do
    # Clean up any existing projection records
    TestRepo.delete_all("user_count_projections")
    :ok
  end

  describe "record_id modes during replay" do
    test "creates projection records with both :as_argument and :ignore modes" do
      # Create a user which generates a v1 create event
      {:ok, user} =
        Accounts.create_user(
          %{email: "test@example.com", given_name: "Test", family_name: "User"},
          actor: %SystemActor{name: "test"}
        )

      # Clear all records (including projections) and replay
      AshEvents.EventLogs.replay_events!(%{})

      # Query all projection records
      projections =
        UserCountProjection
        |> Ash.Query.new()
        |> Ash.read!()

      # We should have 2 projection records from the replay:
      # 1. One from :track_user_create (with last_record_id set to user.id)
      # 2. One from :count_event (with last_record_id nil)

      # Find the one with last_record_id (from :as_argument mode)
      as_argument_projection = Enum.find(projections, fn p -> p.last_record_id == user.id end)
      assert as_argument_projection != nil
      assert as_argument_projection.event_count == 1
      assert as_argument_projection.projection_type == "user_count"

      # Find the one without last_record_id (from :ignore mode)
      ignore_projection = Enum.find(projections, fn p -> p.last_record_id == nil end)
      assert ignore_projection != nil
      assert ignore_projection.event_count == 1
      assert ignore_projection.projection_type == "user_count"

      # The projections should have different IDs (their own PKs, not record_id)
      assert as_argument_projection.id != ignore_projection.id
      # And neither should have the user's ID
      assert as_argument_projection.id != user.id
      assert ignore_projection.id != user.id
    end

    test "multiple users create multiple projection records" do
      actor = %SystemActor{name: "test_multiple"}

      # Create multiple users
      {:ok, user1} =
        Accounts.create_user(%{email: "user1@example.com", given_name: "User", family_name: "One"}, actor: actor)

      {:ok, user2} =
        Accounts.create_user(%{email: "user2@example.com", given_name: "User", family_name: "Two"}, actor: actor)

      {:ok, user3} =
        Accounts.create_user(%{email: "user3@example.com", given_name: "User", family_name: "Three"}, actor: actor)

      # Clear all records and replay
      AshEvents.EventLogs.replay_events!(%{})

      # Query all projection records
      projections =
        UserCountProjection
        |> Ash.Query.new()
        |> Ash.read!()

      # 3 users * 2 projection routes = 6 projection records
      assert length(projections) == 6

      # Check :as_argument mode projections (should have last_record_id)
      as_argument_projections = Enum.filter(projections, fn p -> p.last_record_id != nil end)
      assert length(as_argument_projections) == 3

      # Each should have a different user's record_id
      record_ids = Enum.map(as_argument_projections, & &1.last_record_id) |> MapSet.new()
      assert MapSet.equal?(record_ids, MapSet.new([user1.id, user2.id, user3.id]))

      # Check :ignore mode projections (should have nil last_record_id)
      ignore_projections = Enum.filter(projections, fn p -> p.last_record_id == nil end)
      assert length(ignore_projections) == 3
    end

    test ":force_change_attribute mode still works (default behavior)" do
      actor = %SystemActor{name: "test_force_change"}

      # Create a user which will be rerouted to both User :create_v1 and RoutedUser :routed_create
      # Both of these use the default :force_change_attribute mode
      {:ok, user} =
        Accounts.create_user(
          %{email: "force@example.com", given_name: "Force", family_name: "Change"},
          actor: actor
        )

      # Clear and replay
      AshEvents.EventLogs.replay_events!(%{})

      # The user should be recreated with the same ID (force_change_attribute mode)
      replayed_user = Accounts.get_user_by_id!(user.id, actor: actor)
      assert replayed_user.id == user.id
      assert replayed_user.given_name == "Force"
      assert replayed_user.family_name == "Change"

      # The RoutedUser should also have the same ID as the original user
      # (since it also uses :force_change_attribute by default)
      routed_user =
        AshEvents.Accounts.RoutedUser
        |> Ash.Query.filter(id == ^user.id)
        |> Ash.read_one!(actor: actor)

      assert routed_user != nil
      assert routed_user.id == user.id
    end
  end
end
