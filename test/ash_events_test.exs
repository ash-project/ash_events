defmodule AshEventsTest do
  use AshEvents.RepoCase, async: false

  alias AshEvents.Test.Accounts
  alias AshEvents.Test.Events
  alias AshEvents.Test.Accounts.User
  alias AshEvents.Test.Accounts.UserRole
  alias AshEvents.Test.Events.EventResource

  require Ash.Query

  setup do
    Ash.bulk_destroy!(EventResource, :destroy, %{}, strategy: :stream)
    Ash.bulk_destroy!(User, :destroy, %{}, strategy: :stream)
    :ok
  end

  test "events are created as expected & event replay works" do
    user =
      Accounts.create_user!(%{
        email: "user@example.com",
        given_name: "John",
        family_name: "Doe",
        event_metadata: %{meta_field: "meta_value"}
      })

    opts = [actor: user]

    # Events are inserted in the correct order
    [event, event2] =
      EventResource
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    assert event.metadata == %{"meta_field" => "meta_value"}
    assert event.user_id == nil
    assert event.system_actor == nil
    assert event.ash_events_action == :create_ash_events_orig_impl
    assert event.ash_events_resource == User

    assert event2.metadata == %{}
    assert event2.user_id == nil
    assert event2.system_actor == nil
    assert event2.ash_events_action == :create_ash_events_orig_impl
    assert event2.ash_events_resource == UserRole

    Accounts.update_user!(user, %{given_name: "Jane"},
      actor: %AshEvents.Test.Events.SystemActor{name: "Some system worker"}
    )

    [_user] = Ash.read!(User)
    [_user_role] = Ash.read!(UserRole)

    AshEvents.Test.ClearRecords.clear_records!(opts)
    [] = Ash.read!(User)

    [_event, _event2, event3, event4] =
      EventResource
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    assert event3.metadata == %{}
    assert event3.user_id == nil
    assert event3.system_actor == "Some system worker"
    assert event3.ash_events_action == :update_ash_events_orig_impl
    assert event3.ash_events_resource == User

    assert event4.metadata == %{}
    assert event4.user_id == nil
    assert event4.system_actor == "Some system worker"
    assert event4.ash_events_action == :update_ash_events_orig_impl
    assert event4.ash_events_resource == UserRole

    # Would have failed due to unique constraint on user_role if not
    # after_action changes was skipped.
    :ok = Events.replay_events!()

    [user] = Ash.read!(User, load: [:user_role])

    assert user.given_name == "Jane"

    Accounts.destroy_user_role!(user.user_role, opts)
    Accounts.destroy_user!(user, opts)

    [] = Ash.read!(User)

    [_e1, _e2, update_user_event, _e4, event5, event6] =
      EventResource
      |> Ash.Query.sort({:id, :asc})
      |> Ash.read!()

    assert event5.metadata == %{}
    assert event5.user_id == user.id
    assert event5.system_actor == nil
    assert event5.ash_events_action == :destroy_ash_events_orig_impl
    assert event5.ash_events_resource == UserRole

    assert event6.metadata == %{}
    assert event6.user_id == user.id
    assert event6.system_actor == nil
    assert event6.ash_events_action == :destroy_ash_events_orig_impl
    assert event6.ash_events_resource == User

    :ok = Events.replay_events(%{last_event_id: update_user_event.id})

    [user] = Ash.read!(User, load: [:user_role])

    assert user.given_name == "Jane"
    assert user.user_role.name == "regular_user"
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
          family_name: "Family",
          event_metadata: %{meta_field: "meta_value"}
        },
        opts
      )
      |> Ash.create!()

    user =
      user
      |> Ash.Changeset.for_update(
        :update,
        %{
          given_name: "Updated given",
          family_name: "Updated family",
          event_metadata: %{meta_field: "meta_value"}
        },
        opts
      )
      |> Ash.update!(load: [:user_role])

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

    [] = Ash.read!(User)
  end
end
