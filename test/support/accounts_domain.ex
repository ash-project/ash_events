defmodule AshEvents.Test.Accounts do
  @moduledoc false
  use Ash.Domain

  resources do
    resource AshEvents.Test.Accounts.User do
      define :get_user_by_id, action: :get_by_id, args: [:id]
      define :create_user, action: :create
    end
  end
end
