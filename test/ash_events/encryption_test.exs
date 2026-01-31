# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EncryptionTest do
  @moduledoc """
  Tests for event encryption using AshCloak.

  This module tests:
  - Encrypted data storage in events
  - Encrypted metadata storage
  - Decryption via calculations
  - Replay with encrypted events
  - Multiple encryption operations
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts
  alias AshEvents.EventLogs
  alias AshEvents.EventLogs.SystemActor

  describe "encrypted data storage" do
    test "cloaked event logs encrypt data and metadata" do
      Accounts.create_org_cloaked!(%{name: "Cloaked name"},
        context: %{ash_events_metadata: %{some: "metadata"}}
      )

      [event] = Ash.read!(AshEvents.EventLogs.EventLogCloaked)

      decrypted_data =
        event.encrypted_data
        |> Base.decode64!()
        |> AshEvents.Vault.decrypt!()
        |> Jason.decode!()

      decrypted_metadata =
        event.encrypted_metadata
        |> Base.decode64!()
        |> AshEvents.Vault.decrypt!()
        |> Jason.decode!()

      assert decrypted_data["name"] == "Cloaked name"
      assert decrypted_metadata["some"] == "metadata"
    end

    test "encrypted data is not readable in raw form" do
      Accounts.create_org_cloaked!(%{name: "Secret Org"})

      [event] = Ash.read!(AshEvents.EventLogs.EventLogCloaked)

      # Raw encrypted_data should not contain the plaintext
      refute event.encrypted_data =~ "Secret Org"

      # But decrypted via calculation should work
      event = Ash.load!(event, [:data])
      assert event.data["name"] == "Secret Org"
    end

    test "multiple events have different encrypted values" do
      actor = %SystemActor{name: "encryption_test"}

      {:ok, org1} =
        AshEvents.Accounts.OrgCloaked
        |> Ash.Changeset.for_create(:create, %{name: "Org One"})
        |> Ash.create(actor: actor)

      {:ok, org2} =
        AshEvents.Accounts.OrgCloaked
        |> Ash.Changeset.for_create(:create, %{name: "Org Two"})
        |> Ash.create(actor: actor)

      events = Ash.read!(AshEvents.EventLogs.EventLogCloaked)

      event1 = Enum.find(events, &(&1.record_id == org1.id))
      event2 = Enum.find(events, &(&1.record_id == org2.id))

      # Different data should have different encrypted values
      assert event1.encrypted_data != event2.encrypted_data

      # But both should decrypt correctly
      event1 = Ash.load!(event1, [:data])
      event2 = Ash.load!(event2, [:data])

      assert event1.data["name"] == "Org One"
      assert event2.data["name"] == "Org Two"
    end
  end

  describe "encrypted metadata" do
    test "metadata is encrypted separately from data" do
      Accounts.create_org_cloaked!(%{name: "Meta Test"},
        context: %{ash_events_metadata: %{request_id: "req-123", user_agent: "test-client"}}
      )

      [event] = Ash.read!(AshEvents.EventLogs.EventLogCloaked)

      # Load both calculations
      event = Ash.load!(event, [:data, :metadata])

      assert event.data["name"] == "Meta Test"
      assert event.metadata["request_id"] == "req-123"
      assert event.metadata["user_agent"] == "test-client"
    end

    test "empty metadata is handled correctly" do
      Accounts.create_org_cloaked!(%{name: "No Meta"})

      [event] = Ash.read!(AshEvents.EventLogs.EventLogCloaked)
      event = Ash.load!(event, [:metadata])

      # Empty metadata should be an empty map
      assert event.metadata == %{}
    end

    test "complex nested metadata is preserved" do
      complex_metadata = %{
        "nested" => %{
          "level1" => %{
            "level2" => "deep value"
          }
        },
        "array" => [1, 2, 3],
        "mixed" => [%{"key" => "value"}, "string", 42]
      }

      Accounts.create_org_cloaked!(%{name: "Complex Meta"},
        context: %{ash_events_metadata: complex_metadata}
      )

      [event] = Ash.read!(AshEvents.EventLogs.EventLogCloaked)
      event = Ash.load!(event, [:metadata])

      assert event.metadata["nested"]["level1"]["level2"] == "deep value"
      assert event.metadata["array"] == [1, 2, 3]
      assert event.metadata["mixed"] == [%{"key" => "value"}, "string", 42]
    end
  end

  describe "encrypted replay" do
    test "cloaked event logs calcs and replay work" do
      org = Accounts.create_org_cloaked!(%{name: "Cloaked name"})

      Accounts.update_org_cloaked!(org, %{name: "Updated name"},
        context: %{ash_events_metadata: %{some: "metadata"}}
      )

      [create_event, update_event] = Ash.read!(AshEvents.EventLogs.EventLogCloaked)

      update_event =
        update_event
        |> Ash.load!([:data, :metadata])

      assert update_event.data["name"] == "Updated name"
      assert update_event.metadata["some"] == "metadata"

      :ok = EventLogs.replay_events_cloaked!(%{last_event_id: create_event.id})

      [org] = Ash.read!(Accounts.OrgCloaked)
      org = Ash.load!(org, [:name])
      assert org.name == "Cloaked name"

      :ok = EventLogs.replay_events_cloaked!()

      [org] = Ash.read!(Accounts.OrgCloaked)
      org = Ash.load!(org, [:name])
      assert org.name == "Updated name"
    end

    test "replay preserves encrypted data integrity" do
      actor = %SystemActor{name: "integrity_test"}
      AshEvents.EventLogs.ClearRecordsCloaked.clear_records!([])

      # Create org with data
      {:ok, org} =
        AshEvents.Accounts.OrgCloaked
        |> Ash.Changeset.for_create(:create, %{name: "Integrity Test"})
        |> Ash.create(actor: actor)

      original_id = org.id

      # Clear and replay
      AshEvents.EventLogs.ClearRecordsCloaked.clear_records!([])

      :ok = EventLogs.replay_events_cloaked!()

      # Verify data integrity
      {:ok, restored} = Ash.get(AshEvents.Accounts.OrgCloaked, original_id, actor: actor)
      restored = Ash.load!(restored, [:name])

      assert restored.name == "Integrity Test"
    end

    test "multiple update cycle with encryption" do
      actor = %SystemActor{name: "cycle_test"}
      AshEvents.EventLogs.ClearRecordsCloaked.clear_records!([])

      # Create
      {:ok, org} =
        AshEvents.Accounts.OrgCloaked
        |> Ash.Changeset.for_create(:create, %{name: "Cycle Org"})
        |> Ash.create(actor: actor)

      # Update multiple times
      {:ok, org} =
        org
        |> Ash.Changeset.for_update(:update, %{name: "Updated Once"})
        |> Ash.update(actor: actor)

      {:ok, org} =
        org
        |> Ash.Changeset.for_update(:update, %{name: "Updated Twice"})
        |> Ash.update(actor: actor)

      final_id = org.id

      # Verify events are created (create + 2 updates = 3)
      events = Ash.read!(AshEvents.EventLogs.EventLogCloaked)
      record_events = Enum.filter(events, &(&1.record_id == final_id))

      assert length(record_events) == 3

      # Verify event data via calculations
      record_events = Enum.map(record_events, &Ash.load!(&1, [:data]))

      names = Enum.map(record_events, & &1.data["name"])
      assert "Cycle Org" in names
      assert "Updated Once" in names
      assert "Updated Twice" in names

      # Clear and replay
      AshEvents.EventLogs.ClearRecordsCloaked.clear_records!([])
      :ok = EventLogs.replay_events_cloaked!()

      # Org should exist with final state
      {:ok, restored} = Ash.get(AshEvents.Accounts.OrgCloaked, final_id, actor: actor)
      restored = Ash.load!(restored, [:name])
      assert restored.name == "Updated Twice"
    end
  end

  describe "encryption edge cases" do
    test "special characters in encrypted data" do
      special_name = "Org with 'quotes' and \"double quotes\" and \\ backslash"

      Accounts.create_org_cloaked!(%{name: special_name})

      [event] = Ash.read!(AshEvents.EventLogs.EventLogCloaked)
      event = Ash.load!(event, [:data])

      assert event.data["name"] == special_name
    end

    test "unicode characters in encrypted data" do
      unicode_name = "Org with émojis 🎉 and ñ and 中文"

      Accounts.create_org_cloaked!(%{name: unicode_name})

      [event] = Ash.read!(AshEvents.EventLogs.EventLogCloaked)
      event = Ash.load!(event, [:data])

      assert event.data["name"] == unicode_name
    end
  end
end
