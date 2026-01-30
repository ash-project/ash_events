# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.TestRepo.Migrations.AddSoftDeletableUsers do
  @moduledoc """
  Adds the soft_deletable_users table for testing soft delete functionality.
  """

  use Ecto.Migration

  def up do
    create table(:soft_deletable_users, primary_key: false) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)

      add(:created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )

      add(:updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )

      add(:email, :text, null: false)
      add(:name, :text)
      add(:archived_at, :utc_datetime_usec)
    end

    create unique_index(:soft_deletable_users, [:email], name: "soft_deletable_users_unique_email_index")
  end

  def down do
    drop_if_exists(unique_index(:soft_deletable_users, [:email], name: "soft_deletable_users_unique_email_index"))
    drop(table(:soft_deletable_users))
  end
end
