# SPDX-FileCopyrightText: 2024 Torkild G. Kjevik
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Accounts.User.UpdateUserRole do
  @moduledoc false
  alias AshEvents.Accounts
  use Ash.Resource.Change

  def change(changeset, _opts, ctx) do
    changeset
    |> Ash.Changeset.after_action(fn cs, record ->
      role = Ash.Changeset.get_argument(cs, :role)

      if role do
        opts = Ash.Context.to_opts(ctx)
        user = Ash.load!(record, [:user_role], opts)
        Accounts.update_user_role!(user.user_role, %{name: role}, opts)
        {:ok, record}
      else
        {:ok, record}
      end
    end)
  end
end
