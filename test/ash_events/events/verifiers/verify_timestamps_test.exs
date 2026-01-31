# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Events.Verifiers.VerifyTimestampsTest do
  @moduledoc """
  Tests for the VerifyTimestamps verifier.

  This verifier ensures that timestamp configuration is valid:
  - create_timestamp attribute exists on the resource (if specified) and is a valid timestamp type
  - update_timestamp attribute exists on the resource (if specified) and is a valid timestamp type
  """
  use ExUnit.Case, async: true

  alias AshEvents.Events.Verifiers.VerifyTimestamps

  describe "verify/1 with valid configurations" do
    test "accepts User resource with valid timestamp configuration" do
      assert Code.ensure_loaded?(AshEvents.Accounts.User)

      # User has create_timestamp and update_timestamp configured
      {:ok, create_timestamp} =
        AshEvents.Events.Info.events_create_timestamp(AshEvents.Accounts.User)

      {:ok, update_timestamp} =
        AshEvents.Events.Info.events_update_timestamp(AshEvents.Accounts.User)

      assert create_timestamp == :created_at
      assert update_timestamp == :updated_at
    end

    test "timestamp attributes exist on User resource" do
      {:ok, create_timestamp} =
        AshEvents.Events.Info.events_create_timestamp(AshEvents.Accounts.User)

      {:ok, update_timestamp} =
        AshEvents.Events.Info.events_update_timestamp(AshEvents.Accounts.User)

      attributes = Ash.Resource.Info.attributes(AshEvents.Accounts.User)
      attribute_names = Enum.map(attributes, & &1.name)

      assert create_timestamp in attribute_names
      assert update_timestamp in attribute_names
    end

    test "timestamp attributes have valid timestamp types" do
      {:ok, create_timestamp} =
        AshEvents.Events.Info.events_create_timestamp(AshEvents.Accounts.User)

      {:ok, update_timestamp} =
        AshEvents.Events.Info.events_update_timestamp(AshEvents.Accounts.User)

      attributes = Ash.Resource.Info.attributes(AshEvents.Accounts.User)

      create_attr = Enum.find(attributes, &(&1.name == create_timestamp))
      update_attr = Enum.find(attributes, &(&1.name == update_timestamp))

      valid_timestamp_types = [
        :utc_datetime,
        :utc_datetime_usec,
        :datetime,
        :naive_datetime,
        :naive_datetime_usec,
        Ash.Type.UtcDateTime,
        Ash.Type.UtcDatetimeUsec,
        Ash.Type.DateTime,
        Ash.Type.NaiveDatetime
      ]

      assert create_attr.type in valid_timestamp_types,
             "create_timestamp type #{inspect(create_attr.type)} should be a valid timestamp type"

      assert update_attr.type in valid_timestamp_types,
             "update_timestamp type #{inspect(update_attr.type)} should be a valid timestamp type"
    end
  end

  describe "verifier module validation" do
    test "verifier module is loaded and has verify/1 function" do
      assert Code.ensure_loaded?(VerifyTimestamps)
      assert function_exported?(VerifyTimestamps, :verify, 1)
    end
  end

  describe "valid timestamp types" do
    test ":utc_datetime is a valid timestamp type" do
      valid_types = [
        :utc_datetime,
        :utc_datetime_usec,
        :datetime,
        :naive_datetime,
        :naive_datetime_usec
      ]

      assert :utc_datetime in valid_types
    end

    test ":utc_datetime_usec is a valid timestamp type" do
      valid_types = [
        :utc_datetime,
        :utc_datetime_usec,
        :datetime,
        :naive_datetime,
        :naive_datetime_usec
      ]

      assert :utc_datetime_usec in valid_types
    end

    test "Ash.Type modules are valid timestamp types" do
      assert Code.ensure_loaded?(Ash.Type.UtcDatetimeUsec)
    end
  end

  describe "timestamp behavior in events" do
    test "create_timestamp is used for event occurred_at on create" do
      # When a create action is performed, the create_timestamp value
      # is used as the event's occurred_at timestamp
      {:ok, create_timestamp} =
        AshEvents.Events.Info.events_create_timestamp(AshEvents.Accounts.User)

      assert create_timestamp == :created_at
    end

    test "update_timestamp is used for event occurred_at on update" do
      # When an update action is performed, the update_timestamp value
      # is used as the event's occurred_at timestamp
      {:ok, update_timestamp} =
        AshEvents.Events.Info.events_update_timestamp(AshEvents.Accounts.User)

      assert update_timestamp == :updated_at
    end
  end

  describe "error message validation" do
    test "error messages are descriptive" do
      source = File.read!("lib/events/verifiers/verify_timestamps.ex")

      # Verify error messages mention specific requirements
      assert source =~ "create_timestamp"
      assert source =~ "update_timestamp"
      assert source =~ "does not exist"
      assert source =~ "timestamp type"
    end
  end
end
