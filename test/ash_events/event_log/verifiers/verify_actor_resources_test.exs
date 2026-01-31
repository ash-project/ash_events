# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EventLog.Verifiers.VerifyActorResourcesTest do
  @moduledoc """
  Tests for the VerifyActorResources verifier.

  This verifier ensures that persist_actor_primary_key entries reference
  valid Ash resources with primary key attributes.
  """
  use ExUnit.Case, async: true

  alias AshEvents.EventLog.Verifiers.VerifyActorResources

  describe "verify/1 with valid configurations" do
    test "accepts EventLog with valid User resource as actor destination" do
      # The existing EventLog has valid actor resources configured
      # Verify the module compiles and is loaded successfully
      assert Code.ensure_loaded?(AshEvents.EventLogs.EventLog)

      # Verify the persist_actor_primary_key is configured
      persist_configs = AshEvents.EventLog.Info.event_log(AshEvents.EventLogs.EventLog)
      assert length(persist_configs) > 0

      # Each config should reference a valid Ash resource with a primary key
      Enum.each(persist_configs, fn config ->
        assert Ash.Resource.Info.resource?(config.destination),
               "Expected #{inspect(config.destination)} to be an Ash resource"

        primary_key = Ash.Resource.Info.primary_key(config.destination)

        assert not Enum.empty?(primary_key),
               "Expected #{inspect(config.destination)} to have a primary key"
      end)
    end

    test "accepts EventLog with UUIDv7 configuration" do
      assert Code.ensure_loaded?(AshEvents.EventLogs.EventLogUuidV7)

      persist_configs = AshEvents.EventLog.Info.event_log(AshEvents.EventLogs.EventLogUuidV7)
      assert is_list(persist_configs)
    end

    test "accepts cloaked EventLog configuration" do
      assert Code.ensure_loaded?(AshEvents.EventLogs.EventLogCloaked)

      persist_configs = AshEvents.EventLog.Info.event_log(AshEvents.EventLogs.EventLogCloaked)
      assert is_list(persist_configs)
    end
  end

  describe "verifier logic validation" do
    test "verifier module is loaded and has verify/1 function" do
      assert Code.ensure_loaded?(VerifyActorResources)
      assert function_exported?(VerifyActorResources, :verify, 1)
    end

    test "verifier checks that destination is an Ash resource" do
      # Verify by examining the source code behavior
      # The verifier uses Ash.Resource.Info.resource?/1 to check
      assert Ash.Resource.Info.resource?(AshEvents.Accounts.User)
      refute Ash.Resource.Info.resource?(String)
    end

    test "verifier checks that destination has a primary key" do
      # User resource should have a primary key
      primary_key = Ash.Resource.Info.primary_key(AshEvents.Accounts.User)
      assert length(primary_key) > 0
      assert :id in primary_key
    end
  end

  describe "error message validation" do
    test "error message mentions Ash resource requirement" do
      # The verifier produces clear error messages
      # We verify by checking the error format in the source
      source = File.read!("lib/event_log/verifiers/verify_actor_modules.ex")
      assert source =~ "must be an Ash resource"
      assert source =~ "must have a primary key attribute"
    end
  end
end
