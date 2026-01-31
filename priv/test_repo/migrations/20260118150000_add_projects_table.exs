defmodule AshEvents.TestRepo.Migrations.AddProjectsTable do
  @moduledoc """
  Creates the projects table for testing non-writable id/timestamp replay.
  """

  use Ecto.Migration

  def up do
    create table(:projects, primary_key: false) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)
      add(:created_at, :utc_datetime_usec, null: false, default: fragment("now()"))
      add(:updated_at, :utc_datetime_usec, null: false, default: fragment("now()"))
      add(:name, :text, null: false)
      add(:description, :text)
      add(:status, :text, null: false, default: "draft")
    end

    create unique_index(:projects, [:name])
  end

  def down do
    drop(table(:projects))
  end
end
