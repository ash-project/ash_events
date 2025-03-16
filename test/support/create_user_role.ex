defmodule AshEvents.Test.CreateUserRole do
  alias AshEvents.Test.Accounts
  use Ash.Resource.Change

  def change(changeset, _opts, ctx) do
    changeset
    |> Ash.Changeset.after_action(fn _cs, record ->
      opts = Ash.Context.to_opts(ctx)
      Accounts.create_user_role!(%{name: "regular_user", user_id: record.id}, opts)
      {:ok, record}
    end)
  end
end
