defmodule AshEvents.Accounts.User.Senders.SendNewUserConfirmationEmail do
  @moduledoc """
  Sends an email for a new user to confirm their email address.
  """

  use AshAuthentication.Sender

  @impl true
  def send(_user, _token, _), do: nil
end
