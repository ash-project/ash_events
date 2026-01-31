defmodule AshEvents.TestRepo.Migrations.AddUserCountProjectionsTable do
  @moduledoc """
  Creates the user_count_projections table for testing record_id modes.
  """

  use Ecto.Migration

  def up do
    create table(:user_count_projections, primary_key: false) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)
      add(:projection_type, :text, null: false, default: "user_count")
      add(:event_count, :integer, null: false, default: 0)
      add(:last_record_id, :uuid)
    end
  end

  def down do
    drop(table(:user_count_projections))
  end
end
