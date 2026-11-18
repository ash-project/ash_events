# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.StoreSensitiveChangedAttributesTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias AshEvents.Accounts
  alias AshEvents.Accounts.Credential
  alias AshEvents.EventLogs
  alias AshEvents.EventLogs.{EventLog, EventLogNoSensitiveChanges, SystemActor}

  require Ash.Query

  @actor %SystemActor{name: "test_runner"}

  setup do
    AshEvents.TestRepo.start_link(pool: Ecto.Adapters.SQL.Sandbox)
    Ecto.Adapters.SQL.Sandbox.mode(AshEvents.TestRepo, :manual)
    Ecto.Adapters.SQL.Sandbox.checkout(AshEvents.TestRepo)

    :ok
  end

  defp events(action) do
    EventLogNoSensitiveChanges
    |> Ash.Query.filter(action == ^action)
    |> Ash.read!()
  end

  test "defaults to true" do
    assert AshEvents.EventLog.Info.event_log_store_sensitive_changed_attributes?(EventLog)

    refute AshEvents.EventLog.Info.event_log_store_sensitive_changed_attributes?(
             EventLogNoSensitiveChanges
           )
  end

  test "stores a sensitive attribute set by a change on create as nil" do
    credential = Accounts.create_credential!(%{name: "ci", api_key: "key-123"}, actor: @actor)
    assert credential.secret

    [event] = events(:create)

    assert Map.has_key?(event.changed_attributes, "secret")
    assert event.changed_attributes["secret"] == nil
    assert event.changed_attributes["id"] == credential.id
    assert event.data == %{"name" => "ci", "api_key" => nil}
    refute Jason.encode!(Map.take(event, [:data, :changed_attributes])) =~ credential.secret
  end

  test "stores a sensitive attribute set by a change on update as nil" do
    credential = Accounts.create_credential!(%{name: "ci"}, actor: @actor)
    rotated = Accounts.rotate_credential_secret!(credential, actor: @actor)
    assert rotated.secret != credential.secret

    [event] = events(:rotate_secret)

    assert event.changed_attributes["secret"] == nil
    refute Jason.encode!(Map.take(event, [:data, :changed_attributes])) =~ rotated.secret
  end

  test "replay sets the attribute to nil and keeps the rest" do
    credential = Accounts.create_credential!(%{name: "ci"}, actor: @actor)

    :ok = EventLogs.replay_events_no_sensitive_changes!()

    replayed = Ash.get!(Credential, credential.id)
    assert replayed.name == "ci"
    assert replayed.secret == nil
  end
end
