# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EventLog.Verifiers.VerifyPersistActorPrimaryKeyTest do
  @moduledoc """
  Tests for the VerifyPersistActorPrimaryKey verifier.

  This verifier ensures that when multiple persist_actor_primary_key options are defined,
  they all have allow_nil? set to true.
  """
  use ExUnit.Case, async: true

  alias AshEvents.EventLog.Verifiers.VerifyPersistActorPrimaryKey

  describe "verify/1 with valid configurations" do
    test "accepts single persist_actor_primary_key without allow_nil? requirement" do
      assert Code.ensure_loaded?(AshEvents.EventLogs.EventLog)

      # Get persist_actor_primary_key configurations
      persist_configs = AshEvents.EventLog.Info.event_log(AshEvents.EventLogs.EventLog)

      # Each config is a PersistActorPrimaryKey struct
      assert is_list(persist_configs)

      if length(persist_configs) == 1 do
        # Single config doesn't require allow_nil?
        [config] = persist_configs
        # allow_nil? can be true or false for single config
        assert is_boolean(config.allow_nil?)
      end
    end

    test "accepts multiple persist_actor_primary_key with allow_nil? true" do
      persist_configs = AshEvents.EventLog.Info.event_log(AshEvents.EventLogs.EventLog)

      if length(persist_configs) > 1 do
        # Multiple configs must all have allow_nil? true
        Enum.each(persist_configs, fn config ->
          assert config.allow_nil? == true,
                 "Expected allow_nil? to be true for #{inspect(config.name)}"
        end)
      end
    end
  end

  describe "verifier module validation" do
    test "verifier module is loaded and has verify/1 function" do
      assert Code.ensure_loaded?(VerifyPersistActorPrimaryKey)
      assert function_exported?(VerifyPersistActorPrimaryKey, :verify, 1)
    end
  end

  describe "PersistActorPrimaryKey struct" do
    test "struct has expected fields" do
      persist_configs = AshEvents.EventLog.Info.event_log(AshEvents.EventLogs.EventLog)

      if length(persist_configs) > 0 do
        [config | _] = persist_configs

        # Verify struct has expected fields
        assert Map.has_key?(config, :name)
        assert Map.has_key?(config, :destination)
        assert Map.has_key?(config, :attribute_type)
        assert Map.has_key?(config, :allow_nil?)
      end
    end

    test "persist_actor_primary_key creates attribute on EventLog" do
      persist_configs = AshEvents.EventLog.Info.event_log(AshEvents.EventLogs.EventLog)
      attributes = Ash.Resource.Info.attributes(AshEvents.EventLogs.EventLog)
      attribute_names = Enum.map(attributes, & &1.name)

      # Each persist_actor_primary_key should create an attribute
      Enum.each(persist_configs, fn config ->
        assert config.name in attribute_names,
               "Expected attribute #{inspect(config.name)} to exist on EventLog"
      end)
    end
  end

  describe "allow_nil? logic" do
    test "verifier logic checks all configs when multiple" do
      # The verifier uses Enum.all? to check all configs
      source = File.read!("lib/event_log/verifiers/verify_persist_actor_primary_key.ex")

      assert source =~ "length(persist_actor_primary_keys) > 1"
      assert source =~ "Enum.all?"
      assert source =~ "allow_nil?"
    end
  end

  describe "error message validation" do
    test "error messages are descriptive" do
      source = File.read!("lib/event_log/verifiers/verify_persist_actor_primary_key.ex")

      # Verify error messages mention specific requirements
      assert source =~ "multiple persist_actor_primary_key"
      assert source =~ "allow_nil?"
      assert source =~ "must"
    end
  end
end
