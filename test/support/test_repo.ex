defmodule AshEvents.TestRepo do
  use AshPostgres.Repo, otp_app: :ash_events

  def installed_extensions do
    ["uuid-ossp", "citext", "ash-functions"]
  end

  def on_transaction_begin(data) do
    send(self(), data)
  end

  def prefer_transaction?, do: false

  def prefer_transaction_for_atomic_updates?, do: false

  def min_pg_version do
    %Version{major: 16, minor: 0, patch: 0}
  end
end
