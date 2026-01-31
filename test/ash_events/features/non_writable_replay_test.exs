# SPDX-FileCopyrightText: 2024 Torkild G. Kjevik
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Features.NonWritableReplayTest do
  @moduledoc """
  Tests for replay with non-writable primary key and timestamp attributes.

  The Project resource has:
  - uuid_primary_key :id (writable?: false by default)
  - create_timestamp :created_at (writable?: false by default)
  - update_timestamp :updated_at (writable?: false by default)

  Actions do NOT accept these fields in their accept list. The replay system
  must use force_change_attributes via the changed_attributes mechanism to
  correctly restore these auto-generated values during replay.
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts.Project
  alias AshEvents.EventLogs

  describe "create action replay with non-writable fields" do
    test "project is created with auto-generated id and timestamps" do
      {:ok, project} =
        Project
        |> Ash.Changeset.for_create(:create, %{
          name: "Alpha Project",
          description: "First project",
          status: :active
        })
        |> Ash.create(actor: system_actor())

      # Verify fields were auto-generated
      assert is_binary(project.id)
      assert String.length(project.id) == 36  # UUID format
      assert %DateTime{} = project.created_at
      assert %DateTime{} = project.updated_at
      assert project.name == "Alpha Project"
      assert project.status == :active
    end

    test "replay recreates project with same id" do
      {:ok, project} =
        Project
        |> Ash.Changeset.for_create(:create, %{
          name: "Beta Project",
          description: "Second project"
        })
        |> Ash.create(actor: system_actor())

      original_id = project.id

      # Replay events
      :ok = EventLogs.replay_events!()

      # Verify project was recreated with same id
      projects = Ash.read!(Project)
      assert length(projects) == 1

      replayed_project = hd(projects)
      assert replayed_project.id == original_id
      assert replayed_project.name == "Beta Project"
    end

    test "replay preserves original created_at timestamp" do
      {:ok, project} =
        Project
        |> Ash.Changeset.for_create(:create, %{
          name: "Gamma Project"
        })
        |> Ash.create(actor: system_actor())

      original_created_at = project.created_at

      # Small delay to ensure time would be different if regenerated
      Process.sleep(10)

      # Replay events
      :ok = EventLogs.replay_events!()

      # Verify timestamp was preserved
      [replayed_project] = Ash.read!(Project)
      assert replayed_project.created_at == original_created_at
    end

    test "replay preserves default status when not explicitly set" do
      {:ok, project} =
        Project
        |> Ash.Changeset.for_create(:create, %{
          name: "Delta Project"
        })
        |> Ash.create(actor: system_actor())

      # Status defaults to :draft
      assert project.status == :draft

      :ok = EventLogs.replay_events!()

      [replayed_project] = Ash.read!(Project)
      assert replayed_project.status == :draft
    end
  end

  describe "update action replay with non-writable fields" do
    test "update changes specific fields while preserving id" do
      {:ok, project} =
        Project
        |> Ash.Changeset.for_create(:create, %{name: "Original Name"})
        |> Ash.create(actor: system_actor())

      original_id = project.id
      original_created_at = project.created_at

      {:ok, updated_project} =
        project
        |> Ash.Changeset.for_update(:update, %{
          name: "Updated Name",
          description: "Now with description"
        })
        |> Ash.update(actor: system_actor())

      assert updated_project.id == original_id
      assert updated_project.name == "Updated Name"

      :ok = EventLogs.replay_events!()

      [replayed_project] = Ash.read!(Project)
      assert replayed_project.id == original_id
      assert replayed_project.name == "Updated Name"
      assert replayed_project.description == "Now with description"
      assert replayed_project.created_at == original_created_at
    end

    test "update preserves updated_at from original action" do
      {:ok, project} =
        Project
        |> Ash.Changeset.for_create(:create, %{name: "Timestamp Test"})
        |> Ash.create(actor: system_actor())

      # Small delay to ensure updated_at would be different
      Process.sleep(10)

      {:ok, updated_project} =
        project
        |> Ash.Changeset.for_update(:update, %{description: "Updated"})
        |> Ash.update(actor: system_actor())

      original_updated_at = updated_project.updated_at

      # Another delay
      Process.sleep(10)

      :ok = EventLogs.replay_events!()

      [replayed_project] = Ash.read!(Project)
      assert replayed_project.updated_at == original_updated_at
    end

    test "change_status action with argument updates status" do
      {:ok, project} =
        Project
        |> Ash.Changeset.for_create(:create, %{name: "Status Test"})
        |> Ash.create(actor: system_actor())

      assert project.status == :draft

      {:ok, activated_project} =
        project
        |> Ash.Changeset.for_update(:change_status, %{new_status: :active})
        |> Ash.update(actor: system_actor())

      assert activated_project.status == :active

      :ok = EventLogs.replay_events!()

      [replayed_project] = Ash.read!(Project)
      assert replayed_project.status == :active
    end

    test "multiple updates are replayed in correct order" do
      {:ok, project} =
        Project
        |> Ash.Changeset.for_create(:create, %{name: "Multi Update"})
        |> Ash.create(actor: system_actor())

      original_id = project.id

      # First update
      {:ok, project} =
        project
        |> Ash.Changeset.for_update(:update, %{description: "First update"})
        |> Ash.update(actor: system_actor())

      # Second update
      {:ok, project} =
        project
        |> Ash.Changeset.for_update(:update, %{description: "Second update"})
        |> Ash.update(actor: system_actor())

      # Third update - change status
      {:ok, _project} =
        project
        |> Ash.Changeset.for_update(:change_status, %{new_status: :archived})
        |> Ash.update(actor: system_actor())

      :ok = EventLogs.replay_events!()

      [replayed_project] = Ash.read!(Project)
      assert replayed_project.id == original_id
      assert replayed_project.description == "Second update"
      assert replayed_project.status == :archived
    end
  end

  describe "destroy action replay with non-writable fields" do
    test "destroy removes the record during replay" do
      {:ok, project} =
        Project
        |> Ash.Changeset.for_create(:create, %{name: "To Be Destroyed"})
        |> Ash.create(actor: system_actor())

      :ok =
        project
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.destroy(actor: system_actor())

      # Verify destroyed
      assert Ash.read!(Project) == []

      # Replay - should recreate then destroy
      :ok = EventLogs.replay_events!()

      assert Ash.read!(Project) == []
    end

    test "create then destroy then create new is replayed correctly" do
      # Create first project
      {:ok, project1} =
        Project
        |> Ash.Changeset.for_create(:create, %{name: "First Project"})
        |> Ash.create(actor: system_actor())

      first_id = project1.id

      # Destroy it
      :ok =
        project1
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.destroy(actor: system_actor())

      # Create second project with same name (allowed now that first is gone)
      {:ok, project2} =
        Project
        |> Ash.Changeset.for_create(:create, %{name: "First Project"})
        |> Ash.create(actor: system_actor())

      second_id = project2.id
      assert first_id != second_id

      :ok = EventLogs.replay_events!()

      # Only second project should exist
      projects = Ash.read!(Project)
      assert length(projects) == 1
      assert hd(projects).id == second_id
    end
  end

  describe "upsert action replay with non-writable fields" do
    test "upsert creates new project with correct id" do
      {:ok, project} =
        Project
        |> Ash.Changeset.for_create(:create_or_update, %{
          name: "Upsert New",
          description: "Created via upsert",
          status: :active
        })
        |> Ash.create(actor: system_actor())

      original_id = project.id

      :ok = EventLogs.replay_events!()

      [replayed_project] = Ash.read!(Project)
      assert replayed_project.id == original_id
      assert replayed_project.name == "Upsert New"
      assert replayed_project.status == :active
    end

    test "upsert updates existing project with upsert_fields" do
      # Create initial project
      {:ok, project1} =
        Project
        |> Ash.Changeset.for_create(:create_or_update, %{
          name: "Upsert Existing",
          status: :draft
        })
        |> Ash.create(actor: system_actor())

      # Upsert with same name (updates existing)
      {:ok, project2} =
        Project
        |> Ash.Changeset.for_create(:create_or_update, %{
          name: "Upsert Existing",
          description: "Now with description",
          status: :active
        })
        |> Ash.create(actor: system_actor())

      # Should be same project (upsert)
      assert project2.id == project1.id
      assert project2.status == :active
      assert project2.description == "Now with description"

      :ok = EventLogs.replay_events!()

      [replayed_project] = Ash.read!(Project)
      assert replayed_project.id == project1.id
      assert replayed_project.name == "Upsert Existing"
      # upsert_fields includes :description and :status
      assert replayed_project.description == "Now with description"
      assert replayed_project.status == :active
    end

    test "multiple upserts on same project preserve final state" do
      # First upsert - creates
      {:ok, project} =
        Project
        |> Ash.Changeset.for_create(:create_or_update, %{
          name: "Multi Upsert",
          status: :draft
        })
        |> Ash.create(actor: system_actor())

      original_id = project.id

      # Second upsert - updates
      {:ok, _} =
        Project
        |> Ash.Changeset.for_create(:create_or_update, %{
          name: "Multi Upsert",
          status: :active
        })
        |> Ash.create(actor: system_actor())

      # Third upsert - updates again
      {:ok, _} =
        Project
        |> Ash.Changeset.for_create(:create_or_update, %{
          name: "Multi Upsert",
          description: "Final description",
          status: :archived
        })
        |> Ash.create(actor: system_actor())

      :ok = EventLogs.replay_events!()

      [replayed_project] = Ash.read!(Project)
      assert replayed_project.id == original_id
      assert replayed_project.description == "Final description"
      assert replayed_project.status == :archived
    end
  end

  describe "mixed action types with non-writable fields" do
    test "create, update, upsert sequence is replayed correctly" do
      # Regular create
      {:ok, project1} =
        Project
        |> Ash.Changeset.for_create(:create, %{name: "Project One"})
        |> Ash.create(actor: system_actor())

      # Upsert create (new project)
      {:ok, project2} =
        Project
        |> Ash.Changeset.for_create(:create_or_update, %{
          name: "Project Two",
          status: :active
        })
        |> Ash.create(actor: system_actor())

      # Update first project
      {:ok, _} =
        project1
        |> Ash.Changeset.for_update(:update, %{description: "Updated"})
        |> Ash.update(actor: system_actor())

      # Upsert update (existing project)
      {:ok, _} =
        Project
        |> Ash.Changeset.for_create(:create_or_update, %{
          name: "Project Two",
          status: :archived
        })
        |> Ash.create(actor: system_actor())

      :ok = EventLogs.replay_events!()

      projects = Ash.read!(Project) |> Enum.sort_by(& &1.name)
      assert length(projects) == 2

      [p1, p2] = projects
      assert p1.id == project1.id
      assert p1.name == "Project One"
      assert p1.description == "Updated"

      assert p2.id == project2.id
      assert p2.name == "Project Two"
      assert p2.status == :archived
    end

    test "full lifecycle: create, update, change_status, destroy" do
      {:ok, project} =
        Project
        |> Ash.Changeset.for_create(:create, %{name: "Lifecycle Test"})
        |> Ash.create(actor: system_actor())

      {:ok, project} =
        project
        |> Ash.Changeset.for_update(:update, %{description: "Added description"})
        |> Ash.update(actor: system_actor())

      {:ok, project} =
        project
        |> Ash.Changeset.for_update(:change_status, %{new_status: :active})
        |> Ash.update(actor: system_actor())

      {:ok, project} =
        project
        |> Ash.Changeset.for_update(:change_status, %{new_status: :archived})
        |> Ash.update(actor: system_actor())

      :ok =
        project
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.destroy(actor: system_actor())

      :ok = EventLogs.replay_events!()

      # Project should not exist after replay
      assert Ash.read!(Project) == []
    end
  end

  describe "timestamp consistency" do
    test "created_at is never modified by updates" do
      {:ok, project} =
        Project
        |> Ash.Changeset.for_create(:create, %{name: "Immutable Created"})
        |> Ash.create(actor: system_actor())

      original_created_at = project.created_at

      # Multiple updates
      {:ok, project} =
        project
        |> Ash.Changeset.for_update(:update, %{description: "Update 1"})
        |> Ash.update(actor: system_actor())

      {:ok, project} =
        project
        |> Ash.Changeset.for_update(:update, %{description: "Update 2"})
        |> Ash.update(actor: system_actor())

      # created_at should still match original
      assert project.created_at == original_created_at

      :ok = EventLogs.replay_events!()

      [replayed_project] = Ash.read!(Project)
      assert replayed_project.created_at == original_created_at
    end

    test "updated_at changes with each update and is preserved in replay" do
      {:ok, project} =
        Project
        |> Ash.Changeset.for_create(:create, %{name: "Track Updates"})
        |> Ash.create(actor: system_actor())

      initial_updated_at = project.updated_at

      Process.sleep(10)

      {:ok, project} =
        project
        |> Ash.Changeset.for_update(:update, %{description: "First"})
        |> Ash.update(actor: system_actor())

      first_update_at = project.updated_at
      assert DateTime.compare(first_update_at, initial_updated_at) == :gt

      Process.sleep(10)

      {:ok, project} =
        project
        |> Ash.Changeset.for_update(:update, %{description: "Second"})
        |> Ash.update(actor: system_actor())

      final_updated_at = project.updated_at
      assert DateTime.compare(final_updated_at, first_update_at) == :gt

      :ok = EventLogs.replay_events!()

      [replayed_project] = Ash.read!(Project)
      assert replayed_project.updated_at == final_updated_at
    end
  end

  defp system_actor do
    %AshEvents.EventLogs.SystemActor{name: "test"}
  end
end
