# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EncryptionTest do
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts
  alias AshEvents.EventLogs
  alias AshEvents.EventLogs.EventLogCloaked
  alias AshEvents.TestRepo

  require Ash.Query

  @encrypted_columns [:encrypted_data, :encrypted_changed_attributes, :encrypted_metadata]
  @payload_fields [:data, :changed_attributes, :metadata]

  # Rewrites a stored event into the format written by releases before 0.8.0,
  # where each encrypted column held the Cloak ciphertext as base64 text.
  defp store_as_legacy_base64!(event) do
    for column <- @encrypted_columns do
      legacy = event |> Map.fetch!(column) |> Base.encode64()

      %{num_rows: 1} =
        TestRepo.query!("UPDATE events_cloaked SET #{column} = $2 WHERE id = $1", [
          event.id,
          legacy
        ])
    end

    :ok
  end

  defp read_events_with_payloads do
    EventLogCloaked
    |> Ash.Query.sort(id: :asc)
    |> Ash.Query.load(@payload_fields)
    |> Ash.read!()
  end

  test "cloaked event logs encrypt data and metadata" do
    Accounts.create_org_cloaked!(%{name: "Cloaked name"},
      context: %{ash_events_metadata: %{some: "metadata"}}
    )

    [event] = Ash.read!(AshEvents.EventLogs.EventLogCloaked)

    decrypted_data =
      event.encrypted_data
      |> AshEvents.Vault.decrypt!()
      |> Jason.decode!()

    decrypted_metadata =
      event.encrypted_metadata
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

  describe "ciphertext storage format" do
    test "new events store raw Cloak ciphertext, not base64" do
      Accounts.create_org_cloaked!(%{name: "Raw"},
        context: %{ash_events_metadata: %{some: "metadata"}}
      )

      [event] = Ash.read!(EventLogCloaked)

      for column <- @encrypted_columns do
        assert <<1, _::binary>> = Map.fetch!(event, column),
               "expected #{column} to start with the Cloak tag byte"
      end
    end

    test "events stored as base64 by releases before 0.8.0 still decrypt" do
      Accounts.create_org_cloaked!(%{name: "Legacy"},
        context: %{ash_events_metadata: %{some: "metadata"}}
      )

      [event] = Ash.read!(EventLogCloaked)
      store_as_legacy_base64!(event)

      [legacy] = read_events_with_payloads()

      assert legacy.data["name"] == "Legacy"
      assert legacy.metadata["some"] == "metadata"
      assert Map.has_key?(legacy.changed_attributes, "id")
    end

    test "legacy and current format events decrypt in the same read" do
      Accounts.create_org_cloaked!(%{name: "Legacy"})
      [legacy_event] = Ash.read!(EventLogCloaked)
      store_as_legacy_base64!(legacy_event)

      Accounts.create_org_cloaked!(%{name: "Current"})

      assert [legacy, current] = read_events_with_payloads()
      assert legacy.data["name"] == "Legacy"
      assert current.data["name"] == "Current"
    end

    test "replay rebuilds state from legacy format events" do
      org = Accounts.create_org_cloaked!(%{name: "Legacy"})
      Accounts.update_org_cloaked!(org, %{name: "Legacy updated"})

      for event <- Ash.read!(EventLogCloaked), do: store_as_legacy_base64!(event)

      :ok = EventLogs.replay_events_cloaked!()

      [org] = Ash.read!(Accounts.OrgCloaked)
      assert Ash.load!(org, [:name]).name == "Legacy updated"
    end
  end
end
