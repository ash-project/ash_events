defmodule AshEventsTest do
  alias AshEvents.Test.Accounts.OrgDetails
  alias AshEvents.Test.Events.EventLogUuidV7
  alias AshEvents.Test.Events.SystemActor
  use AshEvents.RepoCase, async: false

  alias AshEvents.Test.Accounts
  alias AshEvents.Test.Accounts.User
  alias AshEvents.Test.Accounts.UserRole
  alias AshEvents.Test.Events
  alias AshEvents.Test.Events.EventLog

  require Ash.Query

  def create_user do
    Accounts.create_user!(
      %{
        email: "user@example.com",
        given_name: "John",
        family_name: "Doe"
      },
      context: %{ash_events_metadata: %{source: "Signup form"}},
      actor: %SystemActor{name: "test_runner"}
    )
  end

  def create_user_uuidv7 do
    Accounts.create_user_uuidv7!(
      %{
        email: "user@example.com",
        given_name: "John",
        family_name: "Doe"
      },
      context: %{ash_events_metadata: %{source: "Signup form"}},
      actor: %SystemActor{name: "test_runner"}
    )
  end

  test "events are created as expected" do
    create_user()

    # Events are inserted in the correct order
    [event, event2] =
      EventLog
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    assert event.metadata == %{"source" => "Signup form"}
    assert event.user_id == nil
    assert event.system_actor == "test_runner"
    assert event.action == :create
    assert event.resource == User

    assert %{
             "email" => "user@example.com",
             "given_name" => "John",
             "family_name" => "Doe"
           } = event.data

    assert event2.metadata == %{}
    assert event2.user_id == nil
    assert event2.system_actor == "test_runner"
    assert event2.action == :create
    assert event2.resource == UserRole

    assert %{
             "name" => "user",
             "user_id" => _user_id
           } = event2.data
  end

  test "actor primary key is persisted" do
    user = create_user()

    Accounts.update_user!(
      user,
      %{
        given_name: "Jack",
        family_name: "Smith"
      },
      actor: user,
      context: %{ash_events_metadata: %{source: "Profile update"}}
    )

    Accounts.update_user!(
      user,
      %{
        given_name: "Jason",
        family_name: "Anderson"
      },
      actor: %SystemActor{name: "External sync job"},
      context: %{ash_events_metadata: %{source: "External sync"}}
    )

    [_event, _event2, profile_event, system_event] =
      EventLog
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    assert profile_event.user_id == user.id
    assert profile_event.system_actor == nil
    assert profile_event.action == :update
    assert profile_event.resource == User

    assert system_event.user_id == nil
    assert system_event.system_actor == "External sync job"
    assert system_event.action == :update
    assert system_event.resource == User
  end

  test "can be used just like normal actions/changesets" do
    opts = [actor: %AshEvents.Test.Events.SystemActor{name: "Some system worker"}]

    user =
      User
      |> Ash.Changeset.for_create(
        :create,
        %{
          email: "email@email.com",
          given_name: "Given",
          family_name: "Family"
        },
        opts ++ [context: %{ash_events_metadata: %{meta_field: "meta_value"}}]
      )
      |> Ash.create!()

    user =
      user
      |> Ash.Changeset.for_update(
        :update,
        %{
          given_name: "Updated given",
          family_name: "Updated family"
        },
        opts ++ [context: %{ash_events_metadata: %{meta_field: "meta_value"}}]
      )
      |> Ash.update!(load: [:user_role])

    events = Ash.read!(EventLog)
    assert Enum.count(events) == 3

    user.user_role
    |> Ash.Changeset.for_destroy(
      :destroy,
      %{},
      opts
    )
    |> Ash.destroy!()

    user
    |> Ash.Changeset.for_destroy(
      :destroy,
      %{},
      opts
    )
    |> Ash.destroy!()

    [] = Ash.read!(User, opts)

    events = Ash.read!(EventLog)
    assert Enum.count(events) == 5
  end

  test "replay works as expected and skips lifecycle hooks" do
    user = create_user()

    updated_user =
      Accounts.update_user!(
        user,
        %{
          given_name: "Jack",
          family_name: "Smith"
        },
        actor: user,
        context: %{ash_events_metadata: %{source: "Profile update"}}
      )

    Accounts.update_user!(
      updated_user,
      %{
        given_name: "Jason",
        family_name: "Anderson",
        role: "admin"
      },
      actor: %SystemActor{name: "External sync job"},
      context: %{ash_events_metadata: %{source: "External sync"}}
    )
    |> Ash.load!([:user_role])

    events =
      EventLog
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    [
      create_user_event,
      create_user_role_event,
      update_user_event_1,
      _update_user_event_2,
      _update_user_role_event
    ] = events

    :ok = Events.replay_events!(%{last_event_id: update_user_event_1.id})

    user = Accounts.get_user_by_id!(user.id, load: [:user_role], actor: user)

    assert user.given_name == "Jack"
    assert user.family_name == "Smith"
    assert user.user_role.name == "user"

    :ok =
      Events.replay_events!(%{
        point_in_time: create_user_role_event.occurred_at
      })

    user = Accounts.get_user_by_id!(user.id, load: [:user_role], actor: user)

    assert user.given_name == "John"
    assert user.family_name == "Doe"
    assert user.user_role.name == "user"

    :ok =
      Events.replay_events!(%{
        point_in_time: create_user_event.occurred_at
      })

    user = Accounts.get_user_by_id!(user.id, load: [:user_role], actor: user)

    assert user.given_name == "John"
    assert user.family_name == "Doe"
    assert user.user_role == nil

    :ok = Events.replay_events!()

    user = Accounts.get_user_by_id!(user.id, load: [:user_role], actor: user)

    assert user.given_name == "Jason"
    assert user.family_name == "Anderson"
    assert user.user_role.name == "admin"
  end

  test "replay works as expected and skips lifecycle hooks with uuidv7" do
    user = create_user_uuidv7()

    updated_user =
      Accounts.update_user_uuidv7!(
        user,
        %{
          given_name: "Jack",
          family_name: "Smith"
        },
        actor: user,
        context: %{ash_events_metadata: %{source: "Profile update"}}
      )

    Accounts.update_user_uuidv7!(
      updated_user,
      %{
        given_name: "Jason",
        family_name: "Anderson"
      },
      actor: %SystemActor{name: "External sync job"},
      context: %{ash_events_metadata: %{source: "External sync"}}
    )

    events =
      EventLogUuidV7
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    [
      create_user_event,
      update_user_event_1,
      _update_user_event_2
    ] = events

    :ok = Events.replay_events_uuidv7!(%{last_event_id: update_user_event_1.id})

    user = Accounts.get_user_uuidv7_by_id!(user.id, actor: user)

    assert user.given_name == "Jack"
    assert user.family_name == "Smith"

    :ok =
      Events.replay_events_uuidv7!(%{
        point_in_time: create_user_event.occurred_at
      })

    user = Accounts.get_user_uuidv7_by_id!(user.id, actor: user)

    assert user.given_name == "John"
    assert user.family_name == "Doe"

    :ok = Events.replay_events_uuidv7!()

    user = Accounts.get_user_uuidv7_by_id!(user.id, actor: user)

    assert user.given_name == "Jason"
    assert user.family_name == "Anderson"
  end

  test "bulk actions works as expected" do
    result =
      1..2
      |> Enum.map(fn _i ->
        %{
          email: Faker.Internet.email(),
          given_name: Faker.Person.first_name(),
          family_name: Faker.Person.last_name()
        }
      end)
      |> Ash.bulk_create!(User, :create,
        actor: %AshEvents.Test.Events.SystemActor{name: "system"},
        return_notifications?: true,
        return_errors?: true,
        return_records?: true
      )

    assert result.error_count == 0
    assert Enum.count(result.records) == 2
    assert Enum.count(result.notifications) == 2

    events =
      EventLog
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    assert Enum.count(events) == 4

    update_result =
      result.records
      |> Ash.bulk_update!(
        :update,
        %{
          given_name: "Updated",
          family_name: "Name"
        },
        actor: %AshEvents.Test.Events.SystemActor{name: "system"},
        return_notifications?: true,
        return_errors?: true,
        return_records?: true,
        strategy: :stream
      )

    assert update_result.error_count == 0
    assert Enum.count(update_result.records) == 2
    assert Enum.count(update_result.notifications) == 2

    events =
      EventLog
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    assert Enum.count(events) == 6

    users = Accounts.User |> Ash.read!(actor: %SystemActor{name: "system"})

    Enum.each(users, fn user ->
      assert user.given_name == "Updated"
      assert user.family_name == "Name"
    end)

    user_roles = Accounts.UserRole |> Ash.read!()

    destroy_roles_result =
      user_roles
      |> Ash.bulk_destroy!(:destroy, %{},
        return_errors?: true,
        return_notifications?: true,
        return_records?: true,
        strategy: :stream
      )

    assert destroy_roles_result.error_count == 0
    assert Enum.count(destroy_roles_result.records) == 2
    assert Enum.count(destroy_roles_result.notifications) == 2

    [] = Accounts.UserRole |> Ash.read!()

    events =
      EventLog
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    assert Enum.count(events) == 8

    destroy_users_result =
      update_result.records
      |> Ash.bulk_destroy!(:destroy, %{},
        return_errors?: true,
        return_notifications?: true,
        return_records?: true,
        strategy: :stream,
        actor: %SystemActor{name: "system"}
      )

    assert destroy_users_result.error_count == 0
    assert Enum.count(destroy_users_result.records) == 2
    assert Enum.count(destroy_users_result.notifications) == 2

    [] = Accounts.User |> Ash.read!(actor: %SystemActor{name: "system"})

    events =
      EventLog
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    assert Enum.count(events) == 10
  end

  test "replay events on event log missing clear function throws RuntimeError" do
    assert_raise(
      RuntimeError,
      "clear_records_for_replay must be specified on Elixir.AshEvents.Test.Events.EventLogMissingClear when doing a replay.",
      fn -> Events.replay_events_missing_clear() end
    )
  end

  test "replay events handles routed actions correctly" do
    create_user()
    [] = Ash.read!(Accounts.RoutedUser)
    :ok = Events.replay_events!()

    [routed_user] = Ash.read!(Accounts.RoutedUser)
    [user] = Ash.read!(Accounts.User, actor: %SystemActor{name: "system"})

    assert routed_user.given_name == "John"
    assert routed_user.family_name == "Doe"
    assert user.given_name == "John"
    assert user.family_name == "Doe"
  end

  test "atomic changes throws error" do
    assert_raise Ash.Error.Invalid, fn ->
      Accounts.create_user_with_atomic(
        %{
          email: "user@example.com",
          given_name: "John",
          family_name: "Doe"
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

  test "advisory lock default value is used for resources without multitenancy" do
    Accounts.create_org!(%{name: "Test Org"})

    {:ok,
     %Postgrex.Result{
       rows: [["ExclusiveLock", true, 2_147_483_647, 0]]
     }} =
      Ecto.Adapters.SQL.query(AshEvents.TestRepo, """
      SELECT mode, granted, objid, classid
      FROM pg_locks
      WHERE locktype = 'advisory';
      """)
  end

  test "advisory locks built tenant value is used for resources with multitenancy" do
    org = Accounts.create_org!(%{name: "Test Org"})
    Accounts.create_org_details!(%{details: "Test details 1"}, tenant: org.id)
    Accounts.create_org_details!(%{details: "Test details 2"}, tenant: org.id)
    Accounts.create_org_details!(%{details: "Test details 3"}, tenant: org.id)
    Accounts.create_org_details!(%{details: "Test details 4"}, tenant: org.id)
    org_details = Accounts.create_org_details!(%{details: "Test details 5"}, tenant: org.id)

    {:ok,
     %Postgrex.Result{
       rows: rows
     }} =
      Ecto.Adapters.SQL.query(AshEvents.TestRepo, """
      SELECT mode, granted, objid, classid
      FROM pg_locks
      WHERE locktype = 'advisory';
      """)

    changeset =
      org_details |> Ash.Changeset.for_update(:update, %{details: "new details"}, tenant: org.id)

    [hi_int, lo_int] = AshEvents.AdvisoryLockKeyGenerator.Default.generate_key!(changeset, 0)

    hi_int_unsigned = Bitwise.band(hi_int, 0xFFFFFFFF)
    lo_int_unsigned = Bitwise.band(lo_int, 0xFFFFFFFF)

    lock_row =
      Enum.find(rows, fn [mode, granted, objid, classid] ->
        objid == lo_int_unsigned and classid == hi_int_unsigned and
          mode == "ExclusiveLock" and granted
      end)

    assert Enum.count(rows) == 2
    assert lock_row != nil
  end

  test "only_actions works as expected" do
    create = Ash.Resource.Info.action(OrgDetails, :create)
    update = Ash.Resource.Info.action(OrgDetails, :update)
    create_not_in_only = Ash.Resource.Info.action(OrgDetails, :create_not_in_only)

    assert create.manual != nil
    assert update.manual != nil
    assert create_not_in_only.manual == nil
  end

  test "cloaked event logs encrypt data and metadata" do
    Accounts.create_org_cloaked!(%{name: "Cloaked name"},
      context: %{ash_events_metadata: %{some: "metadata"}}
    )

    [event] = Ash.read!(AshEvents.Test.Events.EventLogCloaked)

    decrypted_data =
      event.encrypted_data
      |> Base.decode64!()
      |> AshEvents.Test.Vault.decrypt!()
      |> Jason.decode!()

    decrypted_metadata =
      event.encrypted_metadata
      |> Base.decode64!()
      |> AshEvents.Test.Vault.decrypt!()
      |> Jason.decode!()

    assert decrypted_data["name"] == "Cloaked name"
    assert decrypted_metadata["some"] == "metadata"
  end

  test "cloaked event logs calcs and replay work" do
    org = Accounts.create_org_cloaked!(%{name: "Cloaked name"})

    Accounts.update_org_cloaked!(org, %{name: "Updated name"},
      context: %{ash_events_metadata: %{some: "metadata"}}
    )

    [create_event, update_event] = Ash.read!(AshEvents.Test.Events.EventLogCloaked)

    update_event =
      update_event
      |> Ash.load!([:data, :metadata])

    assert update_event.data["name"] == "Updated name"
    assert update_event.metadata["some"] == "metadata"

    :ok = Events.replay_events_cloaked!(%{last_event_id: create_event.id})

    [org] = Ash.read!(Accounts.OrgCloaked)
    org = Ash.load!(org, [:name])
    assert org.name == "Cloaked name"

    :ok = Events.replay_events_cloaked!()

    [org] = Ash.read!(Accounts.OrgCloaked)
    org = Ash.load!(org, [:name])
    assert org.name == "Updated name"
  end

  test "handles ash_state_machine validations" do
    actor = %SystemActor{name: "system"}

    org =
      Accounts.create_org_state_machine!(%{name: "Test State Machine"},
        actor: actor
      )

    Accounts.set_org_state_machine_inactive!(org, actor: actor)
    Events.replay_events_state_machine!([])
  end

  test "handles embedded resources" do
    user =
      Accounts.create_user_embedded!(%{
        given_name: "Embedded User",
        family_name: "Embedded Family",
        email: "embedded@example.com",
        address: %AshEvents.Test.Accounts.Address{
          street: "Embedded Street",
          city: "Embedded City",
          state: "Embedded State",
          zip_code: "Embedded Zip"
        },
        other_addresses: [
          %AshEvents.Test.Accounts.Address{
            street: "Other Embedded Street",
            city: "Other Embedded City",
            state: "Other Embedded State",
            zip_code: "Other Embedded Zip"
          },
          %AshEvents.Test.Accounts.Address{
            street: "Another Embedded Street",
            city: "Another Embedded City",
            state: "Another Embedded State",
            zip_code: "Another Embedded Zip"
          }
        ]
      })

    user = Ash.load!(user, [:address])
    assert user.address.street == "Embedded Street"

    :ok = Events.replay_events!()

    [user] = Ash.read!(Accounts.UserEmbedded)
    user = Ash.load!(user, [:address])
    assert user.address.street == "Embedded Street"

    assert user.other_addresses |> Enum.map(& &1.street) == [
             "Other Embedded Street",
             "Another Embedded Street"
           ]

    user =
      Accounts.update_user_embedded!(user, %{
        given_name: "Updated Embedded User",
        address: %{street: "Updated Embedded Street"},
        other_addresses: []
      })

    assert user.address.street == "Updated Embedded Street"
    assert user.address.city == "Embedded City"
    assert user.address.state == "Embedded State"
    assert user.address.zip_code == "Embedded Zip"
    assert user.other_addresses == []

    :ok = Events.replay_events!()

    user = Accounts.get_user_embedded_by_id!(user.id)

    assert user.address.street == "Updated Embedded Street"
    assert user.address.city == "Embedded City"
    assert user.address.state == "Embedded State"
    assert user.address.zip_code == "Embedded Zip"
  end

  test "handles validation modules in wrapper gracefully" do
    Accounts.create_org!(%{name: "Some org"})

    {:error, %{errors: [%Ash.Error.Changes.InvalidAttribute{field: :name}]}} =
      Accounts.create_org(%{name: "S"})
  end

  test "handles ash phoenix forms correctly" do
    form_params = %{
      "string_key" => "string_value",
      "email" => "user@example.com",
      given_name: "John",
      family_name: "Doe",
      non_existent: "value"
    }

    form =
      AshPhoenix.Form.for_create(Accounts.User, :create_with_form,
        params: form_params,
        context: %{ash_events_metadata: %{source: "Signup form"}},
        actor: %SystemActor{name: "test_runner"}
      )

    {:ok, _user} = AshPhoenix.Form.submit(form, params: form_params)
  end

  test "upsert action generates events correctly for both create and update paths" do
    # First upsert - should create a new record and generate a create event
    user1 =
      Accounts.create_user_upsert!(
        %{
          email: "upsert@example.com",
          given_name: "Initial",
          family_name: "User"
        },
        actor: %SystemActor{name: "test_upsert"}
      )

    # Second upsert with same email but different names - should update existing record
    user2 =
      Accounts.create_user_upsert!(
        %{
          email: "upsert@example.com",
          given_name: "Updated",
          family_name: "Person"
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
    :ok = Events.replay_events!()

    # After replay, should still have the updated values
    replayed_user = Accounts.get_user_by_id!(user2.id, actor: %SystemActor{name: "test_replay"})
    assert replayed_user.given_name == "Updated"
    assert replayed_user.family_name == "Person"
    assert replayed_user.email == "upsert@example.com"
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
end
