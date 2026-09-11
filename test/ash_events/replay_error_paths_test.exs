# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.ReplayErrorPathsTest do
  @moduledoc """
  Covers the failure branches of event creation and replay: data layer errors
  on create, validations that fail at replay time, replay aborting on the
  first failing event, and events whose record no longer exists.
  """
  use AshEvents.RepoCase, async: false

  import ExUnit.CaptureLog

  alias AshEvents.Accounts
  alias AshEvents.Accounts.Article
  alias AshEvents.Accounts.Org
  alias AshEvents.Accounts.User
  alias AshEvents.EventLogs
  alias AshEvents.EventLogs.EventLog
  alias AshEvents.EventLogs.SystemActor
  alias AshEvents.TestRepo

  require Ash.Query

  @actor %SystemActor{name: "test_runner"}

  defp events_for(resource, action) do
    EventLog
    |> Ash.Query.filter(resource == ^resource and action == ^action)
    |> Ash.Query.sort(id: :asc)
    |> Ash.read!()
  end

  defp delete_event!(%{id: id}) do
    {1, nil} =
      TestRepo.query!("DELETE FROM events WHERE id = $1", [id]) |> then(&{&1.num_rows, nil})
  end

  defp set_event_data!(%{id: id}, key, value) do
    %{num_rows: 1} =
      TestRepo.query!(
        "UPDATE events SET data = jsonb_set(data, $2, $3::jsonb) WHERE id = $1",
        [id, [key], value]
      )
  end

  describe "create failing at the data layer" do
    test "unique constraint violation returns an error and writes no event" do
      attrs = %{
        email: "dupe@example.com",
        given_name: "First",
        family_name: "User",
        hashed_password: "hashed_password_123"
      }

      Accounts.create_user!(attrs, actor: @actor)
      assert length(events_for(User, :create)) == 1

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               Accounts.create_user(%{attrs | given_name: "Second"}, actor: @actor)

      assert Enum.any?(errors, &match?(%Ash.Error.Changes.InvalidAttribute{field: :email}, &1))
      assert length(events_for(User, :create)) == 1
    end
  end

  describe "validation failing during replay" do
    test "a validation with a custom message fails replay with that message" do
      article = Accounts.create_article!(%{title: "Archived", body: "Body"}, actor: @actor)
      article = Accounts.archive_article!(article, actor: @actor)
      Accounts.unarchive_article!(article, actor: @actor)

      # Without the archive event, archived_at is nil when unarchive replays.
      [archive_event] = events_for(Article, :archive)
      delete_event!(archive_event)

      error = assert_raise Ash.Error.Invalid, fn -> EventLogs.replay_events() end
      assert Exception.message(error) =~ "Article is not archived"
    end

    test "a validation without a custom message fails replay with the default message" do
      Accounts.create_org!(%{name: "Valid name"}, actor: @actor)

      [create_event] = events_for(Org, :create)
      set_event_data!(create_event, "name", "x")

      error = assert_raise Ash.Error.Invalid, fn -> EventLogs.replay_events() end
      assert Exception.message(error) =~ "must have length of between 2 and 100"
    end
  end

  describe "replay aborting on the first failing event" do
    test "raises, keeps earlier events applied and does not apply later events" do
      before =
        Accounts.create_article!(%{title: "Before the failure", body: "Body"}, actor: @actor)

      Accounts.create_org!(%{name: "Broken"}, actor: @actor)
      Accounts.create_article!(%{title: "After the failure", body: "Body"}, actor: @actor)

      [org_event] = events_for(Org, :create)
      set_event_data!(org_event, "name", "x")

      assert_raise Ash.Error.Invalid, fn -> EventLogs.replay_events() end

      # The replay action does not run in a transaction: records are cleared and
      # events applied up to the failure, then the error propagates.
      assert [%Article{id: before_id}] = Ash.read!(Article)
      assert before_id == before.id
      assert [] = Ash.read!(Org)
    end
  end

  describe "events whose record does not exist at replay time" do
    test "update and destroy events for a missing record log a warning and replay continues" do
      article = Accounts.create_article!(%{title: "Orphan", body: "Body"}, actor: @actor)
      article = Accounts.update_article!(article, %{title: "Orphan updated"}, actor: @actor)
      Accounts.destroy_article!(article, actor: @actor)

      survivor = Accounts.create_article!(%{title: "Survivor", body: "Body"}, actor: @actor)

      [create_event] = events_for(Article, :create) |> Enum.filter(&(&1.record_id == article.id))
      delete_event!(create_event)

      log =
        capture_log(fn ->
          assert :ok = EventLogs.replay_events()
        end)

      assert log =~ "not found when processing update event"
      assert log =~ "not found when processing destroy event"

      assert [%Article{id: survivor_id}] = Ash.read!(Article)
      assert survivor_id == survivor.id
    end
  end
end
