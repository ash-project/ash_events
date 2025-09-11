defmodule AshEvents.AshAuthenticationPasswordTest do
  @moduledoc """
  Comprehensive tests for AshEvents compatibility with AshAuthentication password strategies.
  Tests password registration, sign-in, reset, and change flows while verifying events are created correctly.
  """

  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts.User
  alias AshEvents.EventLogs.EventLog
  alias AshEvents.EventLogs.SystemActor
  alias AshEvents.EventLogs

  require Ash.Query

  # Helper function to clear all data before each test
  setup do
    # Clear all users and events using system actor to bypass policies
    system_actor = %SystemActor{name: "test_cleanup"}
    User |> Ash.read!(actor: system_actor) |> Enum.each(&Ash.destroy!(&1, actor: system_actor))
    EventLog |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
    :ok
  end

  describe "password registration" do
    test "user can register with password and events are created" do
      email = "test@example.com"
      password = "secure_password123"

      # Register user with password
      {:ok, user} =
        User
        |> Ash.Changeset.for_action(
          :register_with_password,
          %{
            email: email,
            password: password,
            password_confirmation: password,
            given_name: "John",
            family_name: "Doe"
          }
        )
        |> Ash.create(context: %{private: %{ash_authentication?: true}})

      # Verify user was created with correct attributes
      assert to_string(user.email) == email
      assert user.__metadata__.token != nil

      # Verify events were created
      events =
        EventLog
        |> Ash.Query.filter(resource == ^User)
        |> Ash.Query.sort({:id, :asc})
        |> Ash.read!()

      assert length(events) == 1

      # Find the user creation event
      user_create_event = Enum.find(events, &(&1.action == :register_with_password))
      assert user_create_event != nil
      assert user_create_event.resource == User
      assert user_create_event.action == :register_with_password

      # Verify event data contains user information (but not sensitive data)
      assert user_create_event.data["email"] == email
      assert user_create_event.changed_attributes["hashed_password"] != nil

      # No user actor for registration
      assert user_create_event.user_id == nil
      # No system actor used for registration
      assert user_create_event.system_actor == nil
    end

    test "registration with mismatched passwords fails gracefully" do
      email = "mismatch@example.com"
      system_actor = %SystemActor{name: "registration_system"}

      # Attempt registration with mismatched passwords
      assert_raise Ash.Error.Invalid, fn ->
        User
        |> Ash.Changeset.for_action(
          :register_with_password,
          %{
            email: email,
            password: "password123",
            password_confirmation: "different_password"
          },
          actor: system_actor
        )
        |> Ash.create!()
      end

      # Verify no user was created
      system_actor = %SystemActor{name: "test_verify"}
      users = User |> Ash.read!(actor: system_actor)
      assert Enum.empty?(users)

      # Verify no events were created for the failed registration
      events = EventLog |> Ash.read!()
      assert Enum.empty?(events)
    end
  end

  describe "password sign-in" do
    setup do
      # Create a confirmed user for sign-in tests
      email = "signin@example.com"
      password = "signin_password123"

      {:ok, user} =
        User
        |> Ash.Changeset.for_action(
          :register_with_password,
          %{
            email: email,
            password: password,
            password_confirmation: password,
            given_name: "John",
            family_name: "Doe"
          }
        )
        |> Ash.create(context: %{private: %{ash_authentication?: true}})

      {:ok, user: user, email: email, password: password}
    end

    test "user can sign in with correct password", %{
      user: _user,
      email: email,
      password: password
    } do
      # Sign in with correct credentials
      {:ok, signed_in_user} =
        User
        |> Ash.Query.for_read(
          :sign_in_with_password,
          %{
            email: email,
            password: password
          }
        )
        |> Ash.read_one(context: %{private: %{ash_authentication?: true}})

      # Verify sign-in successful
      assert signed_in_user != nil
      assert to_string(signed_in_user.email) == email

      # Verify authentication token was generated
      assert signed_in_user.__metadata__.token != nil

      # Note: sign_in_with_password is a read action, so it may not create events
      # This is correct behavior as sign-ins are typically not persisted as events
      # unless specifically configured to do so
    end

    test "sign-in with incorrect password fails", %{email: email} do
      # Attempt sign-in with incorrect password
      {:error, result} =
        User
        |> Ash.Query.for_read(
          :sign_in_with_password,
          %{
            email: email,
            password: "wrong_password"
          }
        )
        |> Ash.read_one(context: %{private: %{ash_authentication?: true}})

      %{errors: errors} = result
      assert [%{caused_by: %{message: "Password is not valid"}}] = errors
    end
  end

  describe "password reset flow" do
    setup do
      email = "reset@example.com"
      password = "original_password123"

      {:ok, user} =
        User
        |> Ash.Changeset.for_action(
          :register_with_password,
          %{
            email: email,
            password: password,
            password_confirmation: password,
            given_name: "John",
            family_name: "Doe"
          }
        )
        |> Ash.create(context: %{private: %{ash_authentication?: true}})

      {:ok, user: user, email: email, password: password}
    end

    test "password reset request generates token", %{email: email} do
      # Request password reset
      :ok =
        User
        |> Ash.ActionInput.for_action(
          :request_password_reset_token,
          %{email: email}
        )
        |> Ash.run_action(context: %{private: %{ash_authentication?: true}})

      # The request should succeed (actual token delivery is mocked)
      # In a real app, this would send an email with a reset token
    end

    test "password reset request with non-existent email succeeds silently" do
      # Request password reset for non-existent email
      :ok =
        User
        |> Ash.ActionInput.for_action(
          :request_password_reset_token,
          %{email: "nonexistent@example.com"}
        )
        |> Ash.run_action(context: %{private: %{ash_authentication?: true}})

      # Request should succeed silently for security reasons
      # (don't reveal whether email exists or not)
    end
  end

  describe "password change" do
    setup do
      # Create a confirmed user for password change tests
      email = "change@example.com"
      password = "original_password123"

      {:ok, user} =
        User
        |> Ash.Changeset.for_action(
          :register_with_password,
          %{
            email: email,
            password: password,
            password_confirmation: password,
            given_name: "John",
            family_name: "Doe"
          }
        )
        |> Ash.create(context: %{private: %{ash_authentication?: true}})

      {:ok, user: user, email: email, password: password}
    end

    test "user can change password with correct current password", %{
      user: user,
      password: current_password
    } do
      new_password = "new_secure_password123"

      # Change password
      {:ok, updated_user} =
        user
        |> Ash.Changeset.for_action(
          :change_password,
          %{
            current_password: current_password,
            password: new_password,
            password_confirmation: new_password
          }
        )
        |> Ash.update(context: %{private: %{ash_authentication?: true}})

      # Verify password was changed
      assert updated_user.hashed_password != user.hashed_password

      # Verify user can now sign in with new password
      {:ok, signed_in_user} =
        User
        |> Ash.Query.for_read(
          :sign_in_with_password,
          %{
            email: updated_user.email,
            password: new_password
          }
        )
        |> Ash.read_one(context: %{private: %{ash_authentication?: true}})

      assert signed_in_user != nil
      assert signed_in_user.id == user.id

      # Verify events were created for password change
      password_change_events =
        EventLog
        |> Ash.Query.filter(resource == ^User and action == :change_password)
        |> Ash.read!()

      assert length(password_change_events) >= 1

      password_change_event = hd(password_change_events)
      assert password_change_event.resource == User
      assert password_change_event.action == :change_password
      assert password_change_event.record_id == user.id

      # Verify sensitive data is not stored in event
      assert password_change_event.data["current_password"] == nil
      assert password_change_event.data["password"] == nil
      assert password_change_event.data["hashed_password"] == nil
    end

    test "password change with incorrect current password fails", %{user: user} do
      new_password = "new_secure_password123"

      # Attempt password change with wrong current password
      assert_raise Ash.Error.Forbidden, fn ->
        user
        |> Ash.Changeset.for_action(
          :change_password,
          %{
            current_password: "wrong_current_password",
            password: new_password,
            password_confirmation: new_password
          }
        )
        |> Ash.update!(actor: user)
      end

      unchanged_user = User |> Ash.get!(user.id, actor: user)
      assert unchanged_user.hashed_password == user.hashed_password
    end

    test "password change with mismatched new passwords fails", %{
      user: user,
      password: current_password
    } do
      # Attempt password change with mismatched new passwords
      assert_raise Ash.Error.Invalid, fn ->
        user
        |> Ash.Changeset.for_action(
          :change_password,
          %{
            current_password: current_password,
            password: "new_password123",
            password_confirmation: "different_new_password123"
          },
          actor: user
        )
        |> Ash.update!(actor: user)
      end

      # Verify password was not changed
      unchanged_user = User |> Ash.get!(user.id, actor: user)
      assert unchanged_user.hashed_password == user.hashed_password
    end
  end

  describe "event replay with password authentication" do
    test "password authentication events can be replayed correctly" do
      email = "replay@example.com"
      password = "replay_password123"
      system_actor = %SystemActor{name: "replay_test"}

      # Register user with password
      {:ok, original_user} =
        User
        |> Ash.Changeset.for_action(
          :register_with_password,
          %{
            email: email,
            password: password,
            password_confirmation: password
          },
          actor: system_actor
        )
        |> Ash.create(context: %{private: %{ash_authentication?: true}})

      # Change password
      new_password = "new_replay_password123"

      {:ok, updated_user} =
        original_user
        |> Ash.Changeset.for_action(
          :change_password,
          %{
            current_password: password,
            password: new_password,
            password_confirmation: new_password
          }
        )
        |> Ash.update(context: %{private: %{ash_authentication?: true}})

      original_hashed_password = updated_user.hashed_password
      :ok = EventLogs.replay_events!(actor: system_actor)

      # Verify user was recreated with correct state
      system_actor = %SystemActor{name: "replay_verify"}
      replayed_users = User |> Ash.read!(actor: system_actor)
      assert length(replayed_users) == 1

      replayed_user = hd(replayed_users)
      assert to_string(replayed_user.email) == email
      assert replayed_user.id == original_user.id
      assert replayed_user.hashed_password == original_hashed_password

      # Verify user can still sign in with the new password after replay
      {:ok, signed_in_user} =
        User
        |> Ash.Query.for_read(
          :sign_in_with_password,
          %{
            email: email,
            password: new_password
          }
        )
        |> Ash.read_one(context: %{private: %{ash_authentication?: true}})

      assert signed_in_user.id == replayed_user.id
    end
  end

  describe "authentication with actor attribution" do
    test "password operations with system actors are properly attributed in events" do
      email = "system@example.com"
      password = "system_password123"
      actor = %SystemActor{name: "test_system"}

      # Register user with system actor
      {:ok, user} =
        User
        |> Ash.Changeset.for_action(
          :register_with_password,
          %{
            email: email,
            password: password,
            password_confirmation: password
          },
          actor: actor
        )
        |> Ash.create(context: %{private: %{ash_authentication?: true}})

      # Verify system actor attribution in events
      events =
        EventLog
        |> Ash.Query.filter(resource == ^User and record_id == ^user.id)
        |> Ash.read!()

      assert length(events) >= 1

      registration_event = Enum.find(events, &(&1.action == :register_with_password))
      assert registration_event != nil
      assert registration_event.system_actor == "test_system"
      # System actor, not user actor
      assert registration_event.user_id == nil
    end
  end
end
