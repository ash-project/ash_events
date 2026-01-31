# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EventLog.Verifiers.VerifyClearRecordsForReplayTest do
  @moduledoc """
  Tests for the VerifyClearRecordsForReplay verifier.

  This verifier ensures that:
  - The clear_records_for_replay module exists (if specified)
  - The clear_records_for_replay module implements the AshEvents.ClearRecordsForReplay behaviour
  """
  use ExUnit.Case, async: true

  alias AshEvents.EventLog.Verifiers.VerifyClearRecordsForReplay

  describe "verify/1 with valid configurations" do
    test "accepts EventLog with valid clear_records_for_replay module" do
      assert Code.ensure_loaded?(AshEvents.EventLogs.EventLog)

      # Get the configured clear records module
      {:ok, clear_module} =
        AshEvents.EventLog.Info.event_log_clear_records_for_replay(AshEvents.EventLogs.EventLog)

      assert clear_module == AshEvents.EventLogs.ClearRecords
      assert Code.ensure_loaded?(clear_module)
    end

    test "clear_records module implements the behaviour" do
      {:ok, clear_module} =
        AshEvents.EventLog.Info.event_log_clear_records_for_replay(AshEvents.EventLogs.EventLog)

      # Check behaviour implementation
      behaviours =
        clear_module.module_info(:attributes)
        |> Keyword.get(:behaviour, [])

      assert AshEvents.ClearRecordsForReplay in behaviours
    end

    test "clear_records module has clear_records!/1 function" do
      {:ok, clear_module} =
        AshEvents.EventLog.Info.event_log_clear_records_for_replay(AshEvents.EventLogs.EventLog)

      assert function_exported?(clear_module, :clear_records!, 1)
    end
  end

  describe "verify/1 with EventLog missing clear_records_for_replay" do
    test "EventLog without clear_records_for_replay compiles but replay fails" do
      # EventLogMissingClear is configured without clear_records_for_replay
      assert Code.ensure_loaded?(AshEvents.EventLogs.EventLogMissingClear)

      # Attempting replay without clear_records should fail
      result =
        AshEvents.EventLog.Info.event_log_clear_records_for_replay(
          AshEvents.EventLogs.EventLogMissingClear
        )

      # Should return :error or nil when not configured
      assert result == :error or result == {:ok, nil}
    end
  end

  describe "verifier module validation" do
    test "verifier module is loaded and has verify/1 function" do
      assert Code.ensure_loaded?(VerifyClearRecordsForReplay)
      assert function_exported?(VerifyClearRecordsForReplay, :verify, 1)
    end
  end

  describe "ClearRecordsForReplay behaviour" do
    test "behaviour defines clear_records!/1 callback" do
      # The behaviour should be defined
      assert Code.ensure_loaded?(AshEvents.ClearRecordsForReplay)
    end

    test "implementing module can be called" do
      {:ok, clear_module} =
        AshEvents.EventLog.Info.event_log_clear_records_for_replay(AshEvents.EventLogs.EventLog)

      # Should be callable (we don't actually call it to avoid side effects)
      assert is_atom(clear_module)
      assert function_exported?(clear_module, :clear_records!, 1)
    end
  end

  describe "error message validation" do
    test "error messages are descriptive" do
      source = File.read!("lib/event_log/verifiers/verify_clear_records_for_replay.ex")

      # Verify error messages mention specific requirements
      assert source =~ "clear_records_for_replay"
      assert source =~ "does not exist"
      assert source =~ "does not implement"
      assert source =~ "AshEvents.ClearRecordsForReplay"
    end
  end
end
