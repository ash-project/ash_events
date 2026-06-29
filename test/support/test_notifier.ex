# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.TestNotifier do
  @moduledoc """
  A simple notifier that sends messages to a registered process for testing purposes.
  """
  use Ash.Notifier

  def notify(notification) do
    if pid = Process.whereis(:notifier_test_pid) do
      send(pid, {:notified, notification})
    end
  end
end
