# SPDX-FileCopyrightText: 2024 Torkild G. Kjevik
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Accounts.UserWithAutoAttrs do
  @moduledoc false
  use Ash.Resource,
    domain: AshEvents.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events]

  postgres do
    table "users_with_auto_attrs"
    repo AshEvents.TestRepo
  end

  events do
    event_log AshEvents.EventLogs.EventLog

    replay_non_input_attribute_changes create: :force_change,
                                       update: :as_arguments,
                                       update_with_required_slug: :as_arguments,
                                       destroy: :force_change
  end

  actions do
    defaults [:read]

    create :create do
      accept [:id, :email, :name, :status]
    end

    update :update do
      accept [:name, :slug]
    end

    update :update_with_required_slug do
      accept [:name]

      argument :slug, :string do
        allow_nil? false
      end

      change fn changeset, _context ->
        case Ash.Changeset.get_argument(changeset, :slug) do
          nil ->
            changeset

          slug ->
            # Force set the slug from the argument to ensure it takes priority
            changeset
            |> Ash.Changeset.force_change_attribute(:slug, slug)
        end
      end
    end

    destroy :destroy do
      require_atomic? false
    end
  end

  attributes do
    uuid_primary_key :id do
      writable? true
    end

    attribute :email, :string do
      public? true
      allow_nil? false
    end

    attribute :name, :string do
      public? true
      allow_nil? false
    end

    attribute :status, :string do
      public? true
      default "active"
      allow_nil? false
    end

    attribute :slug, :string do
      public? true
      allow_nil? false
    end
  end

  changes do
    change fn changeset, _context ->
             # Auto-generate slug from name when creating or updating,
             # but only if slug is not already set (e.g., by an argument)
             case {Map.get(changeset.attributes, :name), Map.get(changeset.attributes, :slug)} do
               {nil, _} ->
                 changeset

               {_, slug} when not is_nil(slug) ->
                 # Slug is already set, don't override it
                 changeset

               {name, nil} ->
                 slug = name |> String.downcase() |> String.replace(~r/[^a-z0-9]/, "-")
                 Ash.Changeset.change_attribute(changeset, :slug, slug)
             end
           end,
           on: [:create, :update]
  end
end
