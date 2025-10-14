# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.TestApp do
  @moduledoc false
  def start(_type, _args) do
    children = [
      AshEvents.TestRepo,
      AshEvents.Vault,
      {AshAuthentication.Supervisor, otp_app: :ash_events}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AshEvents.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
