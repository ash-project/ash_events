# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Test.Assertions do
  @moduledoc """
  Custom assertions for AshEvents test suite.

  This module provides domain-specific assertions that make tests
  more readable and provide better error messages.

  ## Usage

      use AshEvents.RepoCase, async: false
      import AshEvents.Test.Assertions

      test "events are created" do
        create_user()
        assert_events_count(2)  # user + user_role
      end
  """

  import ExUnit.Assertions

  alias AshEvents.EventLogs.EventLog

  require Ash.Query

  @doc """
  Asserts that the EventLog contains exactly `count` events.

  ## Examples

      assert_events_count(3)
      assert_events_count(0)
  """
  def assert_events_count(expected_count) do
    actual_count = Ash.read!(EventLog) |> Enum.count()

    assert actual_count == expected_count,
           "Expected #{expected_count} events, but found #{actual_count}"
  end

  @doc """
  Asserts that a specific number of events were created for a resource.

  ## Examples

      assert_events_count_for_resource(MyApp.User, 2)
  """
  def assert_events_count_for_resource(resource, expected_count) do
    actual_count =
      EventLog
      |> Ash.Query.filter(resource == ^resource)
      |> Ash.read!()
      |> Enum.count()

    assert actual_count == expected_count,
           "Expected #{expected_count} events for #{inspect(resource)}, but found #{actual_count}"
  end

  @doc """
  Asserts that an event was created with the given attributes.

  ## Options

    * `:resource` - The expected resource module
    * `:action` - The expected action name (atom)
    * `:action_type` - The expected action type (:create, :update, :destroy)
    * `:record_id` - The expected record ID
    * `:data` - A map of expected data fields (partial match)
    * `:metadata` - A map of expected metadata fields (partial match)

  ## Examples

      assert_event_created(resource: MyApp.User, action: :create)
      assert_event_created(resource: MyApp.User, data: %{"email" => "test@example.com"})
  """
  def assert_event_created(opts) do
    events = Ash.read!(EventLog)

    matching_event =
      Enum.find(events, fn event ->
        matches_event_criteria?(event, opts)
      end)

    assert matching_event != nil,
           "No event found matching criteria: #{inspect(opts)}\n" <>
             "Available events: #{format_events(events)}"

    matching_event
  end

  @doc """
  Asserts that no event was created matching the given criteria.

  Uses the same options as `assert_event_created/1`.
  """
  def refute_event_created(opts) do
    events = Ash.read!(EventLog)

    matching_event =
      Enum.find(events, fn event ->
        matches_event_criteria?(event, opts)
      end)

    refute matching_event != nil,
           "Expected no event matching criteria: #{inspect(opts)}\n" <>
             "But found: #{inspect(matching_event)}"
  end

  @doc """
  Asserts that an event has the expected actor attribution.

  ## Options

    * `:user_id` - The expected user ID
    * `:system_actor` - The expected system actor name

  ## Examples

      assert_actor_attributed(event, user_id: user.id)
      assert_actor_attributed(event, system_actor: "test_runner")
  """
  def assert_actor_attributed(event, opts) do
    if Keyword.has_key?(opts, :user_id) do
      expected_user_id = Keyword.get(opts, :user_id)

      assert event.user_id == expected_user_id,
             "Expected event to have user_id #{inspect(expected_user_id)}, " <>
               "but got #{inspect(event.user_id)}"
    end

    if Keyword.has_key?(opts, :system_actor) do
      expected_system_actor = Keyword.get(opts, :system_actor)

      assert event.system_actor == expected_system_actor,
             "Expected event to have system_actor #{inspect(expected_system_actor)}, " <>
               "but got #{inspect(event.system_actor)}"
    end

    event
  end

  @doc """
  Asserts that event replay completed successfully.

  ## Examples

      assert_replay_successful()
      assert_replay_successful(%{last_event_id: event.id})
  """
  def assert_replay_successful(opts \\ %{}) do
    result = AshEvents.EventLogs.replay_events!(opts)

    assert result == :ok,
           "Expected replay to return :ok, but got #{inspect(result)}"

    :ok
  end

  @doc """
  Asserts that changed_attributes contains the expected keys.

  ## Examples

      assert_changed_attributes(event, [:status, :slug])
  """
  def assert_changed_attributes(event, expected_keys) when is_list(expected_keys) do
    changed_keys = Map.keys(event.changed_attributes) |> Enum.map(&to_string/1) |> MapSet.new()
    expected_keys = expected_keys |> Enum.map(&to_string/1) |> MapSet.new()

    assert MapSet.equal?(changed_keys, expected_keys),
           "Expected changed_attributes to contain #{inspect(MapSet.to_list(expected_keys))}, " <>
             "but got #{inspect(MapSet.to_list(changed_keys))}"

    event
  end

  @doc """
  Asserts that an event's data contains the expected key-value pairs.

  This is a partial match - the event data may contain additional keys.

  ## Examples

      assert_event_data_contains(event, %{"email" => "test@example.com"})
  """
  def assert_event_data_contains(event, expected_data) when is_map(expected_data) do
    Enum.each(expected_data, fn {key, expected_value} ->
      key_str = to_string(key)
      actual_value = Map.get(event.data, key_str) || Map.get(event.data, key)

      assert actual_value == expected_value,
             "Expected event.data[#{inspect(key)}] to be #{inspect(expected_value)}, " <>
               "but got #{inspect(actual_value)}"
    end)

    event
  end

  @doc """
  Asserts that an event's metadata contains the expected key-value pairs.

  This is a partial match - the event metadata may contain additional keys.

  ## Examples

      assert_event_metadata_contains(event, %{"source" => "test"})
  """
  def assert_event_metadata_contains(event, expected_metadata) when is_map(expected_metadata) do
    Enum.each(expected_metadata, fn {key, expected_value} ->
      key_str = to_string(key)
      actual_value = Map.get(event.metadata, key_str) || Map.get(event.metadata, key)

      assert actual_value == expected_value,
             "Expected event.metadata[#{inspect(key)}] to be #{inspect(expected_value)}, " <>
               "but got #{inspect(actual_value)}"
    end)

    event
  end

  @doc """
  Asserts that events are in chronological order by occurred_at.

  ## Examples

      events = get_all_events()
      assert_events_chronological(events)
  """
  def assert_events_chronological(events) when is_list(events) do
    timestamps = Enum.map(events, & &1.occurred_at)

    sorted = Enum.sort(timestamps, DateTime)

    assert timestamps == sorted,
           "Events are not in chronological order.\n" <>
             "Actual: #{inspect(timestamps)}\n" <>
             "Expected: #{inspect(sorted)}"

    events
  end

  @doc """
  Asserts that a record's state matches after replay.

  ## Examples

      assert_state_after_replay(User, user.id, %{given_name: "John"})
  """
  def assert_state_after_replay(resource, record_id, expected_attrs, opts \\ []) do
    actor = Keyword.get(opts, :actor)

    record =
      resource
      |> Ash.Query.filter(id == ^record_id)
      |> Ash.read_one!(actor: actor)

    if record do
      Enum.each(expected_attrs, fn {key, expected_value} ->
        actual_value = Map.get(record, key)

        assert actual_value == expected_value,
               "After replay, expected #{inspect(resource)}.#{key} to be #{inspect(expected_value)}, " <>
                 "but got #{inspect(actual_value)}"
      end)
    else
      flunk("Record not found after replay: #{inspect(resource)} with id #{inspect(record_id)}")
    end

    record
  end

  @doc """
  Asserts that a record was destroyed after replay.

  ## Examples

      assert_destroyed_after_replay(User, user.id)
  """
  def assert_destroyed_after_replay(resource, record_id, opts \\ []) do
    actor = Keyword.get(opts, :actor)

    record =
      resource
      |> Ash.Query.filter(id == ^record_id)
      |> Ash.read_one!(actor: actor)

    assert record == nil,
           "Expected record to be destroyed after replay, but found: #{inspect(record)}"
  end

  @doc """
  Asserts that the event version matches expected.

  ## Examples

      assert_event_version(event, 1)
      assert_event_version(event, 2)
  """
  def assert_event_version(event, expected_version) do
    assert event.version == expected_version,
           "Expected event version #{expected_version}, but got #{event.version}"

    event
  end

  # Private helpers

  defp matches_event_criteria?(event, opts) do
    Enum.all?(opts, fn {key, expected} ->
      case key do
        :resource ->
          event.resource == expected

        :action ->
          event.action == expected

        :action_type ->
          event.action_type == expected

        :record_id ->
          event.record_id == expected

        :data ->
          Enum.all?(expected, fn {k, v} ->
            Map.get(event.data, to_string(k)) == v || Map.get(event.data, k) == v
          end)

        :metadata ->
          Enum.all?(expected, fn {k, v} ->
            Map.get(event.metadata, to_string(k)) == v || Map.get(event.metadata, k) == v
          end)

        _ ->
          true
      end
    end)
  end

  defp format_events(events) do
    events
    |> Enum.map(fn event ->
      "[#{event.action_type}:#{event.action}] resource=#{inspect(event.resource)} record_id=#{inspect(event.record_id)}"
    end)
    |> Enum.join("\n  ")
  end
end
