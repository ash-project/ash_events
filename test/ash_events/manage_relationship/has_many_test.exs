# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.ManageRelationship.HasManyTest do
  @moduledoc """
  Tests for manage_relationship on has_many relationships with AshEvents.

  Uses User (has_many :comments) managing Comment creation.
  The FK (user_id) is on the child resource (Comment).
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts
  alias AshEvents.Accounts.{Comment, User}
  alias AshEvents.EventLogs
  alias AshEvents.EventLogs.{EventLog, SystemActor}

  require Ash.Query

  @actor %SystemActor{name: "test"}

  describe "has_many + :create" do
    test "creates parent with multiple children, separate events for each" do
      user =
        User
        |> Ash.Changeset.for_create(
          :create_with_comments,
          %{
            email: "hm-create@example.com",
            given_name: "Jane",
            family_name: "Doe",
            hashed_password: "hash",
            comments: [%{body: "First comment"}, %{body: "Second comment"}]
          },
          actor: @actor
        )
        |> Ash.create!(actor: @actor)
        |> Ash.load!(:comments, actor: @actor)

      assert length(user.comments) == 2
      bodies = Enum.map(user.comments, & &1.body) |> Enum.sort()
      assert bodies == ["First comment", "Second comment"]

      events =
        EventLog
        |> Ash.read!(actor: @actor)
        |> Enum.filter(&(&1.action_type == :create))

      user_event = Enum.find(events, &(&1.resource == User and &1.record_id == user.id))
      comment_events = Enum.filter(events, &(&1.resource == Comment))

      assert user_event != nil
      assert length(comment_events) == 2
    end

    test "replay does not duplicate children" do
      user =
        User
        |> Ash.Changeset.for_create(
          :create_with_comments,
          %{
            email: "hm-replay@example.com",
            given_name: "Jane",
            family_name: "Doe",
            hashed_password: "hash",
            comments: [%{body: "Comment A"}, %{body: "Comment B"}]
          },
          actor: @actor
        )
        |> Ash.create!(actor: @actor)
        |> Ash.load!(:comments, actor: @actor)

      original_user_id = user.id
      original_comment_ids = Enum.map(user.comments, & &1.id) |> Enum.sort()

      :ok = EventLogs.replay_events!()

      user = Accounts.get_user_by_id!(original_user_id, load: [:comments], actor: @actor)
      assert length(user.comments) == 2

      replayed_ids = Enum.map(user.comments, & &1.id) |> Enum.sort()
      assert replayed_ids == original_comment_ids
    end
  end

  describe "has_many + :direct_control (update)" do
    test "adding and removing children via update, replay works" do
      # Create user with one comment
      user =
        User
        |> Ash.Changeset.for_create(
          :create_with_comments,
          %{
            email: "hm-dc@example.com",
            given_name: "Jane",
            family_name: "Doe",
            hashed_password: "hash",
            comments: [%{body: "Initial comment"}]
          },
          actor: @actor
        )
        |> Ash.create!(actor: @actor)
        |> Ash.load!(:comments, actor: @actor)

      [initial_comment] = user.comments

      # Update: keep existing comment (updated), add a new one
      user =
        user
        |> Ash.Changeset.for_update(
          :update_with_comments_direct_control,
          %{
            comments: [
              %{id: initial_comment.id, body: "Updated comment"},
              %{body: "New comment"}
            ]
          },
          actor: @actor
        )
        |> Ash.update!(actor: @actor)
        |> Ash.load!(:comments, actor: @actor)

      assert length(user.comments) == 2
      bodies = Enum.map(user.comments, & &1.body) |> Enum.sort()
      assert bodies == ["New comment", "Updated comment"]

      original_user_id = user.id

      :ok = EventLogs.replay_events!()

      user = Accounts.get_user_by_id!(original_user_id, load: [:comments], actor: @actor)
      assert length(user.comments) == 2
      replayed_bodies = Enum.map(user.comments, & &1.body) |> Enum.sort()
      assert replayed_bodies == ["New comment", "Updated comment"]
    end
  end
end
