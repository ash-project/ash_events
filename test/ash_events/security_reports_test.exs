# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.SecurityReportsTest do
  @moduledoc """
  Regression tests for externally reported security findings. Each `describe`
  block covers one report.
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts
  alias AshEvents.Accounts.Article
  alias AshEvents.Accounts.User
  alias AshEvents.EventLogs.EventLog
  alias AshEvents.EventLogs.EventLogCloaked
  alias AshEvents.EventLogs.SystemActor

  require Ash.Query

  @actor %SystemActor{name: "test_runner"}

  defp create_upsert_user(attrs \\ %{}) do
    Accounts.create_user_upsert!(
      Map.merge(
        %{
          email: "security@example.com",
          given_name: "Security",
          family_name: "Tester",
          hashed_password: "hashed_password_123"
        },
        attrs
      ),
      actor: @actor
    )
  end

  defp event_count do
    EventLog |> Ash.read!() |> length()
  end

  defp destroy_event_count(resource, action) do
    EventLog
    |> Ash.Query.filter(resource == ^resource and action == ^action)
    |> Ash.read!()
    |> length()
  end

  describe "report 2873: event payload columns are sensitive" do
    test "plain event log marks data, changed_attributes and metadata as sensitive" do
      for name <- [:data, :changed_attributes, :metadata] do
        assert %{sensitive?: true} = Ash.Resource.Info.attribute(EventLog, name),
               "expected #{name} to be marked sensitive"
      end
    end

    test "cloaked event log exposes the decrypted payload as sensitive fields" do
      for name <- [:data, :changed_attributes, :metadata] do
        assert %{sensitive?: true} = Ash.Resource.Info.field(EventLogCloaked, name),
               "expected #{name} to be marked sensitive"
      end
    end

    test "inspecting an event redacts the stored payload" do
      create_upsert_user(%{email: "redact-me@example.com"})

      [event] =
        EventLog
        |> Ash.Query.filter(resource == ^User)
        |> Ash.read!()

      inspected = inspect(event)

      assert event.data["email"] == "redact-me@example.com"
      # Ecto omits redacted fields from the inspect output entirely
      refute inspected =~ "redact-me@example.com"
      refute inspected =~ "data:"
      refute inspected =~ "changed_attributes:"
    end
  end

  describe "report 2874: destroy failures are propagated" do
    test "destroying a stale record returns an error and does not record a second destroy event" do
      article =
        Accounts.create_article!(%{title: "Stale", body: "Will be deleted twice."}, actor: @actor)

      Accounts.destroy_article!(article, actor: @actor)

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               Accounts.destroy_article(article, actor: @actor)

      assert Enum.any?(errors, &match?(%Ash.Error.Changes.StaleRecord{}, &1))
      assert destroy_event_count(Article, :destroy) == 1
    end

    test "soft destroying a stale record returns an error and does not record an event" do
      article =
        Accounts.create_article!(%{title: "Stale", body: "Gone before soft delete."},
          actor: @actor
        )

      Accounts.destroy_article!(article, actor: @actor)

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               Accounts.soft_destroy_article(article, actor: @actor)

      assert Enum.any?(errors, &match?(%Ash.Error.Changes.StaleRecord{}, &1))
      assert destroy_event_count(Article, :soft_destroy) == 0
    end

    test "bulk destroying a stale record reports the error and does not record a second event" do
      article =
        Accounts.create_article!(%{title: "Stale", body: "Bulk deleted twice."}, actor: @actor)

      Accounts.destroy_article!(article, actor: @actor)

      result =
        Ash.bulk_destroy([article], :destroy, %{},
          strategy: :stream,
          return_errors?: true,
          actor: @actor
        )

      assert result.status == :error
      assert result.error_count == 1
      assert Enum.any?(result.errors, &match?(%Ash.Error.Changes.StaleRecord{}, &1))
      assert destroy_event_count(Article, :destroy) == 1
    end

    test "bulk soft destroying a stale record reports the error and does not record an event" do
      article =
        Accounts.create_article!(%{title: "Stale", body: "Bulk soft deleted."}, actor: @actor)

      Accounts.destroy_article!(article, actor: @actor)

      result =
        Ash.bulk_destroy([article], :soft_destroy, %{},
          strategy: :stream,
          return_errors?: true,
          actor: @actor
        )

      assert result.status == :error
      assert result.error_count == 1
      assert Enum.any?(result.errors, &match?(%Ash.Error.Changes.StaleRecord{}, &1))
      assert destroy_event_count(Article, :soft_destroy) == 0
    end
  end

  describe "report 2879: generated replay update action is not callable directly" do
    test "the generated action exists and is documented as replay-only" do
      action = Ash.Resource.Info.action(User, :ash_events_replay_create_upsert_update)

      assert action.type == :update
      assert action.public? == false
      assert action.description =~ "Not callable outside of event replay"
    end

    test "calling the generated action outside replay fails and writes no event" do
      user = create_upsert_user()
      events_before = event_count()

      result =
        user
        |> Ash.Changeset.for_update(
          :ash_events_replay_create_upsert_update,
          %{given_name: "Escalated"},
          actor: @actor
        )
        |> Ash.update()

      assert {:error, %Ash.Error.Invalid{errors: errors}} = result
      assert Enum.any?(errors, &(Exception.message(&1) =~ "cannot be called directly"))

      reloaded = Ash.get!(User, user.id, actor: @actor)
      assert reloaded.given_name == "Security"
      assert event_count() == events_before
    end

    for strategy <- [:atomic, :stream] do
      test "calling the generated action via bulk_update with strategy #{strategy} fails and writes no event" do
        user = create_upsert_user()
        events_before = event_count()

        result =
          User
          |> Ash.Query.filter(id == ^user.id)
          |> Ash.bulk_update(
            :ash_events_replay_create_upsert_update,
            %{given_name: "Escalated"},
            strategy: unquote(strategy),
            return_errors?: true,
            actor: @actor
          )

        assert result.status == :error

        assert Enum.any?(
                 result.errors,
                 &(Exception.message(&1) =~ "cannot be called directly")
               )

        reloaded = Ash.get!(User, user.id, actor: @actor)
        assert reloaded.given_name == "Security"
        assert event_count() == events_before
      end
    end

    test "the generated action still runs when invoked with the replay marker" do
      user = create_upsert_user()

      updated =
        user
        |> Ash.Changeset.for_update(
          :ash_events_replay_create_upsert_update,
          %{given_name: "Replayed"},
          actor: @actor,
          context: %{ash_events_replay?: true}
        )
        |> Ash.update!()

      assert updated.given_name == "Replayed"
    end
  end
end
