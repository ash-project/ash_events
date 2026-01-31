# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.BinaryAttributesTest do
  @moduledoc """
  Test for binary attributes.

  These tests are currently skipped because Ash core does not yet support
  proper encoding of binary data in `dump_to_embedded`. Once Ash core is
  updated with the new binary encoding callbacks, these tests can be enabled.

  See discussion: The action that receives events during replay contains all
  type information needed for encoding/decoding. Encoding metadata is no longer
  stored in events - it's the responsibility of the action types to handle this.
  """
  alias AshEvents.Accounts.User
  alias AshEvents.EventLogs.SystemActor
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts
  alias AshEvents.EventLogs.EventLog

  require Ash.Query

  describe "binary attribute handling" do
    @describetag :skip
    test "events are created successfully with binary attributes" do
      user =
        Accounts.create_user!(
          %{
            email: "test@example.com",
            given_name: "Test",
            family_name: "User",
            hashed_password: "hashed_password_123"
          },
          actor: %SystemActor{name: "test_runner"}
        )

      # Verify the user was created with default binary api_key_hash
      assert is_binary(user.api_key_hash)
      assert byte_size(user.api_key_hash) == 32

      # Verify events were created successfully
      events = Ash.read!(EventLog)
      user_event = Enum.find(events, &(&1.resource == User and &1.action == :create))

      assert user_event != nil
      assert user_event.changed_attributes != nil

      # The binary value should be stored in changed_attributes
      # (encoding format depends on Ash core's dump_to_embedded implementation)
      assert Map.has_key?(user_event.changed_attributes, "api_key_hash")
    end

    test "event replay properly restores binary attributes" do
      # Create a user with binary attributes
      original_user =
        Accounts.create_user!(
          %{
            email: "replay_test@example.com",
            given_name: "Replay",
            family_name: "Binary",
            hashed_password: "original_password_123"
          },
          actor: %SystemActor{name: "test_runner"}
        )

      # Store the original binary values for comparison
      original_api_key_hash = original_user.api_key_hash
      original_sensitive_token = original_user.sensitive_token

      # Verify binary attributes were created
      assert is_binary(original_api_key_hash)
      assert byte_size(original_api_key_hash) == 32
      assert is_binary(original_sensitive_token)
      assert byte_size(original_sensitive_token) == 16

      # Test replay - the replay action automatically clears records
      system_actor = %SystemActor{name: "replay_system"}
      :ok = AshEvents.EventLogs.replay_events!(actor: system_actor)

      # Verify the user was recreated from events
      replayed_users = Ash.read!(User, actor: system_actor)
      assert length(replayed_users) == 1
      replayed_user = hd(replayed_users)

      # Verify all basic attributes were restored
      assert replayed_user.id == original_user.id
      assert replayed_user.email == original_user.email
      assert replayed_user.given_name == original_user.given_name
      assert replayed_user.family_name == original_user.family_name
      assert replayed_user.hashed_password == original_user.hashed_password

      # Verify binary attributes were properly restored during replay
      assert replayed_user.api_key_hash == original_user.api_key_hash

      # Verify sensitive binary attribute was properly handled
      # (it should be recreated as new binary data since it wasn't stored)
      assert is_binary(replayed_user.sensitive_token)
      assert byte_size(replayed_user.sensitive_token) == 16
      # Since sensitive_token wasn't stored, it will be newly generated
      assert replayed_user.sensitive_token != original_sensitive_token
    end

    test "array binary attributes are handled in events" do
      user =
        Accounts.create_user!(
          %{
            email: "array_test@example.com",
            given_name: "Array",
            family_name: "Test",
            hashed_password: "hashed_password_456"
          },
          actor: %SystemActor{name: "test_runner"}
        )

      # Verify the user was created with default binary_keys array
      assert is_list(user.binary_keys)
      assert length(user.binary_keys) == 3

      # Verify all elements are binary with expected sizes
      [key1, key2, key3] = user.binary_keys
      assert is_binary(key1) && byte_size(key1) == 8
      assert is_binary(key2) && byte_size(key2) == 12
      assert is_binary(key3) && byte_size(key3) == 16

      # Verify events were created successfully
      events = Ash.read!(EventLog)

      user_event =
        Enum.find(
          events,
          &(&1.resource == User and &1.action == :create and
              &1.data["email"] == "array_test@example.com")
        )

      assert user_event != nil
      assert user_event.changed_attributes != nil

      # The binary array should be stored in changed_attributes
      assert Map.has_key?(user_event.changed_attributes, "binary_keys")
    end

    test "event replay properly restores array binary attributes" do
      # Create a user with array binary attributes
      original_user =
        Accounts.create_user!(
          %{
            email: "array_replay@example.com",
            given_name: "Array",
            family_name: "Replay",
            hashed_password: "original_password_array"
          },
          actor: %SystemActor{name: "test_runner"}
        )

      # Store the original binary arrays for comparison
      original_binary_keys = original_user.binary_keys
      original_api_key_hash = original_user.api_key_hash

      # Verify binary attributes were created
      assert is_list(original_binary_keys)
      assert length(original_binary_keys) == 3
      assert is_binary(original_api_key_hash)

      # Test replay - the replay action automatically clears records
      system_actor = %SystemActor{name: "replay_system"}
      :ok = AshEvents.EventLogs.replay_events!(actor: system_actor)

      # Verify the user was recreated from events
      replayed_users = Ash.read!(User, actor: system_actor)
      assert length(replayed_users) == 1
      replayed_user = hd(replayed_users)

      # Verify all basic attributes were restored
      assert replayed_user.id == original_user.id
      assert replayed_user.email == original_user.email
      assert replayed_user.given_name == original_user.given_name
      assert replayed_user.family_name == original_user.family_name
      assert replayed_user.hashed_password == original_user.hashed_password

      # Verify array binary attributes were properly restored during replay
      assert replayed_user.api_key_hash == original_user.api_key_hash
      assert replayed_user.binary_keys == original_user.binary_keys

      # Verify the array structure and content
      assert is_list(replayed_user.binary_keys)
      assert length(replayed_user.binary_keys) == 3

      # Verify each binary element was correctly restored
      [restored1, restored2, restored3] = replayed_user.binary_keys
      [orig1, orig2, orig3] = original_binary_keys

      assert restored1 == orig1
      assert restored2 == orig2
      assert restored3 == orig3

      # Verify the byte sizes are correct
      assert byte_size(restored1) == 8
      assert byte_size(restored2) == 12
      assert byte_size(restored3) == 16
    end
  end
end
