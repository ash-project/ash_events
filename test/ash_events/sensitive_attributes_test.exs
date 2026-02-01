# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.SensitiveAttributesTest do
  @moduledoc """
  Test for sensitive attribute protection in events.

  Tests the store_sensitive_attributes DSL option and ensures that
  sensitive attributes are properly protected unless explicitly allowed.
  """
  use AshEvents.RepoCase, async: false
  alias AshEvents.Accounts
  alias AshEvents.Accounts.OrgCloaked
  alias AshEvents.Accounts.User

  alias AshEvents.EventLogs.EventLog
  alias AshEvents.EventLogs.EventLogCloaked
  alias AshEvents.EventLogs.SystemActor

  require Ash.Query

  describe "sensitive attribute protection" do
    test "sensitive binary attributes are protected in events when not cloaked" do
      # Create a user with both sensitive and non-sensitive binary attributes
      user =
        Accounts.create_user!(
          %{
            email: "sensitive@example.com",
            given_name: "Sensitive",
            family_name: "User",
            hashed_password: "hashed_password_123"
          },
          actor: %SystemActor{name: "test_runner"}
        )

      # Verify both binary attributes were created
      assert is_binary(user.api_key_hash)
      assert is_binary(user.sensitive_token)

      # Verify events were created successfully
      events = Ash.read!(EventLog)
      user_event = Enum.find(events, &(&1.resource == User and &1.action == :create))

      assert user_event != nil
      assert user_event.changed_attributes != nil

      # Non-sensitive binary attribute should be Base64 encoded in changed_attributes
      encoded_hash = user_event.changed_attributes["api_key_hash"]
      assert is_binary(encoded_hash)
      {:ok, decoded_hash} = Base.decode64(encoded_hash)
      assert decoded_hash == user.api_key_hash

      # Sensitive binary attribute should be nil in changed_attributes (not cloaked)
      assert user_event.changed_attributes["sensitive_token"] == nil
    end

    test "store_sensitive_attributes DSL option allows storing specific sensitive attributes" do
      # This test verifies that hashed_password is stored in data because it's in store_sensitive_attributes
      _user =
        Accounts.create_user!(
          %{
            email: "stored_sensitive@example.com",
            given_name: "Stored",
            family_name: "Sensitive",
            hashed_password: "hashed_password_456"
          },
          actor: %SystemActor{name: "test_runner"}
        )

      # Verify events were created successfully
      events = Ash.read!(EventLog)
      user_event = Enum.find(events, &(&1.resource == User and &1.action == :create))

      # hashed_password should be stored in data because it's in store_sensitive_attributes list
      # (hashed_password comes from action arguments, not changed_attributes)
      assert user_event.data["hashed_password"] != nil
      assert user_event.data["hashed_password"] == "hashed_password_456"

      # sensitive_token should still be nil in changed_attributes because it's not in the store list
      assert user_event.changed_attributes["sensitive_token"] == nil
    end

    test "cloaked event logs automatically store all sensitive attributes" do
      # Create an org with a sensitive attribute using the cloaked event log
      org =
        Accounts.create_org_cloaked!(
          %{
            name: "Secret Organization",
            secret_key: "super_secret_key_123"
          },
          actor: %SystemActor{name: "test_runner"}
        )

      # Verify the sensitive attributes were set
      assert org.secret_key == "super_secret_key_123"
      assert String.starts_with?(org.api_token, "token_")

      # Verify events were created successfully in the cloaked event log
      cloaked_events = Ash.read!(EventLogCloaked, load: [:data, :changed_attributes])
      org_event = Enum.find(cloaked_events, &(&1.resource == OrgCloaked and &1.action == :create))

      assert org_event != nil

      # For cloaked event logs, sensitive attributes should be stored (encrypted)
      # The sensitive attribute from action input should be present in the event data
      assert org_event.data["secret_key"] == "super_secret_key_123"

      # The auto-generated sensitive attribute should be present in changed_attributes
      assert org_event.changed_attributes["api_token"] != nil
      assert org_event.changed_attributes["api_token"] == org.api_token
    end
  end
end
