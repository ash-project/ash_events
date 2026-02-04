# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Accounts do
  @moduledoc false
  use Ash.Domain

  resources do
    resource AshEvents.Accounts.User do
      define :get_user_by_id, action: :get_by_id, args: [:id]
      define :create_user, action: :create
      define :create_user_with_atomic, action: :create_with_atomic
      define :create_user_with_form, action: :create_with_form
      define :create_user_upsert, action: :create_upsert
      define :update_user, action: :update
      define :update_user_with_atomic, action: :update_with_atomic
      define :destroy_user, action: :destroy
      define :destroy_user_with_atomic, action: :destroy_with_atomic
    end

    resource AshEvents.Accounts.Token

    resource AshEvents.Accounts.UserUuidV7 do
      define :get_user_uuidv7_by_id, action: :get_by_id, args: [:id]
      define :create_user_uuidv7, action: :create
      define :update_user_uuidv7, action: :update
      define :destroy_user_uuidv7, action: :destroy
    end

    resource AshEvents.Accounts.UserEmbedded do
      define :get_user_embedded_by_id, action: :get_by_id, args: [:id]
      define :create_user_embedded, action: :create
      define :update_user_embedded, action: :update
      define :destroy_user_embedded, action: :destroy
    end

    resource AshEvents.Accounts.UserRole do
      define :create_user_role, action: :create
      define :update_user_role, action: :update
      define :destroy_user_role, action: :destroy
    end

    resource AshEvents.Accounts.RoutedUser

    resource AshEvents.Accounts.Org do
      define :create_org, action: :create
      define :reactivate_org, action: :reactivate
    end

    resource AshEvents.Accounts.OrgDetails do
      define :create_org_details, action: :create
    end

    resource AshEvents.Accounts.OrgCloaked do
      define :create_org_cloaked, action: :create
      define :update_org_cloaked, action: :update
    end

    resource AshEvents.Accounts.OrgStateMachine do
      define :create_org_state_machine, action: :create
      define :set_org_state_machine_active, action: :set_active
      define :set_org_state_machine_inactive, action: :set_inactive
    end

    resource AshEvents.Accounts.UserWithAutoAttrs do
      define :create_user_with_auto_attrs, action: :create
      define :update_user_with_auto_attrs, action: :update
      define :destroy_user_with_auto_attrs, action: :destroy
    end

    resource AshEvents.Accounts.Upload do
      define :create_upload, action: :create
      define :mark_upload_uploaded, action: :mark_uploaded
      define :mark_upload_skipped, action: :mark_skipped
    end

    resource AshEvents.Accounts.Article do
      define :create_article, action: :create
      define :update_article, action: :update
      define :archive_article, action: :archive
      define :unarchive_article, action: :unarchive
      define :destroy_article, action: :destroy
      define :soft_destroy_article, action: :soft_destroy
    end

    resource AshEvents.Accounts.UserNonWritableId do
      define :get_user_non_writable_id_by_id, action: :get_by_id, args: [:id]
      define :create_user_non_writable_id, action: :create
      define :update_user_non_writable_id, action: :update
      define :destroy_user_non_writable_id, action: :destroy
    end
  end
end
