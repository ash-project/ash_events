defmodule AshEvents.NotificationsTest do
  use AshEvents.RepoCase, async: false
  alias AshEvents.Accounts
  alias AshEvents.EventLogs.EventLog

  test "notifications are not dropped when an event log record is created" do
    if Process.whereis(:notifier_test_pid), do: Process.unregister(:notifier_test_pid)
    Process.register(self(), :notifier_test_pid)

    Accounts.create_user!(
      %{
        email: "test@example.com",
        given_name: "Test",
        family_name: "User",
        hashed_password: "password"
      },
      actor: %AshEvents.EventLogs.SystemActor{name: "test_runner"}
    )

    assert_receive {:notified, %Ash.Notifier.Notification{resource: EventLog}},
                   5000,
                   "Expected to receive a notification from the EventLog resource, but none was received!"
  end
end
