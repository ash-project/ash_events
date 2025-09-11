defmodule AshEvents.Accounts.User.Senders.SendMagicLinkEmail do
  @moduledoc """
  Mock sender for magic link emails in tests.
  """

  use AshAuthentication.Sender
  require Logger

  @impl AshAuthentication.Sender
  def send(_user, _token, _opts) do
    :ok
  end
end
