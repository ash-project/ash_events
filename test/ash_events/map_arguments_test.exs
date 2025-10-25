# SPDX-FileCopyrightText: 2025 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT
#
defmodule AshEvents.MapArgumentsTest do
  alias AshEvents.Accounts.User
  alias AshEvents.EventLogs.SystemActor
  use AshEvents.RepoCase, async: false

  alias AshEvents.EventLogs.EventLog

  require Ash.Query

  test "map arguments are correctly stored in event data" do
    # Create a user with actor attribution
    user =
      User
      |> Ash.Changeset.for_create(
        :create,
        %{
          email: "user@example.com",
          given_name: "John",
          family_name: "Doe",
          hashed_password: "hashed_password_123"
        },
        actor: %SystemActor{name: "test_runner"}
      )
      |> Ash.create!()

    # Update user with map argument
    metadata_map = %{
      "source" => "api",
      "ip_address" => "192.168.1.1",
      "nested" => %{
        "key1" => "value1",
        "key2" => 42,
        "key3" => true
      }
    }

    user
    |> Ash.Changeset.for_update(
      :update_with_map_arg,
      %{
        given_name: "Jane",
        metadata: metadata_map
      },
      actor: %SystemActor{name: "test_runner"}
    )
    |> Ash.update!()

    # Find the update event
    events =
      EventLog
      |> Ash.Query.filter(resource == ^User and action == :update_with_map_arg)
      |> Ash.Query.sort({:occurred_at, :desc})
      |> Ash.read!()

    assert length(events) == 1
    [event] = events

    # Verify the map is correctly stored in event data
    assert event.action == :update_with_map_arg
    assert event.resource == User

    # The metadata map should be stored in the data field
    assert %{"metadata" => stored_metadata} = event.data
    assert stored_metadata == metadata_map

    # Verify nested structure is preserved
    assert stored_metadata["source"] == "api"
    assert stored_metadata["ip_address"] == "192.168.1.1"
    assert stored_metadata["nested"]["key1"] == "value1"
    assert stored_metadata["nested"]["key2"] == 42
    assert stored_metadata["nested"]["key3"] == true
  end

  test "nil map arguments are handled correctly" do
    # Create a user with actor attribution
    user =
      User
      |> Ash.Changeset.for_create(
        :create,
        %{
          email: "user2@example.com",
          given_name: "Alice",
          family_name: "Smith",
          hashed_password: "hashed_password_456"
        },
        actor: %SystemActor{name: "test_runner"}
      )
      |> Ash.create!()

    # Update user without map argument (nil)
    user
    |> Ash.Changeset.for_update(
      :update_with_map_arg,
      %{
        given_name: "Bob"
      },
      actor: %SystemActor{name: "test_runner"}
    )
    |> Ash.update!()

    # Find the update event
    events =
      EventLog
      |> Ash.Query.filter(resource == ^User and action == :update_with_map_arg)
      |> Ash.Query.sort({:occurred_at, :desc})
      |> Ash.read!()

    assert length(events) == 1
    [event] = events

    # Verify nil is handled correctly
    assert event.action == :update_with_map_arg
    assert event.data["metadata"] == nil
  end
end
