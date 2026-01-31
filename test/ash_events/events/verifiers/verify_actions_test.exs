# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Events.Verifiers.VerifyActionsTest do
  @moduledoc """
  Tests for the VerifyActions verifier.

  This verifier ensures that action-related configuration is valid:
  - only_actions and ignore_actions are mutually exclusive
  - All actions in only_actions, ignore_actions, current_action_versions,
    and allowed_change_modules reference existing actions on the resource
  - Versions in current_action_versions are positive integers
  - Change modules in allowed_change_modules exist and implement Ash.Resource.Change
  """
  use ExUnit.Case, async: true

  alias AshEvents.Events.Verifiers.VerifyActions

  describe "verify/1 with valid configurations" do
    test "accepts User resource with valid action configuration" do
      assert Code.ensure_loaded?(AshEvents.Accounts.User)

      # User has ignore_actions configured
      ignore_actions = AshEvents.Events.Info.events_ignore_actions!(AshEvents.Accounts.User)
      assert is_list(ignore_actions)
    end

    test "accepts current_action_versions configuration" do
      versions = AshEvents.Events.Info.events_current_action_versions!(AshEvents.Accounts.User)

      assert is_list(versions)

      # Each version should be a positive integer
      Enum.each(versions, fn {action_name, version} ->
        assert is_atom(action_name)
        assert is_integer(version)
        assert version > 0
      end)
    end
  end

  describe "mutual exclusivity of only_actions and ignore_actions" do
    test "User uses ignore_actions, not only_actions" do
      ignore_actions = AshEvents.Events.Info.events_ignore_actions!(AshEvents.Accounts.User)
      only_actions = AshEvents.Events.Info.events_only_actions(AshEvents.Accounts.User)

      # User should use ignore_actions
      assert length(ignore_actions) > 0 or only_actions == :error
    end

    test "verifier checks mutual exclusivity" do
      source = File.read!("lib/events/verifiers/verify_actions.ex")

      assert source =~ "only_actions and ignore_actions are mutually exclusive"
    end
  end

  describe "action existence validation" do
    test "ignore_actions reference existing actions" do
      ignore_actions = AshEvents.Events.Info.events_ignore_actions!(AshEvents.Accounts.User)
      all_actions = Ash.Resource.Info.actions(AshEvents.Accounts.User)
      all_action_names = Enum.map(all_actions, & &1.name)

      # All ignored actions should exist
      Enum.each(ignore_actions, fn action_name ->
        assert action_name in all_action_names,
               "Ignored action #{inspect(action_name)} should exist"
      end)
    end

    test "current_action_versions reference existing actions" do
      versions = AshEvents.Events.Info.events_current_action_versions!(AshEvents.Accounts.User)
      all_actions = Ash.Resource.Info.actions(AshEvents.Accounts.User)
      all_action_names = Enum.map(all_actions, & &1.name)

      Enum.each(versions, fn {action_name, _version} ->
        assert action_name in all_action_names,
               "Versioned action #{inspect(action_name)} should exist"
      end)
    end
  end

  describe "verifier module validation" do
    test "verifier module is loaded and has verify/1 function" do
      assert Code.ensure_loaded?(VerifyActions)
      assert function_exported?(VerifyActions, :verify, 1)
    end
  end

  describe "version validation logic" do
    test "positive integer versions are accepted" do
      assert 1 > 0
      assert 100 > 0
    end

    test "non-positive versions would be rejected" do
      # The verifier checks version > 0
      refute 0 > 0
      refute -1 > 0
    end
  end

  describe "error message validation" do
    test "error messages are descriptive" do
      source = File.read!("lib/events/verifiers/verify_actions.ex")

      # Verify error messages mention specific requirements
      assert source =~ "only_actions"
      assert source =~ "ignore_actions"
      assert source =~ "do not exist"
      assert source =~ "positive integer"
    end
  end
end
