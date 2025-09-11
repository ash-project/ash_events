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
