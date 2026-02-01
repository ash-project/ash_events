# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Accounts.User.Senders.SendPasswordResetEmail do
  @moduledoc """
  Mock sender for password reset emails in tests.
  """

  use AshAuthentication.Sender
  require Logger

  @impl AshAuthentication.Sender
  def send(_user, _token, _opts) do
    :ok
  end
end
