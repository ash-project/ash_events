defmodule AshEvents.Test.Accounts.EventHandler do
  alias AshEvents.Test.Accounts
  use AshEvents.EventHandler

  def process_event(%{name: "accounts_user_created", version: "1." <> _} = event, opts) do
    Accounts.create_user(event.data |> Map.put(:id, event.entity_id), opts)
    |> case do
      {:ok, _user} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def process_event(%{name: "accounts_user_updated", version: "1." <> _} = event, opts) do
    Accounts.update_user(event.entity_id, event.data, opts)
    |> case do
      {:ok, _user} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def process_event(%{name: "accounts_user_destroyed", version: "1." <> _} = event, opts) do
    Accounts.destroy_user(event.entity_id, opts)
  end
end
