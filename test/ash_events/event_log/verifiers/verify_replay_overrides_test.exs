# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EventLog.Verifiers.VerifyReplayOverridesTest do
  @moduledoc """
  Tests for the VerifyReplayOverrides verifier.

  This verifier ensures that replay_overrides configuration is valid:
  - route_to.resource references an existing Ash resource
  - route_to.action references an existing action on the route_to.resource
  """
  use ExUnit.Case, async: true

  alias AshEvents.EventLog.Verifiers.VerifyReplayOverrides

  describe "verify/1 with valid configurations" do
    test "EventLog with replay_overrides compiles successfully" do
      assert Code.ensure_loaded?(AshEvents.EventLogs.EventLog)

      # Get replay overrides
      replay_overrides = AshEvents.EventLog.Info.replay_overrides(AshEvents.EventLogs.EventLog)

      assert is_list(replay_overrides)
    end

    test "replay_overrides can reference valid resources" do
      # User resource exists and can be used in replay_overrides
      assert Ash.Resource.Info.resource?(AshEvents.Accounts.User)
    end

    test "replay_overrides can reference valid actions" do
      # User resource has actions that can be used in route_to
      actions = Ash.Resource.Info.actions(AshEvents.Accounts.User)
      action_names = Enum.map(actions, & &1.name)

      # Should have replay-specific actions
      assert :register_with_password_replay in action_names or :create in action_names
    end
  end

  describe "verifier module validation" do
    test "verifier module is loaded and has verify/1 function" do
      assert Code.ensure_loaded?(VerifyReplayOverrides)
      assert function_exported?(VerifyReplayOverrides, :verify, 1)
    end
  end

  describe "replay override validation logic" do
    test "Ash.Resource.Info.resource? validates resources" do
      # Valid resource
      assert Ash.Resource.Info.resource?(AshEvents.Accounts.User)

      # Invalid resource
      refute Ash.Resource.Info.resource?(String)
      refute Ash.Resource.Info.resource?(NonExistentModule)
    end

    test "Ash.Resource.Info.action validates actions" do
      # Valid action
      action = Ash.Resource.Info.action(AshEvents.Accounts.User, :create)
      assert action != nil

      # Invalid action
      invalid_action = Ash.Resource.Info.action(AshEvents.Accounts.User, :non_existent_action)
      assert invalid_action == nil
    end
  end

  describe "error message validation" do
    test "error messages are descriptive" do
      source = File.read!("lib/event_log/verifiers/verify_replay_overrides.ex")

      # Verify error messages mention specific requirements
      assert source =~ "route_to"
      assert source =~ "does not exist"
      assert source =~ "replay_override"
    end
  end
end
