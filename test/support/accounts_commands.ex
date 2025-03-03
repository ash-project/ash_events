defmodule AshEvents.Test.Accounts.Commands do
  alias AshEvents.Test.Accounts

  use Ash.Resource,
    domain: AshEvents.Test.Accounts,
    extensions: [AshEvents.CommandResource],
    data_layer: AshPostgres.DataLayer

  # Even though a command resource will never persist any data to
  # its own table, it still needs the datalayer extension in order
  # to be able to start transactions.
  postgres do
    table "commands"
    repo AshEvents.TestRepo
  end

  commands do
    event_resource AshEvents.Test.Events.EventResource

    command :create_user, :struct do
      constraints instance_of: AshEvents.Test.Accounts.User
      event_name "accounts_user_created"
      event_version "1.0"

      before_dispatch fn event_args, opts ->
        {:ok, put_in(event_args, [:metadata, :some_value], "something")}
      end

      after_dispatch fn created_event, opts ->
        Accounts.get_user_by_id(created_event.entity_id, opts)
      end
    end

    command :create_user_before_fail, :struct do
      constraints instance_of: AshEvents.Test.Accounts.User
      event_name "accounts_user_created"
      event_version "1.0"

      before_dispatch fn event_args, opts ->
        {:error, "Ooops"}
      end

      after_dispatch fn created_event, opts ->
        Accounts.get_user_by_id(created_event.entity_id, opts)
      end
    end

    command :create_user_after_fail, :struct do
      constraints instance_of: AshEvents.Test.Accounts.User
      event_name "accounts_user_created"
      event_version "1.0"

      before_dispatch fn event_args, opts ->
        {:ok, put_in(event_args, [:metadata, :some_value], "something")}
      end

      after_dispatch fn created_event, opts ->
        Accounts.get_user_by_id(Ash.UUID.generate(), opts)
      end
    end

    command :update_user, :struct do
      constraints instance_of: AshEvents.Test.Accounts.User
      event_name "accounts_user_updated"
      event_version "1.0"

      before_dispatch fn event_args, opts ->
        {:ok, put_in(event_args, [:metadata, :other_value], "something else")}
      end

      after_dispatch fn created_event, opts ->
        Accounts.get_user_by_id(created_event.entity_id, opts)
      end
    end

    command :destroy_user do
      event_name "accounts_user_destroyed"
      event_version "1.0"

      before_dispatch fn event_args, opts ->
        {:ok, put_in(event_args, [:metadata, :some_value], "something")}
      end
    end
  end
end
