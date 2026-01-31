# SPDX-FileCopyrightText: 2024 Torkild G. Kjevik
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Features.ReroutedUpsertReplayTest do
  @moduledoc """
  Tests for rerouted upsert action replay.

  When events are rerouted to a different action during replay, and that action
  uses upsert? true, replay handles it specially:
  - If record exists (by event.record_id): update only the fields in upsert_fields
  - If record doesn't exist: create normally with merged data

  This is necessary because PostgreSQL's ON CONFLICT doesn't work reliably when:
  - The id is passed as input alongside ON CONFLICT on a different column
  - The action runs within nested transactions (replay context)
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts.{Org, Upload, User, UserRole}
  alias AshEvents.EventLogs

  describe "Org rerouted upsert replay" do
    test "new org is created with correct id during replay" do
      # Create org via upsert action (no existing org with this name)
      {:ok, org} =
        Org
        |> Ash.Changeset.for_create(:create_or_update, %{
          name: "Acme Corp",
          active: true
        })
        |> Ash.create(actor: system_actor())

      original_id = org.id
      original_name = org.name

      # Replay events
      :ok = EventLogs.replay_events!()

      # Verify org was recreated with same id
      orgs = Ash.read!(Org)
      assert length(orgs) == 1

      replayed_org = hd(orgs)
      assert replayed_org.id == original_id
      assert replayed_org.name == original_name
      assert replayed_org.active == true
    end

    test "existing org is updated with upsert_fields during replay" do
      # First create an org
      {:ok, org1} =
        Org
        |> Ash.Changeset.for_create(:create, %{name: "Initial Corp"})
        |> Ash.create(actor: system_actor())

      # Then upsert with same name (will update existing)
      {:ok, org2} =
        Org
        |> Ash.Changeset.for_create(:create_or_update, %{
          name: "Initial Corp",
          active: false
        })
        |> Ash.create(actor: system_actor())

      # Should be same org (upsert updated it)
      assert org2.id == org1.id
      assert org2.active == false

      # Replay events
      :ok = EventLogs.replay_events!()

      # Verify org state after replay
      orgs = Ash.read!(Org)
      assert length(orgs) == 1

      replayed_org = hd(orgs)
      assert replayed_org.id == org1.id
      assert replayed_org.name == "Initial Corp"
      # The upsert_fields includes :active, so it should be updated
      assert replayed_org.active == false
    end

    test "multiple upserts on same org are replayed correctly" do
      # Create org
      {:ok, org} =
        Org
        |> Ash.Changeset.for_create(:create_or_update, %{
          name: "Evolving Corp",
          active: true
        })
        |> Ash.create(actor: system_actor())

      # Upsert to deactivate
      {:ok, _} =
        Org
        |> Ash.Changeset.for_create(:create_or_update, %{
          name: "Evolving Corp",
          active: false
        })
        |> Ash.create(actor: system_actor())

      # Upsert to reactivate
      {:ok, _} =
        Org
        |> Ash.Changeset.for_create(:create_or_update, %{
          name: "Evolving Corp",
          active: true
        })
        |> Ash.create(actor: system_actor())

      # Replay events
      :ok = EventLogs.replay_events!()

      # Verify final state
      orgs = Ash.read!(Org)
      assert length(orgs) == 1

      replayed_org = hd(orgs)
      assert replayed_org.id == org.id
      assert replayed_org.name == "Evolving Corp"
      assert replayed_org.active == true
    end
  end

  describe "Upload rerouted upsert replay with :replace_all" do
    test "new upload is created with correct id during replay" do
      {:ok, upload} =
        Upload
        |> Ash.Changeset.for_create(:create, %{
          file_name: "test_file.pdf",
          s3_key_formatted: "uploads/test_file.pdf"
        })
        |> Ash.create(actor: system_actor())

      original_id = upload.id

      # Replay events
      :ok = EventLogs.replay_events!()

      # Verify upload was recreated with same id
      uploads = Ash.read!(Upload, actor: system_actor())
      assert length(uploads) == 1

      replayed_upload = hd(uploads)
      assert replayed_upload.id == original_id
      assert replayed_upload.file_name == "test_file.pdf"
      assert replayed_upload.s3_key_formatted == "uploads/test_file.pdf"
    end

    test "existing upload is updated with :replace_all during replay" do
      # Create upload
      {:ok, upload1} =
        Upload
        |> Ash.Changeset.for_create(:create, %{
          file_name: "document.pdf"
        })
        |> Ash.create(actor: system_actor())

      # Upsert same file_name with s3_key
      {:ok, upload2} =
        Upload
        |> Ash.Changeset.for_create(:create, %{
          file_name: "document.pdf",
          s3_key_formatted: "uploads/document.pdf"
        })
        |> Ash.create(actor: system_actor())

      # Should be same upload (upsert)
      assert upload2.id == upload1.id
      assert upload2.s3_key_formatted == "uploads/document.pdf"

      # Replay events
      :ok = EventLogs.replay_events!()

      # Verify upload state after replay
      uploads = Ash.read!(Upload, actor: system_actor())
      assert length(uploads) == 1

      replayed_upload = hd(uploads)
      assert replayed_upload.id == upload1.id
      assert replayed_upload.file_name == "document.pdf"
      # With :replace_all, all fields should be updated
      assert replayed_upload.s3_key_formatted == "uploads/document.pdf"
    end
  end

  describe "UserRole rerouted upsert replay with relationship identity" do
    setup do
      # Create a user first (include given_name/family_name for RoutedUser replay)
      {:ok, user} =
        User
        |> Ash.Changeset.for_create(:create, %{
          email: "role_test@example.com",
          given_name: "Role",
          family_name: "Tester",
          hashed_password: "hashed"
        })
        |> Ash.create(actor: system_actor())

      %{user: user}
    end

    test "new role is created with correct id during replay", %{user: user} do
      {:ok, role} =
        UserRole
        |> Ash.Changeset.for_create(:create_or_update, %{
          name: "admin",
          user_id: user.id
        })
        |> Ash.create(actor: system_actor())

      original_id = role.id

      # Replay events
      :ok = EventLogs.replay_events!()

      # Verify role was recreated
      roles = Ash.read!(UserRole)
      # One role for the replayed user
      assert length(roles) >= 1

      replayed_role = Enum.find(roles, &(&1.user_id == user.id && &1.name == "admin"))
      assert replayed_role != nil
      assert replayed_role.id == original_id
    end

    test "existing role is updated with upsert_fields during replay", %{user: user} do
      # Create initial role
      {:ok, role1} =
        UserRole
        |> Ash.Changeset.for_create(:create_or_update, %{
          name: "user",
          user_id: user.id
        })
        |> Ash.create(actor: system_actor())

      # Upsert to change role name (same user_id, different name)
      {:ok, role2} =
        UserRole
        |> Ash.Changeset.for_create(:create_or_update, %{
          name: "admin",
          user_id: user.id
        })
        |> Ash.create(actor: system_actor())

      # Should be same role (upsert on user_id)
      assert role2.id == role1.id
      assert role2.name == "admin"

      # Replay events
      :ok = EventLogs.replay_events!()

      # Verify role state after replay
      roles = Ash.read!(UserRole)

      replayed_role = Enum.find(roles, &(&1.user_id == user.id))
      assert replayed_role != nil
      assert replayed_role.id == role1.id
      # The upsert_fields includes :name, so it should be updated
      assert replayed_role.name == "admin"
    end

    test "multiple role changes for same user are replayed correctly", %{user: user} do
      # Create role
      {:ok, role} =
        UserRole
        |> Ash.Changeset.for_create(:create_or_update, %{
          name: "viewer",
          user_id: user.id
        })
        |> Ash.create(actor: system_actor())

      # Change to editor
      {:ok, _} =
        UserRole
        |> Ash.Changeset.for_create(:create_or_update, %{
          name: "editor",
          user_id: user.id
        })
        |> Ash.create(actor: system_actor())

      # Change to admin
      {:ok, _} =
        UserRole
        |> Ash.Changeset.for_create(:create_or_update, %{
          name: "admin",
          user_id: user.id
        })
        |> Ash.create(actor: system_actor())

      # Replay events
      :ok = EventLogs.replay_events!()

      # Verify final state
      roles = Ash.read!(UserRole)

      replayed_role = Enum.find(roles, &(&1.user_id == user.id))
      assert replayed_role != nil
      assert replayed_role.id == role.id
      assert replayed_role.name == "admin"
    end
  end

  describe "edge cases" do
    test "upsert with nil upsert_fields defaults to accept list" do
      # The Org.create_or_update_replay action has upsert_fields: [:name, :active]
      # This test verifies the fields are properly updated

      {:ok, org} =
        Org
        |> Ash.Changeset.for_create(:create_or_update, %{
          name: "Test Org",
          active: true
        })
        |> Ash.create(actor: system_actor())

      {:ok, _} =
        Org
        |> Ash.Changeset.for_create(:create_or_update, %{
          name: "Test Org",
          active: false
        })
        |> Ash.create(actor: system_actor())

      :ok = EventLogs.replay_events!()

      orgs = Ash.read!(Org)
      replayed_org = Enum.find(orgs, &(&1.id == org.id))

      # Both :name and :active are in upsert_fields, so active should be false
      assert replayed_org.active == false
    end

    test "replay handles mixed create and upsert events" do
      # Create org via regular create action
      {:ok, org1} =
        Org
        |> Ash.Changeset.for_create(:create, %{name: "Regular Org"})
        |> Ash.create(actor: system_actor())

      # Create another org via upsert
      {:ok, org2} =
        Org
        |> Ash.Changeset.for_create(:create_or_update, %{
          name: "Upsert Org",
          active: false
        })
        |> Ash.create(actor: system_actor())

      # Replay events
      :ok = EventLogs.replay_events!()

      # Both orgs should exist
      orgs = Ash.read!(Org)
      assert length(orgs) == 2

      replayed_org1 = Enum.find(orgs, &(&1.id == org1.id))
      replayed_org2 = Enum.find(orgs, &(&1.id == org2.id))

      assert replayed_org1.name == "Regular Org"
      assert replayed_org2.name == "Upsert Org"
      assert replayed_org2.active == false
    end
  end

  defp system_actor do
    %AshEvents.EventLogs.SystemActor{name: "test"}
  end
end
