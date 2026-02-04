# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.DestroyActionTest do
  @moduledoc """
  Tests for the DestroyActionWrapper module.

  Tests both hard deletes and soft deletes to ensure events are
  properly created and can be replayed.
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts
  alias AshEvents.Accounts.Article
  alias AshEvents.EventLogs
  alias AshEvents.EventLogs.EventLog
  alias AshEvents.EventLogs.SystemActor

  require Ash.Query

  @actor %SystemActor{name: "test_runner"}

  defp create_article(attrs \\ %{}) do
    default_attrs = %{
      title: "Test Article",
      body: "This is a test article body."
    }

    Accounts.create_article!(Map.merge(default_attrs, attrs), actor: @actor)
  end

  describe "hard delete" do
    test "creates an event when article is hard deleted" do
      article = create_article()

      Accounts.destroy_article!(article, actor: @actor)

      events =
        EventLog
        |> Ash.Query.filter(resource == ^Article and action == :destroy)
        |> Ash.read!()

      assert length(events) == 1
      [event] = events

      assert event.action == :destroy
      assert event.resource == Article
      assert event.record_id == article.id
      assert event.system_actor == "test_runner"
    end

    test "hard delete removes the record from the database" do
      article = create_article()
      article_id = article.id

      Accounts.destroy_article!(article, actor: @actor)

      result =
        Article
        |> Ash.Query.filter(id == ^article_id)
        |> Ash.read!()

      assert result == []
    end

    test "hard delete event stores the correct record_id" do
      article = create_article(%{title: "Original Title", body: "Original body"})

      Accounts.update_article!(article, %{title: "Updated Title"}, actor: @actor)

      updated_article = Ash.get!(Article, article.id)
      Accounts.destroy_article!(updated_article, actor: @actor)

      [destroy_event] =
        EventLog
        |> Ash.Query.filter(resource == ^Article and action == :destroy)
        |> Ash.read!()

      assert destroy_event.record_id == article.id
      assert destroy_event.data == %{}
    end

    test "events are created in order: create, update, destroy" do
      article = create_article()
      Accounts.update_article!(article, %{title: "Updated"}, actor: @actor)
      updated_article = Ash.get!(Article, article.id)
      Accounts.destroy_article!(updated_article, actor: @actor)

      events =
        EventLog
        |> Ash.Query.filter(resource == ^Article)
        |> Ash.Query.sort({:id, :asc})
        |> Ash.read!()

      assert length(events) == 3
      assert Enum.map(events, & &1.action) == [:create, :update, :destroy]
    end

    test "metadata is stored in hard delete events" do
      article = create_article()

      Accounts.destroy_article!(
        article,
        actor: @actor,
        context: %{ash_events_metadata: %{reason: "spam"}}
      )

      [event] =
        EventLog
        |> Ash.Query.filter(resource == ^Article and action == :destroy)
        |> Ash.read!()

      assert event.metadata == %{"reason" => "spam"}
    end
  end

  describe "soft delete" do
    test "creates an event when article is soft deleted" do
      article = create_article()

      Accounts.soft_destroy_article!(article, actor: @actor)

      events =
        EventLog
        |> Ash.Query.filter(resource == ^Article and action == :soft_destroy)
        |> Ash.read!()

      assert length(events) == 1
      [event] = events

      assert event.action == :soft_destroy
      assert event.resource == Article
      assert event.record_id == article.id
      assert event.system_actor == "test_runner"
    end

    test "soft delete sets deleted_at on the record" do
      article = create_article()
      assert article.deleted_at == nil

      Accounts.soft_destroy_article!(article, actor: @actor)

      soft_deleted_article = Ash.get!(Article, article.id)
      assert soft_deleted_article.deleted_at != nil
    end

    test "soft deleted record still exists in database" do
      article = create_article()
      article_id = article.id

      Accounts.soft_destroy_article!(article, actor: @actor)

      result =
        Article
        |> Ash.Query.filter(id == ^article_id)
        |> Ash.read!()

      assert length(result) == 1
      assert hd(result).deleted_at != nil
    end

    test "metadata is stored in soft delete events" do
      article = create_article()

      Accounts.soft_destroy_article!(
        article,
        actor: @actor,
        context: %{ash_events_metadata: %{deleted_by: "moderator"}}
      )

      [event] =
        EventLog
        |> Ash.Query.filter(resource == ^Article and action == :soft_destroy)
        |> Ash.read!()

      assert event.metadata == %{"deleted_by" => "moderator"}
    end
  end

  describe "archive (update-based soft delete pattern)" do
    test "creates an event when article is archived" do
      article = create_article()

      Accounts.archive_article!(article, actor: @actor)

      events =
        EventLog
        |> Ash.Query.filter(resource == ^Article and action == :archive)
        |> Ash.read!()

      assert length(events) == 1
      [event] = events

      assert event.action == :archive
      assert event.resource == Article
      assert event.record_id == article.id
    end

    test "archive sets archived_at on the record" do
      article = create_article()
      assert article.archived_at == nil

      Accounts.archive_article!(article, actor: @actor)

      archived_article = Ash.get!(Article, article.id)
      assert archived_article.archived_at != nil
    end

    test "unarchive clears archived_at" do
      article = create_article()
      archived = Accounts.archive_article!(article, actor: @actor)

      assert archived.archived_at != nil

      unarchived = Accounts.unarchive_article!(archived, actor: @actor)
      assert unarchived.archived_at == nil
    end

    test "unarchive creates an event" do
      article = create_article()
      archived = Accounts.archive_article!(article, actor: @actor)

      Accounts.unarchive_article!(archived, actor: @actor)

      events =
        EventLog
        |> Ash.Query.filter(resource == ^Article and action == :unarchive)
        |> Ash.read!()

      assert length(events) == 1
    end
  end

  describe "replay" do
    test "replays hard delete events correctly" do
      article = create_article(%{title: "Will be deleted"})
      article_id = article.id

      Accounts.destroy_article!(article, actor: @actor)

      [create_event] =
        EventLog
        |> Ash.Query.filter(resource == ^Article and action == :create)
        |> Ash.read!()

      :ok = EventLogs.replay_events!(%{last_event_id: create_event.id})

      [replayed_article] =
        Article
        |> Ash.Query.filter(id == ^article_id)
        |> Ash.read!()

      assert replayed_article.title == "Will be deleted"

      :ok = EventLogs.replay_events!()

      result =
        Article
        |> Ash.Query.filter(id == ^article_id)
        |> Ash.read!()

      assert result == []
    end

    test "replays soft delete events correctly" do
      article = create_article(%{title: "Will be soft deleted"})
      article_id = article.id

      Accounts.soft_destroy_article!(article, actor: @actor)

      [create_event] =
        EventLog
        |> Ash.Query.filter(resource == ^Article and action == :create)
        |> Ash.read!()

      :ok = EventLogs.replay_events!(%{last_event_id: create_event.id})

      [replayed_article] =
        Article
        |> Ash.Query.filter(id == ^article_id)
        |> Ash.read!()

      assert replayed_article.deleted_at == nil

      :ok = EventLogs.replay_events!()

      [soft_deleted_article] =
        Article
        |> Ash.Query.filter(id == ^article_id)
        |> Ash.read!()

      assert soft_deleted_article.deleted_at != nil
    end

    test "replays archive/unarchive cycle correctly" do
      article = create_article()
      article_id = article.id

      archived = Accounts.archive_article!(article, actor: @actor)
      Accounts.unarchive_article!(archived, actor: @actor)

      events =
        EventLog
        |> Ash.Query.filter(resource == ^Article)
        |> Ash.Query.sort({:id, :asc})
        |> Ash.read!()

      [create_event, archive_event, _unarchive_event] = events

      :ok = EventLogs.replay_events!(%{last_event_id: archive_event.id})

      [archived_article] =
        Article
        |> Ash.Query.filter(id == ^article_id)
        |> Ash.read!()

      assert archived_article.archived_at != nil

      :ok = EventLogs.replay_events!(%{last_event_id: create_event.id})

      [fresh_article] =
        Article
        |> Ash.Query.filter(id == ^article_id)
        |> Ash.read!()

      assert fresh_article.archived_at == nil

      :ok = EventLogs.replay_events!()

      [final_article] =
        Article
        |> Ash.Query.filter(id == ^article_id)
        |> Ash.read!()

      assert final_article.archived_at == nil
    end

    test "replays multiple articles with mixed delete types" do
      article1 = create_article(%{title: "Article 1"})
      article2 = create_article(%{title: "Article 2"})
      article3 = create_article(%{title: "Article 3"})

      Accounts.destroy_article!(article1, actor: @actor)
      Accounts.soft_destroy_article!(article2, actor: @actor)
      Accounts.archive_article!(article3, actor: @actor)

      :ok = EventLogs.replay_events!()

      assert [] ==
               Article
               |> Ash.Query.filter(id == ^article1.id)
               |> Ash.read!()

      [soft_deleted] =
        Article
        |> Ash.Query.filter(id == ^article2.id)
        |> Ash.read!()

      assert soft_deleted.deleted_at != nil

      [archived] =
        Article
        |> Ash.Query.filter(id == ^article3.id)
        |> Ash.read!()

      assert archived.archived_at != nil
    end
  end

  describe "replay skips event creation during replay" do
    test "no duplicate events created during hard delete replay" do
      article = create_article()
      Accounts.destroy_article!(article, actor: @actor)

      initial_event_count =
        EventLog
        |> Ash.Query.filter(resource == ^Article)
        |> Ash.read!()
        |> length()

      :ok = EventLogs.replay_events!()

      final_event_count =
        EventLog
        |> Ash.Query.filter(resource == ^Article)
        |> Ash.read!()
        |> length()

      assert initial_event_count == final_event_count
    end

    test "no duplicate events created during soft delete replay" do
      article = create_article()
      Accounts.soft_destroy_article!(article, actor: @actor)

      initial_event_count =
        EventLog
        |> Ash.Query.filter(resource == ^Article)
        |> Ash.read!()
        |> length()

      :ok = EventLogs.replay_events!()

      final_event_count =
        EventLog
        |> Ash.Query.filter(resource == ^Article)
        |> Ash.read!()
        |> length()

      assert initial_event_count == final_event_count
    end
  end
end
