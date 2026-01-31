# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EventLogs.EventLog do
  @moduledoc false
  use Ash.Resource,
    domain: AshEvents.EventLogs,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.EventLog]

  postgres do
    table "events"
    repo AshEvents.TestRepo
  end

  event_log do
    clear_records_for_replay AshEvents.EventLogs.ClearRecords
    persist_actor_primary_key :user_id, AshEvents.Accounts.User

    persist_actor_primary_key :system_actor, AshEvents.EventLogs.SystemActor,
      attribute_type: :string
  end

  replay_overrides do
    replay_override AshEvents.Accounts.User, :create do
      versions [1]
      route_to AshEvents.Accounts.User, :create_v1
      route_to AshEvents.Accounts.RoutedUser, :routed_create
      # Test :as_argument mode - record_id passed as argument to track_user_create
      route_to AshEvents.Accounts.UserCountProjection, :track_user_create, record_id: :as_argument
      # Test :ignore mode - record_id not passed at all for pure aggregates
      route_to AshEvents.Accounts.UserCountProjection, :count_event, record_id: :ignore
    end

    replay_override AshEvents.Accounts.User, :register_with_password do
      versions [1]
      route_to AshEvents.Accounts.User, :register_with_password_replay
    end

    replay_override AshEvents.Accounts.User, :change_password do
      versions [1]
      route_to AshEvents.Accounts.User, :change_password_replay
    end

    replay_override AshEvents.Accounts.User, :confirm do
      versions [1]
      route_to AshEvents.Accounts.User, :confirm_replay
    end

    replay_override AshEvents.Accounts.User, :sign_in_with_magic_link do
      versions [1]
      route_to AshEvents.Accounts.User, :sign_in_with_magic_link_replay
    end

    # Rerouted upsert actions for testing
    replay_override AshEvents.Accounts.Org, :create_or_update do
      versions [1]
      route_to AshEvents.Accounts.Org, :create_or_update_replay
    end

    replay_override AshEvents.Accounts.Upload, :create do
      versions [1]
      route_to AshEvents.Accounts.Upload, :create_replay
    end

    replay_override AshEvents.Accounts.UserRole, :create_or_update do
      versions [1]
      route_to AshEvents.Accounts.UserRole, :create_or_update_replay
    end

    # Project upsert replay override for testing non-writable fields
    replay_override AshEvents.Accounts.Project, :create_or_update do
      versions [1]
      route_to AshEvents.Accounts.Project, :create_or_update_replay
    end
  end

  actions do
    defaults [:read]
  end
end
