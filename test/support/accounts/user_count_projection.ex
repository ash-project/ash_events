# SPDX-FileCopyrightText: 2024 Torkild G. Kjevik
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Accounts.UserCountProjection do
  @moduledoc """
  A projection resource that tracks user counts.

  This demonstrates routing events to a different resource that:
  - Has its own primary key (not the original record_id)
  - May receive record_id as an argument to track references
  - Or may ignore record_id entirely for pure aggregates
  """
  use Ash.Resource,
    domain: AshEvents.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "user_count_projections"
    repo AshEvents.TestRepo
  end

  actions do
    defaults [:read]

    create :increment do
      accept [:projection_type]

      change fn changeset, _ctx ->
        # Get or create the projection, then increment
        Ash.Changeset.after_action(changeset, fn _changeset, record ->
          # Update the count
          {:ok, record}
        end)
      end
    end

    # Action that receives record_id as an argument
    create :track_user_create do
      accept [:projection_type]
      argument :record_id, :uuid, allow_nil?: true

      change fn changeset, _ctx ->
        record_id = Ash.Changeset.get_argument(changeset, :record_id)

        changeset
        |> Ash.Changeset.force_change_attribute(:last_record_id, record_id)
        |> Ash.Changeset.force_change_attribute(:event_count, 1)
      end
    end

    # Action that ignores record_id entirely
    create :count_event do
      accept [:projection_type]

      change fn changeset, _ctx ->
        Ash.Changeset.force_change_attribute(changeset, :event_count, 1)
      end
    end

    update :update do
      accept [:event_count]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :projection_type, :string do
      public? true
      allow_nil? false
      default "user_count"
    end

    attribute :event_count, :integer do
      public? true
      allow_nil? false
      default 0
    end

    # Stores the last record_id seen (for :as_argument mode testing)
    attribute :last_record_id, :uuid do
      public? true
      allow_nil? true
    end
  end
end
