defmodule AshEventsTest do
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
             "family_name" => "Doe",
             "created_at" => _created_at,
             "updated_at" => _updated_at,
             "id" => _id
           } = event.data

    assert event2.metadata == %{}
    assert event2.user_id == nil
    assert event2.system_actor == "test_runner"
    assert event2.action == :create
    assert event2.resource == UserRole

    assert %{
             "role" => "user",
             "created_at" => _created_at,
             "updated_at" => _updated_at,
             "id" => _id
           } = event.data
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
          family_name: "Updated family",
          ash_events_metadata: %{meta_field: "meta_value"}
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
    assert Enum.count(result.notifications) == 4

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
    assert Enum.count(update_result.notifications) == 4

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
    assert Enum.count(destroy_roles_result.notifications) == 4

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
    assert Enum.count(destroy_users_result.notifications) == 4

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
end
