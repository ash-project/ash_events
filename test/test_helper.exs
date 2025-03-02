ExUnit.start()
ExUnit.configure(stacktrace_depth: 100)

AshEvents.TestRepo.start_link()

Ecto.Adapters.SQL.Sandbox.mode(AshEvents.TestRepo, :manual)
