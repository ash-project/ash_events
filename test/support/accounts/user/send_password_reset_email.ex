defmodule AshEvents.Accounts.User.Senders.SendPasswordResetEmail do
  @moduledoc """
  Sends a password reset email
  """

  use AshAuthentication.Sender

  @impl true
  def send(_user, token, _) do
    IO.puts("""
    Click this link to reset your password:

    /password-reset/#{token}
    """)
  end
end
