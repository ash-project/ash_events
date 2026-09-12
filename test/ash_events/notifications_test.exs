# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.NotificationsTest do
  @moduledoc """
  Events are created with `return_notifications?: true`, which hands the
  notifications to the caller instead of dispatching them. Each action wrapper
  has to pass them back to Ash, or notifiers on the event log resource never
  fire.

  Regression tests for https://github.com/ash-project/ash_events/pull/92
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts
  alias AshEvents.Accounts.Article
  alias AshEvents.EventLogs.EventLog
  alias AshEvents.EventLogs.SystemActor

  @actor %SystemActor{name: "test_runner"}

  setup do
    if Process.whereis(:notifier_test_pid), do: Process.unregister(:notifier_test_pid)
    Process.register(self(), :notifier_test_pid)
    :ok
  end

  defp create_user do
    Accounts.create_user!(
      %{
        email: "test@example.com",
        given_name: "Test",
        family_name: "User",
        hashed_password: "password"
      },
      actor: @actor
    )
  end

  defmacrop assert_event_log_notification(action) do
    quote do
      assert_receive {:notified,
                      %Ash.Notifier.Notification{
                        resource: EventLog,
                        data: %{action: unquote(action)}
                      }},
                     5000,
                     "Expected an EventLog notification for #{inspect(unquote(action))}, got none"
    end
  end

  test "create actions propagate event log notifications" do
    create_user()
    assert_event_log_notification(:create)
  end

  test "update actions propagate event log notifications" do
    user = create_user()
    Accounts.update_user!(user, %{given_name: "Updated"}, actor: @actor)
    assert_event_log_notification(:update)
  end

  # Known upstream limitation, see destroy_result/3 in DestroyActionWrapper:
  # Ash's single-record destroy pipeline cannot carry notifications out of a
  # manual destroy at all. This locks in the part that does work -- the
  # destroyed record's own notification -- so a future attempt to also emit the
  # event's notification cannot silently trade it away.
  test "single destroy still delivers the record's own notification" do
    article = Accounts.create_article!(%{title: "T", body: "b"}, actor: @actor)

    {:ok, _destroyed, notifications} =
      Ash.destroy(article,
        actor: @actor,
        return_notifications?: true,
        return_destroyed?: true
      )

    assert Enum.map(notifications, & &1.resource) == [Article]
  end

  test "soft destroy actions propagate event log notifications" do
    article = Accounts.create_article!(%{title: "T", body: "b"}, actor: @actor)
    Accounts.soft_destroy_article!(article, actor: @actor)
    assert_event_log_notification(:soft_destroy)
  end

  test "bulk create returns event log notifications alongside the resource's own" do
    result =
      [%{email: "bulk@example.com", given_name: "A", family_name: "B", hashed_password: "p"}]
      |> Ash.bulk_create!(Accounts.User, :create,
        actor: @actor,
        return_notifications?: true,
        return_records?: true
      )

    by_resource = Enum.frequencies_by(result.notifications, & &1.resource)

    assert by_resource[EventLog] == 1,
           "expected the event log notification to survive the bulk pipeline, got #{inspect(by_resource)}"
  end

  test "bulk destroy returns event log notifications alongside the resource's own" do
    article = Accounts.create_article!(%{title: "Bulk", body: "b"}, actor: @actor)

    result =
      Ash.bulk_destroy!([article], :destroy, %{},
        actor: @actor,
        return_notifications?: true,
        return_records?: true,
        strategy: :stream
      )

    by_resource = Enum.frequencies_by(result.notifications, & &1.resource)

    assert by_resource[EventLog] == 1,
           "expected the event log notification to survive the bulk pipeline, got #{inspect(by_resource)}"
  end
end
