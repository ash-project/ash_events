# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.PublicAttributesTest do
  use AshEvents.RepoCase, async: true
  alias AshEvents.EventLogs.EventLog
  alias AshEvents.EventLogs.EventLogMissingClear
  alias AshEvents.EventLogs.EventLogUuidV7

  describe "public attributes configuration" do
    test "EventLogUuidV7 has all attributes public" do
      attributes = Ash.Resource.Info.attributes(EventLogUuidV7)
      calculations = Ash.Resource.Info.calculations(EventLogUuidV7)

      # Test all attributes are public
      for attribute <- attributes do
        assert attribute.public? == true,
               "Attribute #{attribute.name} should be public but is not"
      end

      # Test all calculations are public
      for calculation <- calculations do
        assert calculation.public? == true,
               "Calculation #{calculation.name} should be public but is not"
      end

      # Verify we have the expected attributes
      attribute_names = Enum.map(attributes, & &1.name)

      assert :id in attribute_names
      assert :record_id in attribute_names
      assert :version in attribute_names
      assert :occurred_at in attribute_names
      assert :resource in attribute_names
      assert :action in attribute_names
      assert :action_type in attribute_names
      assert :metadata in attribute_names
      assert :data in attribute_names
      assert :changed_attributes in attribute_names
      assert :user_id in attribute_names
      assert :system_actor in attribute_names
    end

    test "EventLog has all attributes private (default behavior)" do
      attributes = Ash.Resource.Info.attributes(EventLog)
      calculations = Ash.Resource.Info.calculations(EventLog)

      # Test all attributes are private (default)
      for attribute <- attributes do
        assert attribute.public? == false,
               "Attribute #{attribute.name} should be private but is public"
      end

      # Test all calculations are private (default)
      for calculation <- calculations do
        assert calculation.public? == false,
               "Calculation #{calculation.name} should be private but is public"
      end

      # Verify we have the expected attributes
      attribute_names = Enum.map(attributes, & &1.name)

      assert :id in attribute_names
      assert :record_id in attribute_names
      assert :version in attribute_names
      assert :occurred_at in attribute_names
      assert :resource in attribute_names
      assert :action in attribute_names
      assert :action_type in attribute_names
      assert :metadata in attribute_names
      assert :data in attribute_names
      assert :changed_attributes in attribute_names
      assert :user_id in attribute_names
      assert :system_actor in attribute_names
    end

    test "EventLogMissingClear has only id and version as public attributes" do
      attributes = Ash.Resource.Info.attributes(EventLogMissingClear)
      calculations = Ash.Resource.Info.calculations(EventLogMissingClear)

      # Check that only id and version are public
      for attribute <- attributes do
        if attribute.name in [:id, :version] do
          assert attribute.public? == true,
                 "Attribute #{attribute.name} should be public but is not"
        else
          assert attribute.public? == false,
                 "Attribute #{attribute.name} should be private but is public"
        end
      end

      # All calculations should be private (not in the list)
      for calculation <- calculations do
        assert calculation.public? == false,
               "Calculation #{calculation.name} should be private but is public"
      end

      # Verify we have the expected attributes
      attribute_names = Enum.map(attributes, & &1.name)

      assert :id in attribute_names
      assert :version in attribute_names
      assert :record_id in attribute_names
      assert :occurred_at in attribute_names
      assert :resource in attribute_names
      assert :action in attribute_names
      assert :action_type in attribute_names
      assert :metadata in attribute_names
      assert :data in attribute_names
      assert :changed_attributes in attribute_names
      assert :user_id in attribute_names
      assert :system_actor in attribute_names

      # Verify configuration
      public_fields = AshEvents.EventLog.Info.event_log_public_fields!(EventLogMissingClear)
      assert public_fields == [:id, :version]
    end

    test "public_fields configuration works correctly" do
      # Verify EventLogUuidV7 has public_fields set to :all
      public_fields = AshEvents.EventLog.Info.event_log_public_fields!(EventLogUuidV7)
      assert public_fields == :all

      # Verify EventLog has public_fields set to default (empty list)
      public_fields_default = AshEvents.EventLog.Info.event_log_public_fields!(EventLog)
      assert public_fields_default == []
    end
  end
end
