# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.StoreSensitiveInputsTest do
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts
  alias AshEvents.EventLog.Info
  alias AshEvents.EventLogs
  alias AshEvents.EventLogs.EventLogCloaked
  alias AshEvents.EventLogs.EventLogCloakedNoSensitiveInputs

  defp decrypted_data(event) do
    event.encrypted_data
    |> AshEvents.Vault.decrypt!()
    |> Jason.decode!()
  end

  describe "store_sensitive_inputs? option" do
    test "defaults to true" do
      assert Info.event_log_store_sensitive_inputs?(EventLogCloaked)
      refute Info.event_log_store_sensitive_inputs?(EventLogCloakedNoSensitiveInputs)
    end
  end

  describe "cloaked event log with the default (true)" do
    test "stores sensitive arguments in data" do
      Accounts.create_org_cloaked!(%{name: "Org", access_code: "org-access-code"})

      [event] = Ash.read!(EventLogCloaked)

      assert decrypted_data(event)["access_code"] == "org-access-code"
    end
  end

  describe "cloaked event log with store_sensitive_inputs? false" do
    test "stores sensitive attributes and arguments in data as nil" do
      Accounts.create_cloaked_credential!(%{
        name: "Deploy key",
        api_token: "plaintext-api-token",
        passphrase: "plaintext-passphrase",
        note: "rotated monthly"
      })

      [event] = Ash.read!(EventLogCloakedNoSensitiveInputs)
      data = decrypted_data(event)

      assert data["name"] == "Deploy key"
      assert data["note"] == "rotated monthly"
      assert Map.has_key?(data, "api_token")
      assert Map.has_key?(data, "passphrase")
      assert data["api_token"] == nil
      assert data["passphrase"] == nil

      for column <- [:encrypted_data, :encrypted_changed_attributes, :encrypted_metadata] do
        decrypted = event |> Map.fetch!(column) |> AshEvents.Vault.decrypt!()

        refute decrypted =~ "plaintext-api-token"
        refute decrypted =~ "plaintext-passphrase"
      end
    end

    test "applies to update actions" do
      credential = Accounts.create_cloaked_credential!(%{name: "Deploy key"})

      Accounts.update_cloaked_credential!(credential, %{
        name: "Renamed",
        api_token: "rotated-api-token",
        passphrase: "rotated-passphrase"
      })

      [_create, update] =
        EventLogCloakedNoSensitiveInputs
        |> Ash.Query.sort(id: :asc)
        |> Ash.read!()

      data = decrypted_data(update)

      assert data["name"] == "Renamed"
      assert data["api_token"] == nil
      assert data["passphrase"] == nil
    end

    test "still encrypts and replays the non-sensitive inputs" do
      credential = Accounts.create_cloaked_credential!(%{name: "Deploy key"})
      Accounts.update_cloaked_credential!(credential, %{name: "Renamed"})

      :ok = EventLogs.replay_events_cloaked_no_sensitive_inputs!()

      assert [%{name: "Renamed"}] = Ash.read!(Accounts.CloakedCredential)
    end
  end
end
