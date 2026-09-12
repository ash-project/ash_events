# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.AdvisoryLocksTest do
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts

  test "advisory lock default value is used for resources without multitenancy" do
    Accounts.create_org!(%{name: "Test Org"})

    {:ok,
     %Postgrex.Result{
       rows: [["ExclusiveLock", true, 2_147_483_647, 0]]
     }} =
      Ecto.Adapters.SQL.query(AshEvents.TestRepo, """
      SELECT mode, granted, objid, classid
      FROM pg_locks
      WHERE locktype = 'advisory';
      """)
  end

  test "advisory locks built tenant value is used for resources with multitenancy" do
    org = Accounts.create_org!(%{name: "Test Org"})
    Accounts.create_org_details!(%{details: "Test details 1"}, tenant: org.id)
    Accounts.create_org_details!(%{details: "Test details 2"}, tenant: org.id)
    Accounts.create_org_details!(%{details: "Test details 3"}, tenant: org.id)
    Accounts.create_org_details!(%{details: "Test details 4"}, tenant: org.id)
    org_details = Accounts.create_org_details!(%{details: "Test details 5"}, tenant: org.id)

    {:ok,
     %Postgrex.Result{
       rows: rows
     }} =
      Ecto.Adapters.SQL.query(AshEvents.TestRepo, """
      SELECT mode, granted, objid, classid
      FROM pg_locks
      WHERE locktype = 'advisory';
      """)

    changeset =
      org_details |> Ash.Changeset.for_update(:update, %{details: "new details"}, tenant: org.id)

    [hi_int, lo_int] = AshEvents.AdvisoryLockKeyGenerator.Default.generate_key!(changeset, 0)

    hi_int_unsigned = Bitwise.band(hi_int, 0xFFFFFFFF)
    lo_int_unsigned = Bitwise.band(lo_int, 0xFFFFFFFF)

    lock_row =
      Enum.find(rows, fn [mode, granted, objid, classid] ->
        objid == lo_int_unsigned and classid == hi_int_unsigned and
          mode == "ExclusiveLock" and granted
      end)

    assert Enum.count(rows) == 2
    assert lock_row != nil
  end

  test "a failed advisory lock acquisition raises with its own error instead of a 25P02" do
    # Hold the default lock key from a connection outside the sandbox so the
    # lock statement issued by create_event! cannot be granted.
    repo_config = Application.fetch_env!(:ash_events, AshEvents.TestRepo)

    {:ok, holder} =
      Postgrex.start_link(
        Keyword.take(repo_config, [:username, :password, :hostname, :port, :database])
      )

    Postgrex.query!(holder, "BEGIN", [])
    Postgrex.query!(holder, "SELECT pg_advisory_xact_lock(2147483647)", [])

    # Make the blocked lock statement fail quickly, the same way a deadlock
    # victim fails: server-side, mid-transaction, on the lock query itself.
    Ecto.Adapters.SQL.query!(TestRepo, "SET LOCAL lock_timeout = '200ms'")

    error = assert_raise(Ash.Error.Unknown, fn -> Accounts.create_org!(%{name: "Test Org"}) end)

    assert [%Ash.Error.Unknown.UnknownError{error: message}] = error.errors
    assert message =~ "55P03 (lock_not_available)"
    refute message =~ "25P02"
  end

  test "advisory lock generator raises on unsupported tenant type" do
    org = Accounts.create_org!(%{name: "Test Org"})
    org_details = Accounts.create_org_details!(%{details: "Test details"}, tenant: org.id)

    # Create changeset with string tenant (not a UUID)
    changeset_string =
      org_details
      |> Ash.Changeset.for_update(:update, %{details: "new details"})
      |> Map.put(:tenant, "invalid-string-tenant")

    assert_raise RuntimeError,
                 "Unsupported tenant type: \"invalid-string-tenant\". You must implement a custom AdvisoryLockKeyGenerator module.",
                 fn ->
                   AshEvents.AdvisoryLockKeyGenerator.Default.generate_key!(changeset_string, 0)
                 end

    # Create changeset with atom tenant
    changeset_atom =
      org_details
      |> Ash.Changeset.for_update(:update, %{details: "new details"})
      |> Map.put(:tenant, :invalid_atom_tenant)

    assert_raise RuntimeError,
                 "Unsupported tenant type: :invalid_atom_tenant. You must implement a custom AdvisoryLockKeyGenerator module.",
                 fn ->
                   AshEvents.AdvisoryLockKeyGenerator.Default.generate_key!(changeset_atom, 0)
                 end
  end
end
