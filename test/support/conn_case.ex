# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

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
