# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
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

    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             Accounts.destroy_user_with_atomic(user, %{}, actor: user)

    assert Enum.any?(errors, &(Exception.message(&1) =~ "atomic changes are not compatible"))
  end

  test "replay events on event log missing clear function throws RuntimeError" do
    assert_raise(
      Ash.Error.Unknown,
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

  test "before_action?: true delays a validation on a tracked action" do
    org =
      Accounts.create_org_with_before_action_validation!(
        %{name: "Test Organization"},
        actor: %SystemActor{name: "test_runner"}
      )

    assert org.active == false
  end

  test "before_action?: true behaves the same on tracked and ignored actions" do
    args = [%{name: "Test Organization"}, [actor: %SystemActor{name: "test_runner"}]]

    tracked = apply(Accounts, :create_org_with_before_action_validation, args)
    ignored = apply(Accounts, :create_ignored_org_with_before_action_validation, args)

    assert {:ok, %{active: false}} = tracked
    assert {:ok, %{active: false}} = ignored
  end

  test "validations receive a Validation.Context on tracked actions" do
    org =
      Accounts.create_org!(%{name: "Test Organization"}, actor: %SystemActor{name: "test_runner"})

    # `changing/2` reads `context.message`, which only exists on
    # `Ash.Resource.Validation.Context`. With a `Change.Context` this is a
    # KeyError instead of a validation error.
    {:error, %Ash.Error.Invalid{errors: errors}} =
      Accounts.require_org_name_change(org, %{}, actor: %SystemActor{name: "test_runner"})

    assert [%Ash.Error.Changes.InvalidAttribute{field: :name, message: "must be changing"}] =
             errors

    {:ok, %{name: "Renamed"}} =
      Accounts.require_org_name_change(org, %{name: "Renamed"},
        actor: %SystemActor{name: "test_runner"}
      )
  end

  test "validations that read context.message use the custom message on tracked actions" do
    org =
      Accounts.create_org!(%{name: "Test Organization"}, actor: %SystemActor{name: "test_runner"})

    {:error, %Ash.Error.Invalid{errors: errors}} =
      Accounts.require_org_name_change_with_message(org, %{},
        actor: %SystemActor{name: "test_runner"}
      )

    assert [
             %Ash.Error.Changes.InvalidAttribute{
               field: :name,
               message: "a new name is required"
             }
           ] = errors
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
