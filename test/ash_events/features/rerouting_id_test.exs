# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Features.ReroutingIdTest do
  @moduledoc """
  Tests to verify that rerouted actions correctly preserve the original record id.
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts
  alias AshEvents.Accounts.RoutedUser
  alias AshEvents.EventLogs
  alias AshEvents.EventLogs.SystemActor

  describe "rerouting preserves record id" do
    test "routed user gets the same id as the original user" do
      # Create a user - this will log an event
      user =
        Accounts.create_user!(
          %{
            email: "test@example.com",
            given_name: "John",
            family_name: "Doe",
            hashed_password: "hashed_password_123"
          },
          actor: %SystemActor{name: "test"}
        )

      original_id = user.id

      # Before replay, no routed users exist
      assert [] == Ash.read!(RoutedUser)

      # Replay - this routes the create event to both User and RoutedUser
      :ok = EventLogs.replay_events!()

      # Check the routed user
      [routed_user] = Ash.read!(RoutedUser)

      # The routed user should have the SAME id as the original user
      # This is important for data consistency across rerouted resources
      assert routed_user.id == original_id,
             "Expected routed_user.id to be #{original_id}, got #{routed_user.id}"

      # Also verify other attributes are correct
      assert routed_user.given_name == "John"
      assert routed_user.family_name == "Doe"
      assert routed_user.email == "test@example.com"
    end
  end
end
