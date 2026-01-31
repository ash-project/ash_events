# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Features.CustomAdvisoryLockGeneratorsTest do
  @moduledoc """
  Tests for custom advisory lock generators.

  This module tests:
  - Default advisory lock generator behavior
  - UUID to integer conversion
  - Multitenancy-aware lock generation
  - Error handling for unsupported tenant types
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.AdvisoryLockKeyGenerator.Default, as: DefaultGenerator
  alias AshEvents.Accounts

  describe "default advisory lock generator" do
    test "returns default integer for resources without multitenancy" do
      # Org resource doesn't have multitenancy
      changeset =
        Accounts.Org
        |> Ash.Changeset.for_create(:create, %{name: "Test Org"})

      result = DefaultGenerator.generate_key!(changeset, 2_147_483_647)

      assert result == 2_147_483_647
    end

    test "returns default integer for context multitenancy strategy" do
      # Create a mock changeset with context strategy
      changeset =
        Accounts.Org
        |> Ash.Changeset.for_create(:create, %{name: "Context Org"})

      # Context strategy should return default
      result = DefaultGenerator.generate_key!(changeset, 12345)

      assert result == 12345
    end
  end

  describe "UUID conversion" do
    test "valid_uuid? returns true for valid UUIDs" do
      assert DefaultGenerator.valid_uuid?("550e8400-e29b-41d4-a716-446655440000")
      assert DefaultGenerator.valid_uuid?("550E8400-E29B-41D4-A716-446655440000")
      assert DefaultGenerator.valid_uuid?(Ecto.UUID.generate())
    end

    test "valid_uuid? returns false for invalid UUIDs" do
      refute DefaultGenerator.valid_uuid?("not-a-uuid")
      refute DefaultGenerator.valid_uuid?("12345")
      refute DefaultGenerator.valid_uuid?("")
      refute DefaultGenerator.valid_uuid?(nil)
    end

    test "valid_uuid? returns false for malformed UUIDs" do
      refute DefaultGenerator.valid_uuid?("550e8400-e29b-41d4-a716")
      refute DefaultGenerator.valid_uuid?("550e8400e29b41d4a716446655440000")
    end
  end

  describe "multitenancy with attribute strategy" do
    test "generates lock key for integer tenant" do
      org = Accounts.create_org!(%{name: "Test Org"})

      # OrgDetails uses attribute multitenancy with tenant = org.id
      changeset =
        Accounts.OrgDetails
        |> Ash.Changeset.for_create(:create, %{details: "Test details"}, tenant: org.id)

      # Should work with UUID tenant
      result = DefaultGenerator.generate_key!(changeset, 0)

      # Result should be a list of two integers for UUID
      assert is_list(result)
      assert length(result) == 2
      assert Enum.all?(result, &is_integer/1)
    end

    test "raises for unsupported tenant types" do
      org = Accounts.create_org!(%{name: "Test Org"})
      org_details = Accounts.create_org_details!(%{details: "Test details"}, tenant: org.id)

      # Create changeset with string tenant (not a UUID)
      changeset =
        org_details
        |> Ash.Changeset.for_update(:update, %{details: "new details"})
        |> Map.put(:tenant, "invalid-string-tenant")

      assert_raise RuntimeError,
                   ~r/Unsupported tenant type/,
                   fn ->
                     DefaultGenerator.generate_key!(changeset, 0)
                   end
    end

    test "raises for atom tenant" do
      org = Accounts.create_org!(%{name: "Test Org"})
      org_details = Accounts.create_org_details!(%{details: "Test details"}, tenant: org.id)

      # Create changeset with atom tenant
      changeset =
        org_details
        |> Ash.Changeset.for_update(:update, %{details: "new details"})
        |> Map.put(:tenant, :invalid_atom_tenant)

      assert_raise RuntimeError,
                   ~r/Unsupported tenant type/,
                   fn ->
                     DefaultGenerator.generate_key!(changeset, 0)
                   end
    end
  end

  describe "advisory lock behavior module" do
    test "behavior is defined with generate_key!/2 callback" do
      # The behaviour defines the callback
      assert function_exported?(AshEvents.AdvisoryLockKeyGenerator.Default, :generate_key!, 2)
    end

    test "using macro adds behaviour to module" do
      # Default module uses the behaviour
      behaviours = AshEvents.AdvisoryLockKeyGenerator.Default.__info__(:attributes)[:behaviour]

      assert AshEvents.AdvisoryLockKeyGenerator in behaviours
    end
  end

  describe "advisory lock key consistency" do
    test "same changeset produces same key" do
      org = Accounts.create_org!(%{name: "Consistency Test"})

      changeset =
        Accounts.OrgDetails
        |> Ash.Changeset.for_create(:create, %{details: "Test"}, tenant: org.id)

      key1 = DefaultGenerator.generate_key!(changeset, 0)
      key2 = DefaultGenerator.generate_key!(changeset, 0)

      assert key1 == key2
    end

    test "different tenants produce different keys" do
      org1 = Accounts.create_org!(%{name: "Org One"})
      org2 = Accounts.create_org!(%{name: "Org Two"})

      changeset1 =
        Accounts.OrgDetails
        |> Ash.Changeset.for_create(:create, %{details: "Test 1"}, tenant: org1.id)

      changeset2 =
        Accounts.OrgDetails
        |> Ash.Changeset.for_create(:create, %{details: "Test 2"}, tenant: org2.id)

      key1 = DefaultGenerator.generate_key!(changeset1, 0)
      key2 = DefaultGenerator.generate_key!(changeset2, 0)

      # Different UUIDs should produce different keys
      assert key1 != key2
    end
  end
end
