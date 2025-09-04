defmodule AshEvents.TimestampTest do
  alias AshEvents.Test.Accounts.Org
  alias AshEvents.Test.Accounts.User
  alias AshEvents.Test.Events.SystemActor
  use AshEvents.RepoCase, async: false
  alias AshEvents.Test.Accounts
  alias AshEvents.Test.Events.EventLog

  require Ash.Query

  describe "event occurred_at timestamp matching" do
    test "create action event occurred_at matches create_timestamp" do
      user =
        Accounts.create_user!(
          %{
            email: "user@example.com",
            given_name: "John",
            family_name: "Doe"
          },
          actor: %SystemActor{name: "test_runner"}
        )

      user_create_event =
        EventLog
        |> Ash.Query.filter(resource == ^User and action == :create)
        |> Ash.Query.sort({:id, :asc})
        |> Ash.read!()
        |> List.first()

      assert user_create_event.occurred_at == user.created_at,
             "Event occurred_at (#{user_create_event.occurred_at}) should match user created_at (#{user.created_at})"
    end

    test "update action event occurred_at matches update_timestamp" do
      user =
        Accounts.create_user!(
          %{
            email: "user@example.com",
            given_name: "John",
            family_name: "Doe"
          },
          actor: %SystemActor{name: "test_runner"}
        )

      updated_user =
        user
        |> Ash.Changeset.for_update(
          :update,
          %{given_name: "Updated John"},
          actor: %SystemActor{name: "test_runner"}
        )
        |> Ash.update!()

      user_update_event =
        EventLog
        |> Ash.Query.filter(resource == ^User and action == :update)
        |> Ash.Query.sort({:id, :desc})
        |> Ash.read!()
        |> List.first()

      assert user_update_event.occurred_at == updated_user.updated_at,
             "Event occurred_at (#{user_update_event.occurred_at}) should match user updated_at (#{updated_user.updated_at})"
    end

    test "org create action event occurred_at matches create_timestamp" do
      org =
        Org
        |> Ash.Changeset.for_create(
          :create,
          %{name: "Test Organization"},
          actor: %SystemActor{name: "test_runner"}
        )
        |> Ash.create!()

      org_create_event =
        EventLog
        |> Ash.Query.filter(resource == ^Org and action == :create)
        |> Ash.Query.sort({:id, :asc})
        |> Ash.read!()
        |> List.first()

      assert org_create_event.occurred_at == org.created_at,
             "Event occurred_at (#{org_create_event.occurred_at}) should match org created_at (#{org.created_at})"
    end

    test "org update action event occurred_at matches update_timestamp" do
      org =
        Org
        |> Ash.Changeset.for_create(
          :create,
          %{name: "Test Organization"},
          actor: %SystemActor{name: "test_runner"}
        )
        |> Ash.create!()

      updated_org =
        org
        |> Ash.Changeset.for_update(
          :update,
          %{name: "Updated Organization"},
          actor: %SystemActor{name: "test_runner"}
        )
        |> Ash.update!()

      # Get the update event for the org
      org_update_event =
        EventLog
        |> Ash.Query.filter(resource == ^Org and action == :update)
        |> Ash.Query.sort({:id, :desc})
        |> Ash.read!()
        |> List.first()

      # Assert that event occurred_at matches the org's updated_at timestamp
      assert org_update_event.occurred_at == updated_org.updated_at,
             "Event occurred_at (#{org_update_event.occurred_at}) should match org updated_at (#{updated_org.updated_at})"
    end
  end
end
