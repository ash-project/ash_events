# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

ExUnit.start()
ExUnit.configure(stacktrace_depth: 100)

AshEvents.TestRepo.start_link()

Ecto.Adapters.SQL.Sandbox.mode(AshEvents.TestRepo, :manual)
