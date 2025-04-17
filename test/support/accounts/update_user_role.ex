defmodule AshEvents.Test.Accounts.User.UpdateUserRole do
  alias AshEvents.Test.Accounts
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
