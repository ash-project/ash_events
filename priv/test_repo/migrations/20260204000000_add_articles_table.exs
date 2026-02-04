# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.TestRepo.Migrations.AddArticlesTable do
  @moduledoc """
  Creates the articles table for testing destroy action wrappers
  with both hard and soft delete functionality.
  """
  use Ecto.Migration

  def change do
    create table(:articles, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :title, :text, null: false
      add :body, :text, null: true
      add :archived_at, :utc_datetime_usec, null: true
      add :deleted_at, :utc_datetime_usec, null: true
      add :created_at, :utc_datetime_usec, null: false
      add :updated_at, :utc_datetime_usec, null: false
    end
  end
end
