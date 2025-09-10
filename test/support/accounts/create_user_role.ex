defmodule AshEvents.Accounts.User.CreateUserRole do
  @moduledoc false
  alias AshEvents.Accounts
  use Ash.Resource.Change

  def change(changeset, _opts, ctx) do
    changeset
    |> Ash.Changeset.after_action(fn cs, record ->
      opts = Ash.Context.to_opts(ctx)
      role = Ash.Changeset.get_argument(cs, :role)
      Accounts.create_user_role!(%{name: role, user_id: record.id}, opts)
      {:ok, record}
    end)
  end
end
