defmodule AshEvents.EncryptionTest do
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts
  alias AshEvents.EventLogs

  test "cloaked event logs encrypt data and metadata" do
    Accounts.create_org_cloaked!(%{name: "Cloaked name"},
      context: %{ash_events_metadata: %{some: "metadata"}}
    )

    [event] = Ash.read!(AshEvents.EventLogs.EventLogCloaked)

    decrypted_data =
      event.encrypted_data
      |> Base.decode64!()
      |> AshEvents.Vault.decrypt!()
      |> Jason.decode!()

    decrypted_metadata =
      event.encrypted_metadata
      |> Base.decode64!()
      |> AshEvents.Vault.decrypt!()
      |> Jason.decode!()

    assert decrypted_data["name"] == "Cloaked name"
    assert decrypted_metadata["some"] == "metadata"
  end

  test "cloaked event logs calcs and replay work" do
    org = Accounts.create_org_cloaked!(%{name: "Cloaked name"})

    Accounts.update_org_cloaked!(org, %{name: "Updated name"},
      context: %{ash_events_metadata: %{some: "metadata"}}
    )

    [create_event, update_event] = Ash.read!(AshEvents.EventLogs.EventLogCloaked)

    update_event =
      update_event
      |> Ash.load!([:data, :metadata])

    assert update_event.data["name"] == "Updated name"
    assert update_event.metadata["some"] == "metadata"

    :ok = EventLogs.replay_events_cloaked!(%{last_event_id: create_event.id})

    [org] = Ash.read!(Accounts.OrgCloaked)
    org = Ash.load!(org, [:name])
    assert org.name == "Cloaked name"

    :ok = EventLogs.replay_events_cloaked!()

    [org] = Ash.read!(Accounts.OrgCloaked)
    org = Ash.load!(org, [:name])
    assert org.name == "Updated name"
  end
end
