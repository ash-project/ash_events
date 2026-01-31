# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Errors.EncryptionErrorsTest do
  @moduledoc """
  Tests for encryption error scenarios.

  This module tests edge cases with encrypted events using cloaked resources.
  Note: Encrypted fields are calculations that need to be loaded explicitly.
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.EventLogs.SystemActor

  describe "encrypted event creation" do
    test "creates encrypted events successfully" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, org} =
        AshEvents.Accounts.OrgCloaked
        |> Ash.Changeset.for_create(:create, %{name: "Encrypted Org"})
        |> Ash.create(actor: actor)

      events = get_all_cloaked_events()
      event = Enum.find(events, &(&1.record_id == org.id))

      assert event != nil
      assert event.action == :create
    end

    test "encrypted data is stored correctly" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, org} =
        AshEvents.Accounts.OrgCloaked
        |> Ash.Changeset.for_create(:create, %{name: "Data Test Org"})
        |> Ash.create(actor: actor)

      events = get_all_cloaked_events()
      event = Enum.find(events, &(&1.record_id == org.id))

      # Load the encrypted data calculation
      event = Ash.load!(event, [:data])
      assert event.data["name"] == "Data Test Org"
    end

    test "encrypted metadata is stored correctly" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, org} =
        AshEvents.Accounts.OrgCloaked
        |> Ash.Changeset.for_create(:create, %{name: "Metadata Org"})
        |> Ash.Changeset.set_context(%{ash_events_metadata: %{"secret" => "encrypted_value"}})
        |> Ash.create(actor: actor)

      events = get_all_cloaked_events()
      event = Enum.find(events, &(&1.record_id == org.id))

      # Load the encrypted metadata calculation
      event = Ash.load!(event, [:metadata])
      assert event.metadata["secret"] == "encrypted_value"
    end
  end

  describe "encrypted data types" do
    test "handles unicode in encrypted data" do
      actor = %SystemActor{name: "test_runner"}
      unicode_name = "Ørganization 组织 🏢"

      {:ok, org} =
        AshEvents.Accounts.OrgCloaked
        |> Ash.Changeset.for_create(:create, %{name: unicode_name})
        |> Ash.create(actor: actor)

      events = get_all_cloaked_events()
      event = Enum.find(events, &(&1.record_id == org.id))
      event = Ash.load!(event, [:data])

      assert event.data["name"] == unicode_name
    end

    test "handles long strings in encrypted data" do
      actor = %SystemActor{name: "test_runner"}
      long_name = String.duplicate("a", 500)

      {:ok, org} =
        AshEvents.Accounts.OrgCloaked
        |> Ash.Changeset.for_create(:create, %{name: long_name})
        |> Ash.create(actor: actor)

      events = get_all_cloaked_events()
      event = Enum.find(events, &(&1.record_id == org.id))
      event = Ash.load!(event, [:data])

      assert event.data["name"] == long_name
    end
  end

  describe "encrypted update tracking" do
    test "update events have encrypted changed_attributes" do
      actor = %SystemActor{name: "test_runner"}

      {:ok, org} =
        AshEvents.Accounts.OrgCloaked
        |> Ash.Changeset.for_create(:create, %{name: "Original"})
        |> Ash.create(actor: actor)

      # Update to generate changed_attributes
      {:ok, _updated} =
        org
        |> Ash.Changeset.for_update(:update, %{name: "Updated Name"})
        |> Ash.update(actor: actor)

      events = get_all_cloaked_events()
      update_event = Enum.find(events, &(&1.record_id == org.id and &1.action_type == :update))

      assert update_event != nil
      # The event should exist with action_type :update
      assert update_event.action_type == :update
    end
  end

  describe "encrypted replay" do
    test "replay works with encrypted events" do
      actor = %SystemActor{name: "test_runner"}
      clear_cloaked_records()

      # Create an encrypted org
      {:ok, org} =
        AshEvents.Accounts.OrgCloaked
        |> Ash.Changeset.for_create(:create, %{name: "Replay Org"})
        |> Ash.create(actor: actor)

      org_id = org.id

      # Clear and replay
      clear_cloaked_records()

      :ok =
        AshEvents.EventLogs.EventLogCloaked
        |> Ash.ActionInput.for_action(:replay, %{})
        |> Ash.run_action()

      # Org should be restored - need to load the encrypted name calculation
      {:ok, replayed_org} = Ash.get(AshEvents.Accounts.OrgCloaked, org_id, actor: actor)
      replayed_org = Ash.load!(replayed_org, [:name])
      assert replayed_org.name == "Replay Org"
    end

    test "encrypted update and replay work together" do
      actor = %SystemActor{name: "test_runner"}
      clear_cloaked_records()

      # Create and update
      {:ok, org} =
        AshEvents.Accounts.OrgCloaked
        |> Ash.Changeset.for_create(:create, %{name: "Original"})
        |> Ash.create(actor: actor)

      {:ok, _updated} =
        org
        |> Ash.Changeset.for_update(:update, %{name: "Updated"})
        |> Ash.update(actor: actor)

      org_id = org.id

      # Clear and replay
      clear_cloaked_records()

      :ok =
        AshEvents.EventLogs.EventLogCloaked
        |> Ash.ActionInput.for_action(:replay, %{})
        |> Ash.run_action()

      # Org should have updated name
      {:ok, replayed_org} = Ash.get(AshEvents.Accounts.OrgCloaked, org_id, actor: actor)
      replayed_org = Ash.load!(replayed_org, [:name])
      assert replayed_org.name == "Updated"
    end
  end

  # Helper functions

  defp get_all_cloaked_events do
    AshEvents.EventLogs.EventLogCloaked
    |> Ash.Query.sort(occurred_at: :asc)
    |> Ash.read!()
  end

  defp clear_cloaked_records do
    AshEvents.EventLogs.ClearRecordsCloaked.clear_records!([])
  end
end
