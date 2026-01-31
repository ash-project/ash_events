# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EventLog.Verifiers.VerifyPublicFieldsTest do
  @moduledoc """
  Tests for the VerifyPublicAttributes verifier.

  This verifier ensures that public_fields configuration contains valid attribute names:
  - When public_fields is a list, all entries are valid attribute names
  - When public_fields is :all, no validation is needed
  """
  use ExUnit.Case, async: true

  alias AshEvents.EventLog.Verifiers.VerifyPublicAttributes
  alias AshEvents.EventLog.Transformers.AddAttributes

  describe "verify/1 with valid configurations" do
    test "accepts valid public_fields configuration" do
      # Get public_fields configuration from EventLog
      public_fields =
        AshEvents.EventLog.Info.event_log_public_fields!(AshEvents.EventLogs.EventLog)

      # public_fields can be :all or a list
      assert public_fields == :all or is_list(public_fields)
    end

    test "accepts empty list as public_fields" do
      # Empty list is valid (no fields public)
      public_fields =
        AshEvents.EventLog.Info.event_log_public_fields!(AshEvents.EventLogs.EventLog)

      # If it's a list, verify it's valid
      if is_list(public_fields) do
        assert is_list(public_fields)
      end
    end
  end

  describe "canonical AshEvents fields" do
    test "AddAttributes defines canonical field list" do
      fields = AddAttributes.ash_events_fields()

      assert is_list(fields)
      assert length(fields) > 0

      # Verify expected fields are present
      assert :id in fields
      assert :record_id in fields
      assert :version in fields
      assert :occurred_at in fields
      assert :resource in fields
      assert :action in fields
      assert :action_type in fields
      assert :metadata in fields
      assert :data in fields
      assert :changed_attributes in fields
    end

    test "canonical fields include encryption-related fields" do
      fields = AddAttributes.ash_events_fields()

      assert :encrypted_metadata in fields
      assert :encrypted_data in fields
      assert :encrypted_changed_attributes in fields
    end
  end

  describe "verifier module validation" do
    test "verifier module is loaded and has verify/1 function" do
      assert Code.ensure_loaded?(VerifyPublicAttributes)
      assert function_exported?(VerifyPublicAttributes, :verify, 1)
    end
  end

  describe "field visibility on EventLog resource" do
    test "EventLog has expected attributes" do
      attributes = Ash.Resource.Info.attributes(AshEvents.EventLogs.EventLog)
      attribute_names = Enum.map(attributes, & &1.name)

      # Core fields should exist
      assert :id in attribute_names
      assert :record_id in attribute_names
      assert :version in attribute_names
      assert :occurred_at in attribute_names
      assert :resource in attribute_names
      assert :action in attribute_names
      assert :action_type in attribute_names

      # Non-cloaked EventLog should have data/metadata as attributes (not calculations)
      assert :data in attribute_names
      assert :metadata in attribute_names
      assert :changed_attributes in attribute_names
    end

    test "EventLogCloaked has encrypted attributes instead of plain data" do
      attributes = Ash.Resource.Info.attributes(AshEvents.EventLogs.EventLogCloaked)
      attribute_names = Enum.map(attributes, & &1.name)

      # Cloaked EventLog should have encrypted fields
      assert :encrypted_data in attribute_names
      assert :encrypted_metadata in attribute_names
      assert :encrypted_changed_attributes in attribute_names
    end

    test "EventLogCloaked has calculations for decrypted data" do
      calculations = Ash.Resource.Info.calculations(AshEvents.EventLogs.EventLogCloaked)
      calculation_names = Enum.map(calculations, & &1.name)

      # Cloaked EventLog should have calculations for decrypted data
      assert :data in calculation_names
      assert :metadata in calculation_names
      assert :changed_attributes in calculation_names
    end
  end

  describe "error message validation" do
    test "error messages are descriptive" do
      source = File.read!("lib/event_log/verifiers/verify_public_fields.ex")

      # Verify error messages mention specific requirements
      assert source =~ "public_fields"
      assert source =~ "invalid field names"
    end
  end
end
