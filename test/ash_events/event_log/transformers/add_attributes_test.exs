# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EventLog.Transformers.AddAttributesTest do
  @moduledoc """
  Tests for the AddAttributes transformer.

  This transformer injects the necessary attributes into the EventLog resource:
  - id (primary key)
  - record_id
  - version
  - occurred_at
  - resource
  - action
  - action_type
  - metadata/encrypted_metadata
  - data/encrypted_data
  - changed_attributes/encrypted_changed_attributes
  - Actor primary key attributes
  """
  use ExUnit.Case, async: true

  alias AshEvents.EventLog.Transformers.AddAttributes

  describe "ash_events_fields/0" do
    test "returns list of canonical field names" do
      fields = AddAttributes.ash_events_fields()

      assert is_list(fields)
      assert length(fields) > 0
    end

    test "includes core event tracking fields" do
      fields = AddAttributes.ash_events_fields()

      assert :id in fields
      assert :record_id in fields
      assert :version in fields
      assert :occurred_at in fields
      assert :resource in fields
      assert :action in fields
      assert :action_type in fields
    end

    test "includes data storage fields" do
      fields = AddAttributes.ash_events_fields()

      assert :data in fields
      assert :metadata in fields
      assert :changed_attributes in fields
    end

    test "includes encrypted field variants" do
      fields = AddAttributes.ash_events_fields()

      assert :encrypted_data in fields
      assert :encrypted_metadata in fields
      assert :encrypted_changed_attributes in fields
    end
  end

  describe "non-cloaked EventLog attributes" do
    test "EventLog has id attribute as primary key" do
      attributes = Ash.Resource.Info.attributes(AshEvents.EventLogs.EventLog)
      id_attr = Enum.find(attributes, &(&1.name == :id))

      assert id_attr != nil
      assert id_attr.primary_key? == true
    end

    test "EventLog has record_id attribute" do
      attributes = Ash.Resource.Info.attributes(AshEvents.EventLogs.EventLog)
      record_id_attr = Enum.find(attributes, &(&1.name == :record_id))

      assert record_id_attr != nil
      assert record_id_attr.allow_nil? == false
    end

    test "EventLog has version attribute with default 1" do
      attributes = Ash.Resource.Info.attributes(AshEvents.EventLogs.EventLog)
      version_attr = Enum.find(attributes, &(&1.name == :version))

      assert version_attr != nil
      assert version_attr.type in [:integer, Ash.Type.Integer]
      assert version_attr.allow_nil? == false
      assert version_attr.default == 1
    end

    test "EventLog has occurred_at timestamp" do
      attributes = Ash.Resource.Info.attributes(AshEvents.EventLogs.EventLog)
      occurred_at_attr = Enum.find(attributes, &(&1.name == :occurred_at))

      assert occurred_at_attr != nil
      assert occurred_at_attr.allow_nil? == false
    end

    test "EventLog has resource attribute" do
      attributes = Ash.Resource.Info.attributes(AshEvents.EventLogs.EventLog)
      resource_attr = Enum.find(attributes, &(&1.name == :resource))

      assert resource_attr != nil
      assert resource_attr.type in [:atom, Ash.Type.Atom]
      assert resource_attr.allow_nil? == false
    end

    test "EventLog has action attribute" do
      attributes = Ash.Resource.Info.attributes(AshEvents.EventLogs.EventLog)
      action_attr = Enum.find(attributes, &(&1.name == :action))

      assert action_attr != nil
      assert action_attr.type in [:atom, Ash.Type.Atom]
      assert action_attr.allow_nil? == false
    end

    test "EventLog has action_type attribute with constraints" do
      attributes = Ash.Resource.Info.attributes(AshEvents.EventLogs.EventLog)
      action_type_attr = Enum.find(attributes, &(&1.name == :action_type))

      assert action_type_attr != nil
      assert action_type_attr.type in [:atom, Ash.Type.Atom]
      assert action_type_attr.allow_nil? == false
      # Should be constrained to [:create, :update, :destroy]
      assert action_type_attr.constraints[:one_of] == [:create, :update, :destroy]
    end

    test "EventLog has data attribute as map" do
      attributes = Ash.Resource.Info.attributes(AshEvents.EventLogs.EventLog)
      data_attr = Enum.find(attributes, &(&1.name == :data))

      assert data_attr != nil
      assert data_attr.type in [:map, Ash.Type.Map]
      assert data_attr.allow_nil? == false
    end

    test "EventLog has metadata attribute as map" do
      attributes = Ash.Resource.Info.attributes(AshEvents.EventLogs.EventLog)
      metadata_attr = Enum.find(attributes, &(&1.name == :metadata))

      assert metadata_attr != nil
      assert metadata_attr.type in [:map, Ash.Type.Map]
      assert metadata_attr.allow_nil? == false
    end

    test "EventLog has changed_attributes attribute as map" do
      attributes = Ash.Resource.Info.attributes(AshEvents.EventLogs.EventLog)
      changed_attr = Enum.find(attributes, &(&1.name == :changed_attributes))

      assert changed_attr != nil
      assert changed_attr.type in [:map, Ash.Type.Map]
      assert changed_attr.allow_nil? == false
    end
  end

  describe "cloaked EventLog attributes" do
    test "EventLogCloaked has encrypted attributes instead of plain data" do
      attributes = Ash.Resource.Info.attributes(AshEvents.EventLogs.EventLogCloaked)
      attribute_names = Enum.map(attributes, & &1.name)

      # Should have encrypted fields as attributes
      assert :encrypted_data in attribute_names
      assert :encrypted_metadata in attribute_names
      assert :encrypted_changed_attributes in attribute_names

      # Plain fields should be calculations, not attributes
      refute :data in attribute_names
      refute :metadata in attribute_names
      refute :changed_attributes in attribute_names
    end

    test "EventLogCloaked has data as calculation" do
      calculations = Ash.Resource.Info.calculations(AshEvents.EventLogs.EventLogCloaked)
      data_calc = Enum.find(calculations, &(&1.name == :data))

      assert data_calc != nil
      assert data_calc.type in [:map, Ash.Type.Map]
    end

    test "EventLogCloaked has metadata as calculation" do
      calculations = Ash.Resource.Info.calculations(AshEvents.EventLogs.EventLogCloaked)
      metadata_calc = Enum.find(calculations, &(&1.name == :metadata))

      assert metadata_calc != nil
      assert metadata_calc.type in [:map, Ash.Type.Map]
    end

    test "EventLogCloaked has changed_attributes as calculation" do
      calculations = Ash.Resource.Info.calculations(AshEvents.EventLogs.EventLogCloaked)
      changed_calc = Enum.find(calculations, &(&1.name == :changed_attributes))

      assert changed_calc != nil
      assert changed_calc.type in [:map, Ash.Type.Map]
    end

    test "encrypted attributes are binary type" do
      attributes = Ash.Resource.Info.attributes(AshEvents.EventLogs.EventLogCloaked)

      encrypted_data = Enum.find(attributes, &(&1.name == :encrypted_data))
      encrypted_metadata = Enum.find(attributes, &(&1.name == :encrypted_metadata))
      encrypted_changed = Enum.find(attributes, &(&1.name == :encrypted_changed_attributes))

      assert encrypted_data.type in [:binary, Ash.Type.Binary]
      assert encrypted_metadata.type in [:binary, Ash.Type.Binary]
      assert encrypted_changed.type in [:binary, Ash.Type.Binary]
    end
  end

  describe "UUIDv7 primary key configuration" do
    test "EventLogUuidV7 has UUIDv7 primary key type" do
      attributes = Ash.Resource.Info.attributes(AshEvents.EventLogs.EventLogUuidV7)
      id_attr = Enum.find(attributes, &(&1.name == :id))

      assert id_attr != nil
      assert id_attr.primary_key? == true
      assert id_attr.type == Ash.Type.UUIDv7
    end
  end

  describe "actor primary key attributes" do
    test "EventLog has actor primary key attributes" do
      persist_configs = AshEvents.EventLog.Info.event_log(AshEvents.EventLogs.EventLog)
      attributes = Ash.Resource.Info.attributes(AshEvents.EventLogs.EventLog)
      attribute_names = Enum.map(attributes, & &1.name)

      # Each persist_actor_primary_key should create an attribute
      Enum.each(persist_configs, fn config ->
        assert config.name in attribute_names,
               "Expected actor attribute #{inspect(config.name)} to exist"
      end)
    end
  end

  describe "datetime_default/0" do
    test "returns current UTC time with microsecond precision" do
      before = DateTime.utc_now(:microsecond)
      default_time = AddAttributes.datetime_default()
      after_time = DateTime.utc_now(:microsecond)

      assert DateTime.compare(default_time, before) in [:eq, :gt]
      assert DateTime.compare(default_time, after_time) in [:eq, :lt]
    end
  end
end
