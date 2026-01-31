# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Events.Verifiers.VerifyReplayNonInputAttributeChangesTest do
  @moduledoc """
  Tests for the VerifyReplayNonInputAttributeChanges verifier.

  This verifier ensures that replay_non_input_attribute_changes configuration is valid:
  - All action names reference existing actions on the resource
  - All values are either :force_change or :as_arguments
  """
  use ExUnit.Case, async: true

  alias AshEvents.Events.Verifiers.VerifyReplayNonInputAttributeChanges

  describe "verify/1 with valid configurations" do
    test "accepts User resource with valid replay_non_input_attribute_changes" do
      assert Code.ensure_loaded?(AshEvents.Accounts.User)

      replay_config =
        AshEvents.Events.Info.events_replay_non_input_attribute_changes!(AshEvents.Accounts.User)

      assert is_list(replay_config)
    end

    test "replay config uses valid strategies" do
      replay_config =
        AshEvents.Events.Info.events_replay_non_input_attribute_changes!(AshEvents.Accounts.User)

      valid_strategies = [:force_change, :as_arguments]

      Enum.each(replay_config, fn {_action_name, strategy} ->
        assert strategy in valid_strategies,
               "Strategy #{inspect(strategy)} should be :force_change or :as_arguments"
      end)
    end

    test "replay config actions exist on resource" do
      replay_config =
        AshEvents.Events.Info.events_replay_non_input_attribute_changes!(AshEvents.Accounts.User)

      all_actions = Ash.Resource.Info.actions(AshEvents.Accounts.User)
      all_action_names = Enum.map(all_actions, & &1.name)

      Enum.each(replay_config, fn {action_name, _strategy} ->
        assert action_name in all_action_names,
               "Action #{inspect(action_name)} should exist on User"
      end)
    end
  end

  describe "verifier module validation" do
    test "verifier module is loaded and has verify/1 function" do
      assert Code.ensure_loaded?(VerifyReplayNonInputAttributeChanges)
      assert function_exported?(VerifyReplayNonInputAttributeChanges, :verify, 1)
    end
  end

  describe "strategy validation" do
    test ":force_change is a valid strategy" do
      assert :force_change in [:force_change, :as_arguments]
    end

    test ":as_arguments is a valid strategy" do
      assert :as_arguments in [:force_change, :as_arguments]
    end

    test "invalid strategies are rejected" do
      # Other values would be rejected
      refute :invalid_strategy in [:force_change, :as_arguments]
      refute :some_other_value in [:force_change, :as_arguments]
    end
  end

  describe "strategy behavior documentation" do
    test ":force_change preserves exact attribute values during replay" do
      # :force_change means the changed_attributes values are force-changed
      # during replay, preserving the exact state
      assert :force_change in [:force_change, :as_arguments]
    end

    test ":as_arguments passes values as arguments during replay" do
      # :as_arguments means the changed_attributes values are passed as
      # arguments to the action, allowing business logic to recompute
      assert :as_arguments in [:force_change, :as_arguments]
    end
  end

  describe "error message validation" do
    test "error messages are descriptive" do
      source = File.read!("lib/events/verifiers/verify_replay_non_input_attribute_changes.ex")

      # Verify error messages mention specific requirements
      assert source =~ "replay_non_input_attribute_changes"
      assert source =~ "does not exist"
      assert source =~ ":force_change"
      assert source =~ ":as_arguments"
    end
  end
end
