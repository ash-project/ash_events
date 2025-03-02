defmodule AshEvents.RepoCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      alias AshEvents.TestRepo

      import Ecto
      import Ecto.Query
      import AshEvents.RepoCase

      # and any other stuff
    end
  end

  setup tags do
    :ok = Sandbox.checkout(AshEvents.TestRepo)

    if !tags[:async] do
      Sandbox.mode(AshEvents.TestRepo, {:shared, self()})
    end

    :ok
  end
end
