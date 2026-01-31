# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.StateMachineTest do
  @moduledoc """
  Tests for state machine integration with events.

  This module tests:
  - State transitions with event logging
  - Conditional state transitions
  - Replay with state machine resources
  - Upsert behavior with state transitions
  """
  alias AshEvents.EventLogs.SystemActor
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts

  describe "basic state machine operations" do
    test "handles ash_state_machine validations" do
      actor = %SystemActor{name: "system"}

      org =
        Accounts.create_org_state_machine!(%{name: "Test State Machine"},
          actor: actor
        )

      Accounts.set_org_state_machine_inactive!(org, actor: actor)
      AshEvents.EventLogs.replay_events_state_machine!([])
    end

    test "state transitions create events" do
      actor = %SystemActor{name: "state_event_test"}

      org =
        Accounts.create_org_state_machine!(%{name: "Event Tracking Org"},
          actor: actor
        )

      # Initial state
      assert org.state == :active

      # Transition to inactive
      org = Accounts.set_org_state_machine_inactive!(org, actor: actor)
      assert org.state == :inactive

      # Check events were created
      events = Ash.read!(AshEvents.EventLogs.EventLogStateMachine)
      org_events = Enum.filter(events, &(&1.record_id == org.id))

      assert length(org_events) >= 2
    end

    test "state machine replay preserves final state" do
      actor = %SystemActor{name: "replay_state_test"}
      AshEvents.EventLogs.ClearRecordsStateMachine.clear_records!([])

      org =
        Accounts.create_org_state_machine!(%{name: "Replay State Org"},
          actor: actor
        )

      org_id = org.id

      # Transition through states
      org = Accounts.set_org_state_machine_inactive!(org, actor: actor)
      assert org.state == :inactive

      # Clear and replay
      AshEvents.EventLogs.ClearRecordsStateMachine.clear_records!([])
      :ok = AshEvents.EventLogs.replay_events_state_machine!()

      # Verify final state - use authorize?: false since OrgStateMachine has limited policies
      restored_orgs = Ash.read!(Accounts.OrgStateMachine, authorize?: false)
      restored = Enum.find(restored_orgs, &(&1.id == org_id))

      assert restored != nil
      assert restored.state == :inactive
    end
  end

  describe "conditional state transitions" do
    test "default initial state should not be overridden when conditional state transition condition is not met" do
      actor = %SystemActor{name: "test_actor"}

      # Create upload without s3_key_formatted
      # The conditional transition should NOT occur, so state should remain :skipped
      upload_without_s3_key =
        Accounts.create_upload!(
          %{
            file_name: "test_file.txt"
            # Note: s3_key_formatted is NOT provided
          },
          actor: actor
        )

      # State should be :skipped (the default initial state) because:
      # 1. The conditional transition requires attributes_present([:s3_key_formatted])
      # 2. s3_key_formatted was not provided
      # 3. Therefore the transition should not occur and state should remain default
      assert upload_without_s3_key.state == :skipped

      # Create upload WITH s3_key_formatted
      # The conditional transition SHOULD occur, so state should be :uploaded
      upload_with_s3_key =
        Accounts.create_upload!(
          %{
            file_name: "test_file_2.txt",
            s3_key_formatted: "formatted_key_123"
          },
          actor: actor
        )

      # State should be :uploaded because the condition is met
      assert upload_with_s3_key.state == :uploaded
    end

    test "upsert behavior with conditional state transitions" do
      actor = %SystemActor{name: "test_actor"}

      # First upsert - create without s3_key_formatted
      upload_1 =
        Accounts.create_upload!(
          %{
            file_name: "upsert_test.txt"
            # s3_key_formatted not provided
          },
          actor: actor
        )

      # Should be in skipped state initially
      assert upload_1.state == :skipped

      # Second upsert - same file_name but now with s3_key_formatted
      upload_2 =
        Accounts.create_upload!(
          %{
            file_name: "upsert_test.txt",
            s3_key_formatted: "formatted_key_456"
          },
          actor: actor
        )

      # Should be the same record (upsert)
      assert upload_2.id == upload_1.id

      # Now the state should be :uploaded because condition is met
      assert upload_2.state == :uploaded
    end

    test "multiple upserts without meeting transition condition keep default state" do
      actor = %SystemActor{name: "test_actor"}

      # First upsert without s3_key_formatted
      upload_1 =
        Accounts.create_upload!(
          %{
            file_name: "persistent_test.txt"
          },
          actor: actor
        )

      assert upload_1.state == :skipped

      # Second upsert, still without s3_key_formatted
      upload_2 =
        Accounts.create_upload!(
          %{
            file_name: "persistent_test.txt"
            # Still no s3_key_formatted
          },
          actor: actor
        )

      # Should be the same record and state should still be :skipped
      assert upload_2.id == upload_1.id
      assert upload_2.state == :skipped
    end
  end

  describe "state machine events" do
    test "events capture state transitions correctly for OrgStateMachine" do
      actor = %SystemActor{name: "event_capture_test"}

      # Create org (uses EventLogStateMachine)
      org = Accounts.create_org_state_machine!(%{name: "Event Test Org"}, actor: actor)

      assert org.state == :active

      # Check event data
      events = Ash.read!(AshEvents.EventLogs.EventLogStateMachine)
      org_event = Enum.find(events, &(&1.record_id == org.id))

      assert org_event != nil
      assert org_event.action_type == :create
    end

    test "multiple state changes create multiple events" do
      actor = %SystemActor{name: "multiple_events_test"}

      # Create org
      org = Accounts.create_org_state_machine!(%{name: "Multi Event Org"}, actor: actor)

      # Transition to inactive
      org = Accounts.set_org_state_machine_inactive!(org, actor: actor)

      # Check events
      events = Ash.read!(AshEvents.EventLogs.EventLogStateMachine)
      org_events = Enum.filter(events, &(&1.record_id == org.id))

      # Should have create event and update event (for state change)
      assert length(org_events) >= 2

      action_types = Enum.map(org_events, & &1.action_type)
      assert :create in action_types
      assert :update in action_types
    end
  end
end
