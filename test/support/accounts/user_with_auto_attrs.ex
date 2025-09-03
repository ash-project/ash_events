defmodule AshEvents.Test.Accounts.UserWithAutoAttrs do
  @moduledoc false
  use Ash.Resource,
    domain: AshEvents.Test.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events]

  postgres do
    table "users_with_auto_attrs"
    repo AshEvents.TestRepo
  end

  events do
    event_log AshEvents.Test.Events.EventLog
    track_auto_changed_attributes([:status, :slug])
  end

  actions do
    defaults [:read]

    create :create do
      accept [:id, :email, :name, :status, :slug]
    end

    update :update do
      accept [:name]
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
             # Auto-generate slug from name when creating or updating
             case Map.get(changeset.attributes, :name) do
               nil ->
                 changeset

               name ->
                 slug = name |> String.downcase() |> String.replace(~r/[^a-z0-9]/, "-")
                 Ash.Changeset.change_attribute(changeset, :slug, slug)
             end
           end,
           on: [:create, :update]
  end
end
