# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Accounts.User.Senders.SendNewUserConfirmationEmail do
  @moduledoc """
  Mock sender for new user confirmation emails in tests.
  """

  use AshAuthentication.Sender
  require Logger

  @impl AshAuthentication.Sender
  def send(_user, _token, _opts) do
    :ok
  end
end
