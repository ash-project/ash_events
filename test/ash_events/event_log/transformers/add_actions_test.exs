# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EventLog.Transformers.AddActionsTest do
  @moduledoc """
  Tests for the AddActions transformer.

  This transformer injects the necessary actions into the EventLog resource:
  - create action for storing events
  - replay action for replaying events
  """
  use ExUnit.Case, async: true

  describe "create action" do
    test "EventLog has create action" do
      actions = Ash.Resource.Info.actions(AshEvents.EventLogs.EventLog)
      create_action = Enum.find(actions, &(&1.name == :create and &1.type == :create))

      assert create_action != nil
    end

    test "create action accepts core event fields" do
      actions = Ash.Resource.Info.actions(AshEvents.EventLogs.EventLog)
      create_action = Enum.find(actions, &(&1.name == :create and &1.type == :create))

      # Core fields that should be accepted
      expected_accepts = [
        :version,
        :record_id,
        :resource,
        :action,
        :action_type,
        :occurred_at
      ]

      Enum.each(expected_accepts, fn field ->
        assert field in create_action.accept,
               "create action should accept #{inspect(field)}"
      end)
    end

    test "non-cloaked create action accepts data fields directly" do
      actions = Ash.Resource.Info.actions(AshEvents.EventLogs.EventLog)
      create_action = Enum.find(actions, &(&1.name == :create and &1.type == :create))

      # Non-cloaked should accept data, metadata, changed_attributes
      assert :data in create_action.accept
      assert :metadata in create_action.accept
      assert :changed_attributes in create_action.accept
    end

    test "create action accepts actor primary key fields" do
      persist_configs = AshEvents.EventLog.Info.event_log(AshEvents.EventLogs.EventLog)
      actions = Ash.Resource.Info.actions(AshEvents.EventLogs.EventLog)
      create_action = Enum.find(actions, &(&1.name == :create and &1.type == :create))

      Enum.each(persist_configs, fn config ->
        assert config.name in create_action.accept,
               "create action should accept actor field #{inspect(config.name)}"
      end)
    end
  end

  describe "cloaked create action" do
    test "EventLogCloaked create action has encrypt change" do
      actions = Ash.Resource.Info.actions(AshEvents.EventLogs.EventLogCloaked)
      create_action = Enum.find(actions, &(&1.name == :create and &1.type == :create))

      assert create_action != nil

      # Should have encryption change
      change_modules =
        Enum.map(create_action.changes, fn
          %Ash.Resource.Change{change: {module, _opts}} -> module
          _ -> nil
        end)
        |> Enum.reject(&is_nil/1)

      assert AshEvents.EventLog.Changes.Encrypt in change_modules
    end

    test "cloaked create action has arguments for data fields" do
      actions = Ash.Resource.Info.actions(AshEvents.EventLogs.EventLogCloaked)
      create_action = Enum.find(actions, &(&1.name == :create and &1.type == :create))

      argument_names = Enum.map(create_action.arguments, & &1.name)

      # Cloaked should have data, metadata, changed_attributes as arguments
      assert :data in argument_names
      assert :metadata in argument_names
      assert :changed_attributes in argument_names
    end
  end

  describe "replay action" do
    test "EventLog has replay action" do
      actions = Ash.Resource.Info.actions(AshEvents.EventLogs.EventLog)
      replay_action = Enum.find(actions, &(&1.name == :replay and &1.type == :action))

      assert replay_action != nil
    end

    test "replay action has last_event_id argument" do
      actions = Ash.Resource.Info.actions(AshEvents.EventLogs.EventLog)
      replay_action = Enum.find(actions, &(&1.name == :replay and &1.type == :action))

      last_event_id_arg = Enum.find(replay_action.arguments, &(&1.name == :last_event_id))

      assert last_event_id_arg != nil
      assert last_event_id_arg.allow_nil? == true
    end

    test "replay action has point_in_time argument" do
      actions = Ash.Resource.Info.actions(AshEvents.EventLogs.EventLog)
      replay_action = Enum.find(actions, &(&1.name == :replay and &1.type == :action))

      point_in_time_arg = Enum.find(replay_action.arguments, &(&1.name == :point_in_time))

      assert point_in_time_arg != nil
      assert point_in_time_arg.type in [:utc_datetime_usec, Ash.Type.UtcDatetimeUsec]
      assert point_in_time_arg.allow_nil? == true
    end

    test "replay action runs AshEvents.EventLog.Actions.Replay" do
      actions = Ash.Resource.Info.actions(AshEvents.EventLogs.EventLog)
      replay_action = Enum.find(actions, &(&1.name == :replay and &1.type == :action))

      # The run option should reference the Replay action module
      {run_module, _opts} = replay_action.run

      assert run_module == AshEvents.EventLog.Actions.Replay
    end
  end

  describe "UUIDv7 EventLog actions" do
    test "EventLogUuidV7 replay action has UUIDv7 last_event_id type" do
      actions = Ash.Resource.Info.actions(AshEvents.EventLogs.EventLogUuidV7)
      replay_action = Enum.find(actions, &(&1.name == :replay and &1.type == :action))

      last_event_id_arg = Enum.find(replay_action.arguments, &(&1.name == :last_event_id))

      assert last_event_id_arg != nil
      # Type should match the primary key type (UUIDv7)
      assert last_event_id_arg.type == Ash.Type.UUIDv7
    end
  end

  describe "replay overrides integration" do
    test "replay action passes overrides to run module" do
      actions = Ash.Resource.Info.actions(AshEvents.EventLogs.EventLog)
      replay_action = Enum.find(actions, &(&1.name == :replay and &1.type == :action))

      {_run_module, opts} = replay_action.run

      # Should have overrides option
      assert Keyword.has_key?(opts, :overrides)
    end
  end
end
