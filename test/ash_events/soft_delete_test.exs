# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.SoftDeleteTest do
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts.SoftDeletableUser
  alias AshEvents.EventLogs.EventLog
  alias AshEvents.EventLogs.SystemActor

  require Ash.Query

  @actor %SystemActor{name: "test_runner"}

  describe "soft delete" do
    test "soft delete creates event with action_type :destroy" do
      # Create a user
      user =
        SoftDeletableUser
        |> Ash.Changeset.for_create(:create, %{
          email: "test@example.com",
          name: "Test User"
        })
        |> Ash.create!(actor: @actor)

      # Soft delete the user
      user
      |> Ash.Changeset.for_destroy(:archive, %{}, actor: @actor)
      |> Ash.destroy!()

      # Check that an event was created with action_type :destroy
      events =
        EventLog
        |> Ash.Query.filter(resource == ^SoftDeletableUser)
        |> Ash.Query.sort({:id, :asc})
        |> Ash.read!()

      assert length(events) == 2

      [create_event, destroy_event] = events

      assert create_event.action == :create
      assert create_event.action_type == :create

      assert destroy_event.action == :archive
      assert destroy_event.action_type == :destroy
    end
  end
end
