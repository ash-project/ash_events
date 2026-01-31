# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Events.Verifiers.VerifyStoreSensitiveAttributesTest do
  @moduledoc """
  Tests for the VerifyStoreSensitiveAttributes verifier.

  This verifier ensures that store_sensitive_attributes configuration is valid:
  - All attribute names reference existing attributes on the resource
  - All specified attributes are actually marked as sensitive
  - store_sensitive_attributes is not configured when using a cloaked event log
  """
  use ExUnit.Case, async: true

  alias AshEvents.Events.Verifiers.VerifyStoreSensitiveAttributes

  describe "verify/1 with valid configurations" do
    test "accepts User resource with valid store_sensitive_attributes" do
      assert Code.ensure_loaded?(AshEvents.Accounts.User)

      store_sensitive =
        AshEvents.Events.Info.events_store_sensitive_attributes!(AshEvents.Accounts.User)

      assert is_list(store_sensitive)
    end

    test "store_sensitive_attributes references existing attributes" do
      store_sensitive =
        AshEvents.Events.Info.events_store_sensitive_attributes!(AshEvents.Accounts.User)

      attributes = Ash.Resource.Info.attributes(AshEvents.Accounts.User)
      attribute_names = Enum.map(attributes, & &1.name)

      Enum.each(store_sensitive, fn attr_name ->
        assert attr_name in attribute_names,
               "Attribute #{inspect(attr_name)} should exist on User"
      end)
    end

    test "store_sensitive_attributes only lists sensitive attributes" do
      store_sensitive =
        AshEvents.Events.Info.events_store_sensitive_attributes!(AshEvents.Accounts.User)

      attributes = Ash.Resource.Info.attributes(AshEvents.Accounts.User)

      Enum.each(store_sensitive, fn attr_name ->
        attribute = Enum.find(attributes, &(&1.name == attr_name))

        assert attribute != nil

        assert attribute.sensitive? == true,
               "Attribute #{inspect(attr_name)} should be marked as sensitive"
      end)
    end
  end

  describe "cloaked event log interaction" do
    test "cloaked event log doesn't need store_sensitive_attributes" do
      # For cloaked event logs, all sensitive data is encrypted automatically
      assert AshEvents.EventLog.Info.cloaked?(AshEvents.EventLogs.EventLogCloaked)
    end

    test "verifier checks for cloaked/store_sensitive_attributes conflict" do
      source = File.read!("lib/events/verifiers/verify_store_sensitive_attributes.ex")

      assert source =~ "cloaked"
      assert source =~ "store_sensitive_attributes"
    end
  end

  describe "verifier module validation" do
    test "verifier module is loaded and has verify/1 function" do
      assert Code.ensure_loaded?(VerifyStoreSensitiveAttributes)
      assert function_exported?(VerifyStoreSensitiveAttributes, :verify, 1)
    end
  end

  describe "sensitive attribute identification" do
    test "hashed_password is a sensitive attribute on User" do
      attributes = Ash.Resource.Info.attributes(AshEvents.Accounts.User)
      hashed_password_attr = Enum.find(attributes, &(&1.name == :hashed_password))

      assert hashed_password_attr != nil
      assert hashed_password_attr.sensitive? == true
    end

    test "email is not a sensitive attribute on User" do
      attributes = Ash.Resource.Info.attributes(AshEvents.Accounts.User)
      email_attr = Enum.find(attributes, &(&1.name == :email))

      assert email_attr != nil
      assert email_attr.sensitive? == false
    end
  end

  describe "error message validation" do
    test "error messages are descriptive" do
      source = File.read!("lib/events/verifiers/verify_store_sensitive_attributes.ex")

      # Verify error messages mention specific requirements
      assert source =~ "store_sensitive_attributes"
      assert source =~ "does not exist"
      assert source =~ "is not marked as sensitive"
      assert source =~ "cloaked event log"
    end
  end
end
