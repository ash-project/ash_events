# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.ManageRelationship.ManyToManyTest do
  @moduledoc """
  Tests for manage_relationship on many_to_many relationships with AshEvents.

  Uses Article (many_to_many :tags, through: ArticleTag).
  Join records are stored in the article_tags table.
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts
  alias AshEvents.Accounts.{Article, ArticleTag}
  alias AshEvents.EventLogs
  alias AshEvents.EventLogs.{EventLog, SystemActor}

  require Ash.Query

  @actor %SystemActor{name: "test"}

  defp create_tag(name) do
    Accounts.create_tag!(%{name: name}, actor: @actor)
  end

  describe "many_to_many + :append" do
    test "creates article with existing tags, join table events created" do
      tag1 = create_tag("elixir")
      tag2 = create_tag("ash")

      article =
        Article
        |> Ash.Changeset.for_create(:create_with_tags, %{
          title: "Learning Ash",
          body: "Great framework",
          tags: [%{id: tag1.id}, %{id: tag2.id}]
        }, actor: @actor)
        |> Ash.create!(actor: @actor)
        |> Ash.load!(:tags, actor: @actor)

      assert length(article.tags) == 2
      tag_names = Enum.map(article.tags, & &1.name) |> Enum.sort()
      assert tag_names == ["ash", "elixir"]

      # Verify join table events were created
      events =
        EventLog
        |> Ash.read!(actor: @actor)
        |> Enum.filter(&(&1.resource == ArticleTag))

      assert length(events) == 2
    end

    test "replay restores article-tag associations" do
      tag1 = create_tag("phoenix")
      tag2 = create_tag("liveview")

      article =
        Article
        |> Ash.Changeset.for_create(:create_with_tags, %{
          title: "Phoenix LiveView",
          body: "Real-time web",
          tags: [%{id: tag1.id}, %{id: tag2.id}]
        }, actor: @actor)
        |> Ash.create!(actor: @actor)
        |> Ash.load!(:tags, actor: @actor)

      original_article_id = article.id

      :ok = EventLogs.replay_events!()

      articles = Ash.read!(Article, actor: @actor)
      article = Enum.find(articles, &(&1.id == original_article_id))
      assert article != nil

      article = Ash.load!(article, :tags, actor: @actor)
      tag_names = Enum.map(article.tags, & &1.name) |> Enum.sort()
      assert tag_names == ["liveview", "phoenix"]
    end
  end

  describe "many_to_many + :append_and_remove (update)" do
    test "adding and removing tags via update, replay works" do
      tag1 = create_tag("elixir-ar")
      tag2 = create_tag("ash-ar")
      tag3 = create_tag("phoenix-ar")

      # Create article with tag1 and tag2
      article =
        Article
        |> Ash.Changeset.for_create(:create_with_tags, %{
          title: "Initial Article",
          tags: [%{id: tag1.id}, %{id: tag2.id}]
        }, actor: @actor)
        |> Ash.create!(actor: @actor)
        |> Ash.load!(:tags, actor: @actor)

      assert length(article.tags) == 2

      # Update: remove tag2, add tag3
      article =
        article
        |> Ash.Changeset.for_update(:update_tags, %{
          tags: [%{id: tag1.id}, %{id: tag3.id}]
        }, actor: @actor)
        |> Ash.update!(actor: @actor)
        |> Ash.load!(:tags, actor: @actor)

      tag_names = Enum.map(article.tags, & &1.name) |> Enum.sort()
      assert tag_names == ["elixir-ar", "phoenix-ar"]

      original_article_id = article.id

      :ok = EventLogs.replay_events!()

      articles = Ash.read!(Article, actor: @actor)
      article = Enum.find(articles, &(&1.id == original_article_id))
      article = Ash.load!(article, :tags, actor: @actor)

      replayed_names = Enum.map(article.tags, & &1.name) |> Enum.sort()
      assert replayed_names == ["elixir-ar", "phoenix-ar"]
    end
  end
end
