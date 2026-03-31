# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.BulkActionsTest do
  alias AshEvents.EventLogs.SystemActor
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts
  alias AshEvents.Accounts.User
  alias AshEvents.EventLogs.EventLog

  require Ash.Query

  test "bulk actions works as expected" do
    result =
      1..2
      |> Enum.map(fn _i ->
        %{
          email: Faker.Internet.email(),
          given_name: Faker.Person.first_name(),
          family_name: Faker.Person.last_name(),
          hashed_password: "hashed_password_123"
        }
      end)
      |> Ash.bulk_create!(User, :create,
        actor: %AshEvents.EventLogs.SystemActor{name: "system"},
        return_notifications?: true,
        return_errors?: true,
        return_records?: true
      )

    assert result.error_count == 0
    assert Enum.count(result.records) == 2
    assert Enum.count(result.notifications) == 2

    events =
      EventLog
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    assert Enum.count(events) == 4

    update_result =
      result.records
      |> Ash.bulk_update!(
        :update,
        %{
          given_name: "Updated",
          family_name: "Name"
        },
        actor: %AshEvents.EventLogs.SystemActor{name: "system"},
        return_notifications?: true,
        return_errors?: true,
        return_records?: true,
        strategy: :stream
      )

    assert update_result.error_count == 0
    assert Enum.count(update_result.records) == 2
    assert Enum.count(update_result.notifications) == 2

    events =
      EventLog
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    assert Enum.count(events) == 6

    users = Accounts.User |> Ash.read!(actor: %SystemActor{name: "system"})

    Enum.each(users, fn user ->
      assert user.given_name == "Updated"
      assert user.family_name == "Name"
    end)

    user_roles = Accounts.UserRole |> Ash.read!()

    destroy_roles_result =
      user_roles
      |> Ash.bulk_destroy!(:destroy, %{},
        return_errors?: true,
        return_notifications?: true,
        return_records?: true,
        strategy: :stream
      )

    assert destroy_roles_result.error_count == 0
    assert Enum.count(destroy_roles_result.records) == 2
    assert Enum.count(destroy_roles_result.notifications) == 2

    [] = Accounts.UserRole |> Ash.read!()

    events =
      EventLog
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    assert Enum.count(events) == 8

    destroy_users_result =
      update_result.records
      |> Ash.bulk_destroy!(:destroy, %{},
        return_errors?: true,
        return_notifications?: true,
        return_records?: true,
        strategy: :stream,
        actor: %SystemActor{name: "system"}
      )

    assert destroy_users_result.error_count == 0
    assert Enum.count(destroy_users_result.records) == 2
    assert Enum.count(destroy_users_result.notifications) == 2

    [] = Accounts.User |> Ash.read!(actor: %SystemActor{name: "system"})

    events =
      EventLog
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    assert Enum.count(events) == 10
  end

  test "bulk_create works atomically with ignored action" do
    alias AshEvents.Accounts.Org

    result =
      Ash.bulk_create!(
        [%{name: "Org 1"}, %{name: "Org 2"}, %{name: "Org 3"}],
        Org,
        :create_ignored,
        return_errors?: true,
        return_records?: true,
        actor: %SystemActor{name: "system"}
      )

    assert result.error_count == 0
    assert Enum.count(result.records) == 3

    events =
      EventLog
      |> Ash.Query.filter(resource == ^Org and action == :create_ignored)
      |> Ash.read!()

    assert events == []
  end

  test "bulk_update works atomically with ignored action" do
    alias AshEvents.Accounts.Org

    orgs =
      1..3
      |> Enum.map(fn i ->
        Org
        |> Ash.Changeset.for_create(:create, %{name: "Org #{i}"})
        |> Ash.create!(actor: %SystemActor{name: "system"})
      end)

    result =
      orgs
      |> Ash.bulk_update!(:update_ignored, %{name: "Updated"},
        return_errors?: true,
        return_records?: true,
        actor: %SystemActor{name: "system"}
      )

    assert result.error_count == 0
    assert Enum.count(result.records) == 3
    assert Enum.all?(result.records, &(&1.name == "Updated"))

    events =
      EventLog
      |> Ash.Query.filter(resource == ^Org and action == :update_ignored)
      |> Ash.read!()

    assert events == []
  end

  test "bulk_destroy works atomically with ignored action" do
    alias AshEvents.Accounts.Org

    orgs =
      1..3
      |> Enum.map(fn i ->
        Org
        |> Ash.Changeset.for_create(:create, %{name: "Org #{i}"})
        |> Ash.create!(actor: %SystemActor{name: "system"})
      end)

    result =
      orgs
      |> Ash.bulk_destroy!(:destroy_ignored, %{},
        return_errors?: true,
        return_records?: true,
        actor: %SystemActor{name: "system"}
      )

    assert result.error_count == 0
    assert Enum.count(result.records) == 3
    assert [] == Org |> Ash.read!()

    events =
      EventLog
      |> Ash.Query.filter(resource == ^Org and action == :destroy_ignored)
      |> Ash.read!()

    assert events == []
  end

  test "bulk_create without return_notifications? should not generate missed notification warnings" do
    result =
      Ash.bulk_create!(
        [
          %{name: "Acme Corp"},
          %{name: "Globex Inc"}
        ],
        Accounts.Org,
        :create,
        actor: %SystemActor{name: "system"},
        return_errors?: true,
        return_records?: true
      )

    assert result.error_count == 0
    assert Enum.count(result.records) == 2

    events =
      EventLog
      |> Ash.Query.filter(resource == ^Accounts.Org)
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    assert Enum.count(events) == 2
  end

  test "bulk_destroy with soft delete works correctly" do
    alias AshEvents.Accounts.Article

    # Create articles
    articles =
      1..3
      |> Enum.map(fn i ->
        Accounts.create_article!(
          %{title: "Article #{i}", body: "Body #{i}"},
          actor: %SystemActor{name: "system"}
        )
      end)

    # Bulk soft-delete the articles
    result =
      articles
      |> Ash.bulk_destroy!(:soft_destroy, %{},
        resource: Article,
        return_errors?: true,
        return_notifications?: true,
        return_records?: true,
        strategy: :stream,
        actor: %SystemActor{name: "system"}
      )

    assert result.error_count == 0
    assert Enum.count(result.records) == 3

    # Verify articles are soft-deleted (deleted_at is set)
    all_articles = Article |> Ash.read!()

    Enum.each(all_articles, fn article ->
      assert article.deleted_at != nil
    end)

    # Verify soft-delete events were created
    events =
      EventLog
      |> Ash.Query.filter(resource == ^Article and action == :soft_destroy)
      |> Ash.read!()

    assert Enum.count(events) == 3
  end

  test "bulk_destroy with soft delete and nested bulk operation works correctly" do
    alias AshEvents.Accounts.Article
    alias AshEvents.Accounts.ArticleTag
    alias AshEvents.Accounts.Tag

    # Create a tag
    tag =
      Tag
      |> Ash.Changeset.for_create(:create, %{name: "test-tag"})
      |> Ash.create!(actor: %SystemActor{name: "system"})

    # Create articles with tags
    articles =
      1..3
      |> Enum.map(fn i ->
        Article
        |> Ash.Changeset.for_create(:create_with_tags, %{
          title: "Article #{i}",
          body: "Body #{i}",
          tags: [%{id: tag.id}]
        })
        |> Ash.create!(actor: %SystemActor{name: "system"})
      end)

    # Verify article_tags were created
    article_tags = ArticleTag |> Ash.read!()
    assert Enum.count(article_tags) == 3

    # Bulk soft-delete the articles with nested bulk operation to delete tags
    # This tests the fix for original_params being nil in nested bulk operations
    result =
      articles
      |> Ash.bulk_destroy!(:soft_destroy_with_tags, %{},
        resource: Article,
        return_errors?: true,
        return_notifications?: true,
        return_records?: true,
        strategy: :stream,
        actor: %SystemActor{name: "system"}
      )

    assert result.error_count == 0
    assert Enum.count(result.records) == 3

    # Verify articles are soft-deleted (deleted_at is set)
    all_articles = Article |> Ash.read!()

    Enum.each(all_articles, fn article ->
      assert article.deleted_at != nil
    end)

    # Verify article_tags were hard deleted by the nested bulk operation
    article_tags_after = ArticleTag |> Ash.read!()
    assert article_tags_after == []

    # Verify soft-delete events were created for articles
    events =
      EventLog
      |> Ash.Query.filter(resource == ^Article and action == :soft_destroy_with_tags)
      |> Ash.read!()

    assert Enum.count(events) == 3
  end

  test "single create without return_notifications? should work fine" do
    org =
      Accounts.Org
      |> Ash.Changeset.for_create(:create, %{name: "Wayne Enterprises"})
      |> Ash.create!(actor: %SystemActor{name: "system"})

    assert org.id

    # Verify events were created
    events =
      EventLog
      |> Ash.Query.filter(resource == ^Accounts.Org)
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!(actor: %SystemActor{name: "system"})

    assert Enum.count(events) == 1
  end
end
