# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Events.Verifiers.VerifyEventLogTest do
  @moduledoc """
  Tests for the VerifyEventLog verifier.

  This verifier ensures that event_log configuration is valid:
  - The event_log module is an Ash resource
  - The event_log resource uses the AshEvents.EventLog extension
  """
  use ExUnit.Case, async: true

  alias AshEvents.Events.Verifiers.VerifyEventLog

  describe "verify/1 with valid configurations" do
    test "accepts User resource with valid event_log reference" do
      assert Code.ensure_loaded?(AshEvents.Accounts.User)

      # Get the event_log configuration
      event_log = AshEvents.Events.Info.events_event_log!(AshEvents.Accounts.User)

      assert event_log == AshEvents.EventLogs.EventLog
    end

    test "event_log is an Ash resource" do
      event_log = AshEvents.Events.Info.events_event_log!(AshEvents.Accounts.User)

      assert Ash.Resource.Info.resource?(event_log)
    end

    test "event_log uses AshEvents.EventLog extension" do
      event_log = AshEvents.Events.Info.events_event_log!(AshEvents.Accounts.User)

      extensions = Spark.extensions(event_log)
      assert AshEvents.EventLog in extensions
    end
  end

  describe "verifier module validation" do
    test "verifier module is loaded and has verify/1 function" do
      assert Code.ensure_loaded?(VerifyEventLog)
      assert function_exported?(VerifyEventLog, :verify, 1)
    end
  end

  describe "resource validation logic" do
    test "Ash.Resource.Info.resource? validates resources" do
      # Valid Ash resource
      assert Ash.Resource.Info.resource?(AshEvents.EventLogs.EventLog)
      assert Ash.Resource.Info.resource?(AshEvents.Accounts.User)

      # Invalid resource
      refute Ash.Resource.Info.resource?(String)
      refute Ash.Resource.Info.resource?(NonExistentModule)
    end

    test "Spark.extensions retrieves module extensions" do
      extensions = Spark.extensions(AshEvents.EventLogs.EventLog)

      assert is_list(extensions)
      assert AshEvents.EventLog in extensions
    end
  end

  describe "different resources reference correct event logs" do
    test "User references EventLog" do
      event_log = AshEvents.Events.Info.events_event_log!(AshEvents.Accounts.User)
      assert event_log == AshEvents.EventLogs.EventLog
    end

    test "UserUuidV7 references EventLogUuidV7" do
      event_log = AshEvents.Events.Info.events_event_log!(AshEvents.Accounts.UserUuidV7)
      assert event_log == AshEvents.EventLogs.EventLogUuidV7
    end

    test "OrgCloaked references EventLogCloaked" do
      event_log = AshEvents.Events.Info.events_event_log!(AshEvents.Accounts.OrgCloaked)
      assert event_log == AshEvents.EventLogs.EventLogCloaked
    end
  end

  describe "error message validation" do
    test "error messages are descriptive" do
      source = File.read!("lib/events/verifiers/verify_event_log.ex")

      # Verify error messages mention specific requirements
      assert source =~ "event_log"
      assert source =~ "is not an Ash resource"
      assert source =~ "AshEvents.EventLog extension"
    end
  end
end
