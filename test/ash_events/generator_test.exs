# SPDX-FileCopyrightText: 2025 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT
#
defmodule AshEvents.GeneratorTest do
  alias AshEvents.Accounts.User
  alias AshEvents.EventLogs.SystemActor
  use AshEvents.RepoCase, async: false

  alias AshEvents.EventLogs.EventLog

  use Ash.Generator

  require Ash.Query

  def user_generator(actor, opts \\ []) do
    changeset_generator(
      User,
      :create,
      defaults: [
        email: sequence(:email, &"user#{&1}@example.com"),
        given_name: StreamData.string(:alphanumeric, min_length: 3, max_length: 10),
        family_name: StreamData.string(:alphanumeric, min_length: 3, max_length: 10),
        hashed_password: "hashed_password_123",
        role: "user",
        # Explicitly set binary attributes to nil to avoid encoding issues
        api_key_hash: nil,
        sensitive_token: nil,
        binary_keys: nil
      ],
      actor: actor,
      overrides: opts
    )
  end

  def user_seed_generator(opts \\ []) do
    seed_generator(
      %User{
        email: sequence(:email, &"user#{&1}@example.com"),
        given_name: "Generated",
        family_name: "User",
        hashed_password: "hashed_password_123"
      },
      overrides: opts
    )
  end

  test "changeset_generator creates events with proper actor attribution" do
    # Generate a user using changeset_generator with actor
    user = generate(user_generator(%SystemActor{name: "test_generator"}))

    assert to_string(user.email) =~ ~r/user\d+@example\.com/

    # Verify events were created (create action + user role creation)
    events =
      EventLog
      |> Ash.Query.filter(resource == ^User)
      |> Ash.read!()

    assert length(events) >= 1

    # Check the user creation event
    [user_event | _] = events
    assert user_event.action == :create
    assert user_event.resource == User
    assert user_event.system_actor == "test_generator"
    assert user_event.data["email"] == to_string(user.email)
  end

  test "generate_many creates multiple records with events" do
    # Generate multiple users using generate_many (bulk operations)
    users = generate_many(user_generator(%SystemActor{name: "batch_generator"}), 3)

    assert length(users) == 3
    assert Enum.all?(users, &match?(%User{}, &1))

    # Verify events were created for all users
    events =
      EventLog
      |> Ash.Query.filter(resource == ^User and system_actor == "batch_generator")
      |> Ash.read!()

    # Should have at least 3 user creation events
    assert length(events) >= 3
  end

  test "multiple generate calls work correctly with events" do
    # Generate multiple users using individual generate calls instead of generate_many
    users =
      for i <- 1..3 do
        generate(user_generator(%SystemActor{name: "multi_generator_#{i}"}))
      end

    assert length(users) == 3
    assert Enum.all?(users, &match?(%User{}, &1))

    # Verify events were created for all users
    events =
      EventLog
      |> Ash.Query.filter(
        resource == ^User and
          contains(system_actor, "multi_generator")
      )
      |> Ash.read!()

    # Should have at least 3 user creation events
    assert length(events) >= 3
  end

  test "seed_generator bypasses events (no events created)" do
    initial_event_count = Ash.read!(EventLog) |> length()

    # Generate a user using seed_generator (bypasses actions)
    user = generate(user_seed_generator())

    assert to_string(user.email) =~ ~r/user\d+@example\.com/
    assert user.given_name == "Generated"

    # Verify no new events were created (seed_generator bypasses actions)
    final_event_count = Ash.read!(EventLog) |> length()
    assert final_event_count == initial_event_count
  end

  test "changeset_generator without actor fails authorization" do
    # Attempting to generate without actor should fail due to authorization
    assert_raise Ash.Error.Forbidden, fn ->
      generate(user_generator(nil))
    end
  end

  test "generator with custom attributes creates events correctly" do
    custom_email = "custom@example.com"

    user =
      generate(
        user_generator(
          %SystemActor{name: "custom_generator"},
          email: custom_email,
          given_name: "CustomFirst"
        )
      )

    assert to_string(user.email) == custom_email
    assert user.given_name == "CustomFirst"

    # Verify event has custom data
    events =
      EventLog
      |> Ash.Query.filter(
        resource == ^User and
          system_actor == "custom_generator"
      )
      |> Ash.read!()

    assert length(events) >= 1
    [event | _] = events
    assert event.data["email"] == custom_email
    assert event.data["given_name"] == "CustomFirst"
  end
end
