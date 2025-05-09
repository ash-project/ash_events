defmodule AshEvents.Test.Accounts do
  @moduledoc false
  use Ash.Domain

  resources do
    resource AshEvents.Test.Accounts.User do
      define :get_user_by_id, action: :get_by_id, args: [:id]
      define :create_user, action: :create
      define :create_user_with_atomic, action: :create_with_atomic
      define :update_user, action: :update
      define :update_user_with_atomic, action: :update_with_atomic
      define :destroy_user, action: :destroy
      define :destroy_user_with_atomic, action: :destroy_with_atomic
    end

    resource AshEvents.Test.Accounts.UserRole do
      define :create_user_role, action: :create
      define :update_user_role, action: :update
      define :destroy_user_role, action: :destroy
    end

    resource AshEvents.Test.Accounts.RoutedUser
  end
end
