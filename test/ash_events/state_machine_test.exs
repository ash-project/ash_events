# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.StateMachineTest do
  alias AshEvents.EventLogs.SystemActor
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts

  test "handles ash_state_machine validations" do
    actor = %SystemActor{name: "system"}

    org =
      Accounts.create_org_state_machine!(%{name: "Test State Machine"},
        actor: actor
      )

    Accounts.set_org_state_machine_inactive!(org, actor: actor)
    AshEvents.EventLogs.replay_events_state_machine!([])
  end

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
