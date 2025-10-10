# SPDX-FileCopyrightText: 2024 Torkild G. Kjevik
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.ValidationTest do
  alias AshEvents.EventLogs.SystemActor
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts
  alias AshEvents.EventLogs

  def create_user do
    Accounts.create_user!(
      %{
        email: "user@example.com",
        given_name: "John",
        family_name: "Doe",
        hashed_password: "hashed_password_123"
      },
      context: %{ash_events_metadata: %{source: "Signup form"}},
      actor: %SystemActor{name: "test_runner"}
    )
  end

  test "atomic changes throws error" do
    assert_raise Ash.Error.Invalid, fn ->
      Accounts.create_user_with_atomic(
        %{
          email: "user@example.com",
          given_name: "John",
          family_name: "Doe",
          hashed_password: "hashed_password_123"
        },
        context: %{ash_events_metadata: %{source: "Signup form"}},
        actor: %SystemActor{name: "test_runner"}
      )
    end

    user = create_user()

    assert_raise Ash.Error.Invalid, fn ->
      Accounts.update_user_with_atomic(
        user,
        %{
          given_name: "Jack",
          family_name: "Smith"
        },
        actor: user
      )
    end

    assert_raise Ash.Error.Invalid, fn ->
      Accounts.destroy_user_with_atomic(
        user,
        %{},
        actor: user
      )
    end
  end

  test "replay events on event log missing clear function throws RuntimeError" do
    assert_raise(
      RuntimeError,
      "clear_records_for_replay must be specified on Elixir.AshEvents.EventLogs.EventLogMissingClear when doing a replay.",
      fn -> EventLogs.replay_events_missing_clear() end
    )
  end

  test "only_actions works as expected" do
    create = Ash.Resource.Info.action(Accounts.OrgDetails, :create)
    update = Ash.Resource.Info.action(Accounts.OrgDetails, :update)
    create_not_in_only = Ash.Resource.Info.action(Accounts.OrgDetails, :create_not_in_only)

    assert create.manual != nil
    assert update.manual != nil
    assert create_not_in_only.manual == nil
  end

  test "handles validation modules in wrapper gracefully" do
    Accounts.create_org!(%{name: "Some org"})

    {:error, %{errors: [%Ash.Error.Changes.InvalidAttribute{field: :name}]}} =
      Accounts.create_org(%{name: "S"})
  end

  test "replay events handles routed actions correctly" do
    create_user()
    [] = Ash.read!(Accounts.RoutedUser)
    :ok = EventLogs.replay_events!()

    [routed_user] = Ash.read!(Accounts.RoutedUser)
    [user] = Ash.read!(Accounts.User, actor: %SystemActor{name: "system"})

    assert routed_user.given_name == "John"
    assert routed_user.family_name == "Doe"
    assert user.given_name == "John"
    assert user.family_name == "Doe"
  end

  test "custom validation messages are preserved when using AshEvents" do
    # Create an active org (active = true by default)
    org =
      Accounts.create_org!(%{name: "Test Organization"}, actor: %SystemActor{name: "test_runner"})

    assert org.active == true

    # Try to reactivate an already active org - this should fail with our custom message
    {:error, %{errors: errors}} =
      Accounts.reactivate_org(
        org,
        %{justification: "Some reason"},
        actor: %SystemActor{name: "test_runner"}
      )

    # The validation should fail with our custom message, not the default one
    validation_error =
      Enum.find(errors, fn error ->
        error.__struct__ == Ash.Error.Changes.InvalidAttribute &&
          error.field == :active
      end)

    assert validation_error != nil
    assert validation_error.message == "Organization is already active"
  end
end
