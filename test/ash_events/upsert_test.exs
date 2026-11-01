# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.UpsertTest do
  alias AshEvents.EventLogs.SystemActor
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts
  alias AshEvents.Accounts.User
  alias AshEvents.EventLogs
  alias AshEvents.EventLogs.EventLog

  require Ash.Query
  import Ash.Expr

  @actor %SystemActor{name: "test_upsert"}

  defp create_initial_user(email) do
    Accounts.create_user_upsert!(
      %{
        email: email,
        given_name: "Initial",
        family_name: "User",
        hashed_password: "hashed_password_123"
      },
      actor: @actor
    )
  end

  # The existing row has family_name "User", so this upsert's condition is false.
  defp skipped_upsert_params(email) do
    %{
      email: email,
      given_name: "Skipped",
      family_name: "Other",
      hashed_password: "hashed_password_123"
    }
  end

  defp skipped_upsert_condition, do: expr(family_name == upsert_conflict(:family_name))

  defp events_for(email) do
    EventLog
    |> Ash.Query.filter(resource == ^User and data[:email] == ^email)
    |> Ash.read!()
  end

  test "upsert action generates events correctly for both create and update paths" do
    # First upsert - should create a new record and generate a create event
    user1 =
      Accounts.create_user_upsert!(
        %{
          email: "upsert@example.com",
          given_name: "Initial",
          family_name: "User",
          hashed_password: "hashed_password_123"
        },
        actor: %SystemActor{name: "test_upsert"}
      )

    # Second upsert with same email but different names - should update existing record
    user2 =
      Accounts.create_user_upsert!(
        %{
          email: "upsert@example.com",
          given_name: "Updated",
          family_name: "Person",
          hashed_password: "hashed_password_123"
        },
        actor: %SystemActor{name: "test_upsert"}
      )

    # Both operations should return the same record ID (upsert updated the existing record)
    assert user1.id == user2.id
    assert user2.given_name == "Updated"
    assert user2.family_name == "Person"

    # Check events created - both upserts should generate create-type events
    # This is because Ash upserts are conceptually "create" actions, not update actions
    events =
      EventLog
      |> Ash.Query.filter(resource == ^User and data[:email] == "upsert@example.com")
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    # Should have exactly 2 create events (one for each upsert call)
    assert length(events) == 2

    [first_event, second_event] = events

    # First event - actual create
    assert first_event.action == :create_upsert
    assert first_event.system_actor == "test_upsert"
    assert first_event.data["given_name"] == "Initial"
    assert first_event.data["family_name"] == "User"
    assert first_event.data["email"] == "upsert@example.com"

    # Second event - upsert that updated existing record, but still shows as create action
    assert second_event.action == :create_upsert
    assert second_event.system_actor == "test_upsert"
    assert second_event.data["given_name"] == "Updated"
    assert second_event.data["family_name"] == "Person"
    assert second_event.data["email"] == "upsert@example.com"

    # Verify event replay works correctly with upserts
    :ok = EventLogs.replay_events!()

    # After replay, should still have the updated values
    replayed_user = Accounts.get_user_by_id!(user2.id, actor: %SystemActor{name: "test_replay"})
    assert replayed_user.given_name == "Updated"
    assert replayed_user.family_name == "Person"
    assert to_string(replayed_user.email) == "upsert@example.com"
  end

  test "auto-generated replay update action is created for upsert actions" do
    # Check that the auto-generated replay update action exists
    actions = User |> Ash.Resource.Info.actions()
    replay_action = Enum.find(actions, &(&1.name == :ash_events_replay_create_upsert_update))

    assert replay_action != nil
    assert replay_action.type == :update
    # Should accept the same fields as the original upsert action
    assert :email in replay_action.accept
    assert :given_name in replay_action.accept
    assert :family_name in replay_action.accept
    assert replay_action.primary? == false
  end

  describe "skipped upserts" do
    test "returns a StaleRecord error and records no event" do
      email = "skipped-upsert@example.com"
      user = create_initial_user(email)

      result =
        User
        |> Ash.Changeset.for_create(:create_upsert, skipped_upsert_params(email),
          actor: @actor,
          upsert_condition: skipped_upsert_condition()
        )
        |> Ash.create(actor: @actor)

      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Changes.StaleRecord{}]}} = result

      persisted = Accounts.get_user_by_id!(user.id, actor: @actor)
      assert persisted.given_name == "Initial"
      assert persisted.family_name == "User"
      assert length(events_for(email)) == 1
    end

    test "returns the existing record with return_skipped_upsert? and records no event" do
      email = "skipped-upsert-return@example.com"
      user = create_initial_user(email)

      assert {:ok, skipped} =
               User
               |> Ash.Changeset.for_create(:create_upsert, skipped_upsert_params(email),
                 actor: @actor,
                 upsert_condition: skipped_upsert_condition(),
                 return_skipped_upsert?: true
               )
               |> Ash.create(actor: @actor)

      assert skipped.id == user.id
      assert skipped.given_name == "Initial"
      assert skipped.family_name == "User"
      assert Ash.Resource.get_metadata(skipped, :upsert_skipped) == true
      assert length(events_for(email)) == 1
    end

    # Untracked bulk creates drop skipped rows and succeed. Tracked bulk creates run
    # each record through the create wrapper, so a skipped row is a StaleRecord error.
    test "bulk create reports a skipped row as a StaleRecord error and records no event" do
      email = "skipped-upsert-bulk@example.com"
      user = create_initial_user(email)

      result =
        Ash.bulk_create([skipped_upsert_params(email)], User, :create_upsert,
          actor: @actor,
          upsert_fields: [:given_name, :family_name],
          upsert_condition: skipped_upsert_condition(),
          return_errors?: true,
          return_records?: true
        )

      assert result.status == :error
      assert result.records == []
      assert [%Ash.Error.Changes.StaleRecord{}] = result.errors

      persisted = Accounts.get_user_by_id!(user.id, actor: @actor)
      assert persisted.given_name == "Initial"
      assert length(events_for(email)) == 1
    end
  end
end
