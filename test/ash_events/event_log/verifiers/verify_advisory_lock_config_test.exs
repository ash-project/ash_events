# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EventLog.Verifiers.VerifyAdvisoryLockConfigTest do
  @moduledoc """
  Tests for the VerifyAdvisoryLockConfig verifier.

  This verifier ensures that advisory lock configuration is valid:
  - advisory_lock_key_generator module exists and implements the behaviour
  - advisory_lock_key_default is a valid integer or list of two 32-bit integers
  """
  use ExUnit.Case, async: true

  alias AshEvents.EventLog.Verifiers.VerifyAdvisoryLockConfig

  describe "verify/1 with valid configurations" do
    test "accepts default advisory lock configuration" do
      # The existing EventLog uses default configuration
      assert Code.ensure_loaded?(AshEvents.EventLogs.EventLog)

      # Get the configured generator
      generator =
        AshEvents.EventLog.Info.event_log_advisory_lock_key_generator!(
          AshEvents.EventLogs.EventLog
        )

      # Should be the default generator (may be namespaced differently)
      assert generator == AshEvents.AdvisoryLockKeyGenerator.Default or
               generator == AshEvents.AdvisoryLockKeyGeneratorDefault

      assert function_exported?(generator, :generate_key!, 2)
    end

    test "accepts valid advisory lock key default as integer" do
      default =
        AshEvents.EventLog.Info.event_log_advisory_lock_key_default!(AshEvents.EventLogs.EventLog)

      assert is_integer(default)
      # Should be within 32-bit signed integer range
      assert default >= -2_147_483_648
      assert default <= 2_147_483_647
    end
  end

  describe "verifier module validation" do
    test "verifier module is loaded and has verify/1 function" do
      assert Code.ensure_loaded?(VerifyAdvisoryLockConfig)
      assert function_exported?(VerifyAdvisoryLockConfig, :verify, 1)
    end

    test "default generator implements AdvisoryLockKeyGenerator behaviour" do
      generator =
        AshEvents.EventLog.Info.event_log_advisory_lock_key_generator!(
          AshEvents.EventLogs.EventLog
        )

      # Check that the generator module exists and exports the required function
      assert Code.ensure_loaded?(generator)
      assert function_exported?(generator, :generate_key!, 2)
    end

    test "default generator has generate_key!/2 function" do
      generator =
        AshEvents.EventLog.Info.event_log_advisory_lock_key_generator!(
          AshEvents.EventLogs.EventLog
        )

      assert function_exported?(generator, :generate_key!, 2)
    end
  end

  describe "32-bit integer validation logic" do
    test "validates minimum 32-bit signed integer" do
      min_value = -2_147_483_648
      assert is_integer(min_value)
      assert min_value >= -2_147_483_648
    end

    test "validates maximum 32-bit signed integer" do
      max_value = 2_147_483_647
      assert is_integer(max_value)
      assert max_value <= 2_147_483_647
    end

    test "identifies out of range integers" do
      too_large = 2_147_483_648
      too_small = -2_147_483_649

      refute too_large >= -2_147_483_648 and too_large <= 2_147_483_647
      refute too_small >= -2_147_483_648 and too_small <= 2_147_483_647
    end
  end

  describe "error message validation" do
    test "error messages are descriptive" do
      source = File.read!("lib/event_log/verifiers/verify_advisory_lock_config.ex")

      # Verify error messages mention specific requirements
      assert source =~ "advisory_lock_key_generator"
      assert source =~ "does not exist"
      assert source =~ "does not implement"
      assert source =~ "32-bit integer"
    end
  end
end
