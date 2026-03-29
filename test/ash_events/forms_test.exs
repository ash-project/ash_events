# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.FormsTest do
  alias AshEvents.EventLogs.SystemActor
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts

  test "manage_relationship changes are visible for nested form generation" do
    # This verifies the fix for GitHub issue #87:
    # AshPhoenix needs to find ManageRelationship changes in action.changes
    # to generate nested forms via inputs_for. AshEvents must not wrap these
    # changes in ReplayChangeWrapper.
    action = Ash.Resource.Info.action(Accounts.UserRole, :create)

    has_manage_relationship =
      Enum.any?(action.changes, fn
        %{change: {Ash.Resource.Change.ManageRelationship, _}} -> true
        _ -> false
      end)

    assert has_manage_relationship,
           "ManageRelationship change should be directly visible in action.changes, not wrapped"
  end

  test "AshPhoenix nested forms work with manage_relationship on event-tracked resources" do
    actor = %SystemActor{name: "test_runner"}

    # Create a form with auto-detected nested forms
    form =
      AshPhoenix.Form.for_create(Accounts.User, :create_with_nested_role,
        forms: [auto?: true],
        actor: actor
      )

    # Before the fix, :user_role would not be in form_keys because
    # AshPhoenix couldn't detect ManageRelationship through ReplayChangeWrapper
    assert Keyword.has_key?(form.form_keys, :user_role),
           "AshPhoenix should detect manage_relationship and include :user_role in form_keys"

    # Add the nested form for user_role
    form = AshPhoenix.Form.add_form(form, [:user_role])

    # Submit the form with nested params
    params = %{
      "email" => "nested-form@example.com",
      "given_name" => "Jane",
      "family_name" => "Doe",
      "hashed_password" => "hashed_password_123",
      "user_role" => %{"name" => "admin"}
    }

    {:ok, user} =
      AshPhoenix.Form.submit(form,
        params: params,
        actor: actor
      )

    # Verify user was created
    assert to_string(user.email) == "nested-form@example.com"

    # Verify the nested user_role was created
    user = Ash.load!(user, :user_role, actor: actor)
    assert user.user_role != nil
    assert user.user_role.name == "admin"

    # Verify events were created for both user and user_role
    events =
      AshEvents.EventLogs.EventLog
      |> Ash.read!(actor: actor)
      |> Enum.filter(&(&1.action_type == :create))

    user_event = Enum.find(events, &(&1.resource == Accounts.User and &1.record_id == user.id))
    assert user_event != nil
    assert user_event.action == :create_with_nested_role

    role_event =
      Enum.find(
        events,
        &(&1.resource == Accounts.UserRole and &1.record_id == user.user_role.id)
      )

    assert role_event != nil
    assert role_event.action == :create_from_parent
  end

  test "replay works correctly for events created via nested forms with manage_relationship" do
    actor = %SystemActor{name: "test_runner"}

    # Create a user with a nested role via the manage_relationship action
    user =
      Accounts.User
      |> Ash.Changeset.for_create(
        :create_with_nested_role,
        %{
          email: "replay-nested@example.com",
          given_name: "Jane",
          family_name: "Doe",
          hashed_password: "hashed_password_123",
          user_role: %{name: "admin"}
        },
        actor: actor
      )
      |> Ash.create!(actor: actor)
      |> Ash.load!(:user_role, actor: actor)

    original_user_id = user.id
    original_role_id = user.user_role.id

    # Verify both events exist before replay
    events =
      AshEvents.EventLogs.EventLog
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!(actor: actor)
      |> Enum.filter(&(&1.action_type == :create))

    assert length(events) == 2

    # Verify that belongs_to FK (user_id) is captured in changed_attributes
    # for the user_role event. This is essential for replay — managed relationships
    # are skipped during replay, so the FK must come from changed_attributes.
    role_event =
      Enum.find(events, &(&1.resource == Accounts.UserRole))

    assert Map.has_key?(role_event.changed_attributes, "user_id"),
           "belongs_to FK should be in changed_attributes for replay"

    # Replay all events — this clears all records and recreates from events.
    # The ManageRelationship on :create_with_nested_role must NOT fire during
    # replay (hooks stripped), otherwise it would try to create the user_role
    # a second time when the user_role's own event also creates it.
    :ok = AshEvents.EventLogs.replay_events!()

    # Verify user was recreated with correct data
    user = Accounts.get_user_by_id!(original_user_id, load: [:user_role], actor: actor)
    assert user.given_name == "Jane"
    assert user.family_name == "Doe"

    # Verify user_role was recreated from its own event
    assert user.user_role != nil
    assert user.user_role.id == original_role_id
    assert user.user_role.name == "admin"
  end

  test "handles ash phoenix forms correctly" do
    form_params = %{
      "string_key" => "string_value",
      "email" => "user@example.com",
      given_name: "John",
      family_name: "Doe",
      non_existent: "value",
      hashed_password: "hashed_password_123"
    }

    form =
      AshPhoenix.Form.for_create(Accounts.User, :create_with_form,
        params: form_params,
        context: %{ash_events_metadata: %{source: "Signup form"}},
        actor: %SystemActor{name: "test_runner"}
      )

    {:ok, _user} = AshPhoenix.Form.submit(form, params: form_params)
  end
end
