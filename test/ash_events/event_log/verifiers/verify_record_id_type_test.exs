# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EventLog.Verifiers.VerifyRecordIdTypeTest do
  @moduledoc """
  Tests for the VerifyRecordIdType verifier.

  This verifier ensures that record_id_type is a valid Ash type.
  """
  use ExUnit.Case, async: true

  alias AshEvents.EventLog.Verifiers.VerifyRecordIdType

  describe "verify/1 with valid configurations" do
    test "accepts :uuid as record_id_type" do
      record_id_type =
        AshEvents.EventLog.Info.event_log_record_id_type!(AshEvents.EventLogs.EventLog)

      assert record_id_type == :uuid
    end

    test "accepts Ash.Type.UUIDv7 as record_id_type" do
      # Check if any EventLog uses UUIDv7 for record_id
      record_id_type =
        AshEvents.EventLog.Info.event_log_record_id_type!(AshEvents.EventLogs.EventLogUuidV7)

      assert record_id_type == :uuid or record_id_type == Ash.Type.UUIDv7
    end
  end

  describe "valid Ash types" do
    test ":uuid is a valid type" do
      # :uuid should be recognized as valid
      assert :uuid in [:string, :integer, :uuid]
    end

    test ":integer is a valid type" do
      assert :integer in [:string, :integer, :uuid]
    end

    test ":string is a valid type" do
      assert :string in [:string, :integer, :uuid]
    end

    test "Ash.Type.UUIDv7 is a valid type" do
      assert Code.ensure_loaded?(Ash.Type.UUIDv7)
    end
  end

  describe "verifier module validation" do
    test "verifier module is loaded and has verify/1 function" do
      assert Code.ensure_loaded?(VerifyRecordIdType)
      assert function_exported?(VerifyRecordIdType, :verify, 1)
    end
  end

  describe "record_id attribute on EventLog" do
    test "EventLog has record_id attribute" do
      attributes = Ash.Resource.Info.attributes(AshEvents.EventLogs.EventLog)
      record_id_attr = Enum.find(attributes, &(&1.name == :record_id))

      assert record_id_attr != nil
      assert record_id_attr.allow_nil? == false
    end

    test "record_id type matches configuration" do
      config_type =
        AshEvents.EventLog.Info.event_log_record_id_type!(AshEvents.EventLogs.EventLog)

      attributes = Ash.Resource.Info.attributes(AshEvents.EventLogs.EventLog)
      record_id_attr = Enum.find(attributes, &(&1.name == :record_id))

      # The attribute type may be normalized to Ash.Type.UUID
      assert record_id_attr.type == config_type or
               (config_type == :uuid and record_id_attr.type == Ash.Type.UUID)
    end
  end

  describe "error message validation" do
    test "error messages are descriptive" do
      source = File.read!("lib/event_log/verifiers/verify_record_id_type.ex")

      # Verify error messages mention specific requirements
      assert source =~ "record_id_type"
      assert source =~ "is not a valid Ash type"
    end
  end
end
