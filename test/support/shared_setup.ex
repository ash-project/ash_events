# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Test.SharedSetup do
  @moduledoc """
  Shared setup functions for AshEvents tests.

  This module provides common setup scenarios that can be imported
  into test modules using ExUnit's setup callbacks.

  ## Usage

      defmodule MyTest do
        use AshEvents.RepoCase, async: false
        import AshEvents.Test.SharedSetup

        setup :create_user_with_events

        test "my test", %{user: user, events: events} do
          # ...
        end
      end
  """

  alias AshEvents.Accounts
  alias AshEvents.EventLogs.EventLog
  alias AshEvents.EventLogs.SystemActor

  require Ash.Query

  @doc """
  Setup callback that creates a user and returns it in context.

  Returns `%{user: user}` in the test context.
  """
  def create_user_setup(_context) do
    user =
      Accounts.create_user!(
        %{
          email: "user@example.com",
          given_name: "John",
          family_name: "Doe",
          hashed_password: "hashed_password_123"
        },
        actor: %SystemActor{name: "test_setup"}
      )

    %{user: user}
  end

  @doc """
  Setup callback that creates a user and captures all events.

  Returns `%{user: user, events: [event1, event2, ...]}` in the test context.
  """
  def create_user_with_events(_context) do
    user =
      Accounts.create_user!(
        %{
          email: "user@example.com",
          given_name: "John",
          family_name: "Doe",
          hashed_password: "hashed_password_123"
        },
        actor: %SystemActor{name: "test_setup"}
      )

    events =
      EventLog
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    %{user: user, events: events}
  end

  @doc """
  Setup callback that creates a user with update history.

  Returns `%{user: user, events: events}` where the user has been
  updated multiple times.
  """
  def create_user_with_updates(_context) do
    system_actor = %SystemActor{name: "test_setup"}

    user =
      Accounts.create_user!(
        %{
          email: "user@example.com",
          given_name: "John",
          family_name: "Doe",
          hashed_password: "hashed_password_123"
        },
        actor: system_actor
      )

    user =
      Accounts.update_user!(
        user,
        %{given_name: "Jane"},
        actor: user
      )

    user =
      Accounts.update_user!(
        user,
        %{family_name: "Smith", role: "admin"},
        actor: system_actor
      )

    events =
      EventLog
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    %{user: Ash.load!(user, [:user_role]), events: events}
  end

  @doc """
  Setup callback for multitenancy tests.

  Creates a tenant context for testing tenant-specific functionality.
  """
  def setup_tenant(_context) do
    # Multitenancy setup - customize based on your tenant configuration
    tenant = "test_tenant_#{System.unique_integer([:positive])}"
    %{tenant: tenant}
  end

  @doc """
  Setup callback that clears all events before the test.

  Useful for tests that need a clean event log state.
  """
  def clear_events(_context) do
    EventLog
    |> Ash.read!()
    |> Enum.each(&Ash.destroy!/1)

    %{}
  end

  @doc """
  Setup callback that creates multiple users for bulk operation tests.

  Returns `%{users: [user1, user2, user3]}` in the test context.
  """
  def create_multiple_users(_context) do
    system_actor = %SystemActor{name: "test_setup"}

    users =
      Enum.map(1..3, fn i ->
        Accounts.create_user!(
          %{
            email: "user#{i}@example.com",
            given_name: "User",
            family_name: "#{i}",
            hashed_password: "hashed_password_123"
          },
          actor: system_actor
        )
      end)

    %{users: users}
  end
end
