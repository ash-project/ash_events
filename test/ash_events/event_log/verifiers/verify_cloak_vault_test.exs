# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EventLog.Verifiers.VerifyCloakVaultTest do
  @moduledoc """
  Tests for the VerifyCloakVault verifier.

  This verifier ensures that:
  - cloak_vault module exists (if specified)
  - cloak_vault module implements Cloak.Vault behaviour
  """
  use ExUnit.Case, async: true

  alias AshEvents.EventLog.Verifiers.VerifyCloakVault

  describe "verify/1 with valid cloaked configuration" do
    test "accepts EventLogCloaked with valid vault module" do
      assert Code.ensure_loaded?(AshEvents.EventLogs.EventLogCloaked)

      # Get the configured vault
      {:ok, vault} =
        AshEvents.EventLog.Info.event_log_cloak_vault(AshEvents.EventLogs.EventLogCloaked)

      assert vault == AshEvents.Vault
      assert Code.ensure_loaded?(vault)
    end

    test "vault module has encrypt!/1 function" do
      {:ok, vault} =
        AshEvents.EventLog.Info.event_log_cloak_vault(AshEvents.EventLogs.EventLogCloaked)

      assert function_exported?(vault, :encrypt!, 1)
    end

    test "vault module has decrypt!/1 function" do
      {:ok, vault} =
        AshEvents.EventLog.Info.event_log_cloak_vault(AshEvents.EventLogs.EventLogCloaked)

      assert function_exported?(vault, :decrypt!, 1)
    end

    test "cloaked? returns true for cloaked event log" do
      assert AshEvents.EventLog.Info.cloaked?(AshEvents.EventLogs.EventLogCloaked)
    end
  end

  describe "verify/1 with non-cloaked configuration" do
    test "regular EventLog has no vault configured" do
      assert Code.ensure_loaded?(AshEvents.EventLogs.EventLog)

      result = AshEvents.EventLog.Info.event_log_cloak_vault(AshEvents.EventLogs.EventLog)
      assert result == :error
    end

    test "cloaked? returns false for non-cloaked event log" do
      refute AshEvents.EventLog.Info.cloaked?(AshEvents.EventLogs.EventLog)
    end
  end

  describe "verifier module validation" do
    test "verifier module is loaded and has verify/1 function" do
      assert Code.ensure_loaded?(VerifyCloakVault)
      assert function_exported?(VerifyCloakVault, :verify, 1)
    end
  end

  describe "vault encryption/decryption" do
    test "vault can encrypt and decrypt data" do
      {:ok, vault} =
        AshEvents.EventLog.Info.event_log_cloak_vault(AshEvents.EventLogs.EventLogCloaked)

      # Test round-trip encryption
      original = "test data"
      encrypted = vault.encrypt!(original)
      decrypted = vault.decrypt!(encrypted)

      assert decrypted == original
      assert encrypted != original
    end

    test "vault encrypts maps correctly" do
      {:ok, vault} =
        AshEvents.EventLog.Info.event_log_cloak_vault(AshEvents.EventLogs.EventLogCloaked)

      original = %{"key" => "value", "nested" => %{"inner" => "data"}}
      encoded = Jason.encode!(original)
      encrypted = vault.encrypt!(encoded)
      decrypted = vault.decrypt!(encrypted)
      decoded = Jason.decode!(decrypted)

      assert decoded == original
    end
  end

  describe "error message validation" do
    test "error messages are descriptive" do
      source = File.read!("lib/event_log/verifiers/verify_cloak_vault.ex")

      # Verify error messages mention specific requirements
      assert source =~ "cloak_vault"
      assert source =~ "does not exist"
      assert source =~ "Cloak.Vault"
    end
  end
end
