defmodule AshEvents.BinaryAttributesTest do
  @moduledoc """
  Test for binary attributes to reproduce and fix the Jason.EncodeError issue.

  This test reproduces the issue described in:
  https://github.com/ash-project/ash_events/issues/64

  In v0.5.0+, the changed_attributes field includes binary data which
  causes Jason.EncodeError when trying to JSON encode for storage.

  The fix involves Base64 encoding binary data and storing encoding metadata
  for proper decoding during event replay.
  """
  alias AshEvents.Accounts.User
  alias AshEvents.EventLogs.SystemActor
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts
  alias AshEvents.EventLogs.EventLog

  require Ash.Query

  describe "binary attribute encoding" do
    test "binary attributes are properly Base64 encoded in events" do
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

      # Verify that the binary value is Base64 encoded in changed_attributes
      encoded_hash = user_event.changed_attributes["api_key_hash"]
      assert is_binary(encoded_hash)

      # Verify it's valid Base64 and can be decoded back to the original binary
      {:ok, decoded_hash} = Base.decode64(encoded_hash)
      assert decoded_hash == user.api_key_hash
    end

    test "encoding metadata is stored and used correctly for replay" do
      # Create a user with binary attributes
      user =
        Accounts.create_user!(
          %{
            email: "replay@example.com",
            given_name: "Replay",
            family_name: "User",
            hashed_password: "hashed_password_123"
          },
          actor: %SystemActor{name: "test_runner"}
        )

      # Verify encoding metadata is stored in the event
      events = Ash.read!(EventLog)
      user_event = Enum.find(events, &(&1.resource == User and &1.action == :create))

      # Check that encoding metadata was recorded
      # No binary data in params for this test (all binary data is in changed_attributes)
      assert user_event.data_field_encoders == %{}

      expected_encoders = %{
        "api_key_hash" => "base64",
        "binary_keys" => "base64"
      }

      assert user_event.changed_attributes_field_encoders == expected_encoders

      # Verify that event replay would work with encoding metadata
      # The replay logic should use the encoding metadata to decode Base64 values
      assert user_event.changed_attributes["api_key_hash"] != nil
      {:ok, decoded_hash} = Base.decode64(user_event.changed_attributes["api_key_hash"])
      assert decoded_hash == user.api_key_hash
    end

    test "binary data in action arguments gets proper encoding metadata" do
      # Test case where binary data comes from action arguments (data field)
      # This would test the data_field_encoders if we had an action that accepted binary args

      # For now, just verify that the system handles the case where no encoding is needed
      _user =
        Accounts.create_user!(
          %{
            email: "args@example.com",
            given_name: "Args",
            family_name: "Test",
            hashed_password: "hashed_password_789"
          },
          actor: %SystemActor{name: "test_runner"}
        )

      events = Ash.read!(EventLog)
      user_event = Enum.find(events, &(&1.resource == User and &1.action == :create))

      # For regular string/non-binary arguments, no encoding metadata should be present
      assert user_event.data_field_encoders == %{}

      # But binary changed attributes should still have encoding metadata
      expected_encoders = %{
        "api_key_hash" => "base64",
        "binary_keys" => "base64"
      }

      assert user_event.changed_attributes_field_encoders == expected_encoders
    end

    test "event replay properly decodes binary attributes using encoding metadata" do
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

      # Verify events were created with proper encoding metadata
      events = Ash.read!(EventLog)
      user_event = Enum.find(events, &(&1.resource == User and &1.action == :create))

      expected_encoders = %{
        "api_key_hash" => "base64",
        "binary_keys" => "base64"
      }

      assert user_event.changed_attributes_field_encoders == expected_encoders
      assert user_event.changed_attributes["api_key_hash"] != nil

      # Verify the binary data is Base64 encoded in the event
      {:ok, decoded_from_event} = Base.decode64(user_event.changed_attributes["api_key_hash"])
      assert decoded_from_event == original_api_key_hash

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

      # CRITICAL: Verify binary attributes were properly decoded during replay
      # Note: During replay with force_change mode, auto-generated attributes
      # are restored from the changed_attributes in the event
      assert replayed_user.api_key_hash == original_user.api_key_hash

      # Verify sensitive binary attribute was properly handled
      # (it should be recreated as new binary data since it wasn't stored)
      assert is_binary(replayed_user.sensitive_token)
      assert byte_size(replayed_user.sensitive_token) == 16
      # Since sensitive_token wasn't stored, it will be newly generated
      assert replayed_user.sensitive_token != original_sensitive_token
    end

    test "array binary attributes are properly Base64 encoded in events" do
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

      # Verify that the binary array is Base64 encoded in changed_attributes
      encoded_keys = user_event.changed_attributes["binary_keys"]
      assert is_list(encoded_keys)
      assert length(encoded_keys) == 3

      # Verify each element is valid Base64 and can be decoded back to original binary
      [encoded1, encoded2, encoded3] = encoded_keys

      {:ok, decoded1} = Base.decode64(encoded1)
      {:ok, decoded2} = Base.decode64(encoded2)
      {:ok, decoded3} = Base.decode64(encoded3)

      assert decoded1 == key1
      assert decoded2 == key2
      assert decoded3 == key3
    end

    test "array binary encoding metadata is stored correctly" do
      user =
        Accounts.create_user!(
          %{
            email: "array_metadata@example.com",
            given_name: "Array",
            family_name: "Metadata",
            hashed_password: "hashed_password_789"
          },
          actor: %SystemActor{name: "test_runner"}
        )

      # Verify encoding metadata is stored in the event
      events = Ash.read!(EventLog)

      user_event =
        Enum.find(
          events,
          &(&1.resource == User and &1.action == :create and
              &1.data["email"] == "array_metadata@example.com")
        )

      # Check that encoding metadata was recorded for both binary attributes
      assert user_event.data_field_encoders == %{}

      expected_encoders = %{
        "api_key_hash" => "base64",
        "binary_keys" => "base64"
      }

      assert user_event.changed_attributes_field_encoders == expected_encoders

      # Verify that array elements can be decoded using the encoding metadata
      encoded_keys = user_event.changed_attributes["binary_keys"]
      assert is_list(encoded_keys)

      # Decode each element and verify they match the original
      decoded_keys =
        Enum.map(encoded_keys, fn encoded ->
          {:ok, decoded} = Base.decode64(encoded)
          decoded
        end)

      assert decoded_keys == user.binary_keys
    end

    test "event replay properly decodes array binary attributes using encoding metadata" do
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

      # Verify events were created with proper encoding metadata
      events = Ash.read!(EventLog)

      user_event =
        Enum.find(
          events,
          &(&1.resource == User and &1.action == :create and
              &1.data["email"] == "array_replay@example.com")
        )

      expected_encoders = %{
        "api_key_hash" => "base64",
        "binary_keys" => "base64"
      }

      assert user_event.changed_attributes_field_encoders == expected_encoders

      # Verify the binary array is Base64 encoded in the event
      encoded_keys = user_event.changed_attributes["binary_keys"]
      assert is_list(encoded_keys)

      decoded_from_event =
        Enum.map(encoded_keys, fn encoded ->
          {:ok, decoded} = Base.decode64(encoded)
          decoded
        end)

      assert decoded_from_event == original_binary_keys

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

      # CRITICAL: Verify array binary attributes were properly decoded during replay
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
