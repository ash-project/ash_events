# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Test.Helpers do
  @moduledoc """
  Reusable test helper functions for AshEvents test suite.

  This module provides common setup and utility functions used across
  multiple test files to reduce duplication and ensure consistent
  test patterns.

  ## Usage

      use AshEvents.RepoCase, async: false
      import AshEvents.Test.Helpers

      test "my test" do
        user = create_user()
        # ... test code
      end
  """

  alias AshEvents.Accounts
  alias AshEvents.EventLogs.EventLog
  alias AshEvents.EventLogs.SystemActor

  require Ash.Query

  @doc """
  Creates a test user with default attributes.

  ## Options

    * `:email` - The user's email (default: "user@example.com")
    * `:given_name` - The user's given name (default: "John")
    * `:family_name` - The user's family name (default: "Doe")
    * `:hashed_password` - The user's hashed password (default: "hashed_password_123")
    * `:actor` - The actor performing the action (default: SystemActor)
    * `:metadata` - Event metadata to include (default: %{})

  ## Examples

      user = create_user()
      user = create_user(email: "other@example.com")
      user = create_user(actor: existing_user, metadata: %{source: "test"})
  """
  def create_user(opts \\ []) do
    email = Keyword.get(opts, :email, "user@example.com")
    given_name = Keyword.get(opts, :given_name, "John")
    family_name = Keyword.get(opts, :family_name, "Doe")
    hashed_password = Keyword.get(opts, :hashed_password, "hashed_password_123")
    actor = Keyword.get(opts, :actor, %SystemActor{name: "test_runner"})
    metadata = Keyword.get(opts, :metadata, %{})

    context_opts =
      if map_size(metadata) > 0 do
        [context: %{ash_events_metadata: metadata}]
      else
        []
      end

    Accounts.create_user!(
      %{
        email: email,
        given_name: given_name,
        family_name: family_name,
        hashed_password: hashed_password
      },
      [actor: actor] ++ context_opts
    )
  end

  @doc """
  Creates a test user with UUIDv7 primary key.

  ## Options

  Same as `create_user/1` except `:hashed_password` is not required.
  """
  def create_user_uuidv7(opts \\ []) do
    email = Keyword.get(opts, :email, "user@example.com")
    given_name = Keyword.get(opts, :given_name, "John")
    family_name = Keyword.get(opts, :family_name, "Doe")
    actor = Keyword.get(opts, :actor, %SystemActor{name: "test_runner"})
    metadata = Keyword.get(opts, :metadata, %{})

    context_opts =
      if map_size(metadata) > 0 do
        [context: %{ash_events_metadata: metadata}]
      else
        []
      end

    Accounts.create_user_uuidv7!(
      %{
        email: email,
        given_name: given_name,
        family_name: family_name
      },
      [actor: actor] ++ context_opts
    )
  end

  @doc """
  Updates a test user with the given attributes.

  ## Options

    * `:actor` - The actor performing the action (required for audit trail)
    * `:metadata` - Event metadata to include (default: %{})
  """
  def update_user(user, attrs, opts \\ []) do
    actor = Keyword.get(opts, :actor, user)
    metadata = Keyword.get(opts, :metadata, %{})

    context_opts =
      if map_size(metadata) > 0 do
        [context: %{ash_events_metadata: metadata}]
      else
        []
      end

    Accounts.update_user!(user, attrs, [actor: actor] ++ context_opts)
  end

  @doc """
  Creates a system actor for testing.

  ## Examples

      actor = system_actor()
      actor = system_actor("my_worker")
  """
  def system_actor(name \\ "test_runner") do
    %SystemActor{name: name}
  end

  @doc """
  Returns all events from the EventLog, sorted by ID ascending.
  """
  def get_all_events do
    EventLog
    |> Ash.Query.sort({:id, :asc})
    |> Ash.read!()
  end

  @doc """
  Returns the count of events in the EventLog.
  """
  def event_count do
    EventLog
    |> Ash.read!()
    |> Enum.count()
  end

  @doc """
  Clears all events from the EventLog.

  Useful for isolating test scenarios.
  """
  def clear_all_events do
    EventLog
    |> Ash.read!()
    |> Enum.each(&Ash.destroy!/1)
  end

  @doc """
  Gets the last N events from the EventLog.
  """
  def get_last_events(count) do
    EventLog
    |> Ash.Query.sort({:id, :desc})
    |> Ash.Query.limit(count)
    |> Ash.read!()
    |> Enum.reverse()
  end

  @doc """
  Gets a single event by its ID.
  """
  def get_event(id) do
    Ash.get!(EventLog, id)
  end

  @doc """
  Finds events for a specific resource.
  """
  def events_for_resource(resource) do
    EventLog
    |> Ash.Query.filter(resource == ^resource)
    |> Ash.Query.sort({:id, :asc})
    |> Ash.read!()
  end

  @doc """
  Finds events for a specific record.
  """
  def events_for_record(record_id) do
    EventLog
    |> Ash.Query.filter(record_id == ^record_id)
    |> Ash.Query.sort({:id, :asc})
    |> Ash.read!()
  end

  @doc """
  Runs event replay and returns :ok or raises on error.
  """
  def run_replay(opts \\ %{}) do
    AshEvents.EventLogs.replay_events!(opts)
  end

  @doc """
  Wraps an action call with the given actor.

  This is a convenience function for ensuring actor attribution
  in tests.

  ## Examples

      result = with_actor(user, fn ->
        Ash.create!(MyResource, %{name: "test"})
      end)
  """
  def with_actor(_actor, fun) when is_function(fun, 0) do
    # The actor should be passed to the action, not set globally
    # This helper is for documentation purposes; use actor: option directly
    fun.()
  end

  @doc """
  Creates test event metadata.

  ## Examples

      metadata = event_metadata(source: "test", trace_id: "abc123")
  """
  def event_metadata(attrs \\ []) do
    Map.new(attrs)
  end

  @doc """
  Generates a unique email for testing.

  Useful when creating multiple users in a single test.
  """
  def unique_email(prefix \\ "user") do
    "#{prefix}_#{System.unique_integer([:positive])}@example.com"
  end

  @doc """
  Waits for a condition to be true, with timeout.

  Useful for async event processing tests.

  ## Options

    * `:timeout` - Maximum time to wait in milliseconds (default: 1000)
    * `:interval` - Polling interval in milliseconds (default: 50)
  """
  def wait_until(condition_fn, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 1000)
    interval = Keyword.get(opts, :interval, 50)
    deadline = System.monotonic_time(:millisecond) + timeout

    do_wait_until(condition_fn, deadline, interval)
  end

  defp do_wait_until(condition_fn, deadline, interval) do
    if condition_fn.() do
      :ok
    else
      if System.monotonic_time(:millisecond) >= deadline do
        {:error, :timeout}
      else
        Process.sleep(interval)
        do_wait_until(condition_fn, deadline, interval)
      end
    end
  end
end
