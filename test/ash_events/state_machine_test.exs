defmodule AshEvents.StateMachineTest do
  alias AshEvents.Test.Events.SystemActor
  use AshEvents.RepoCase, async: false

  alias AshEvents.Test.Accounts
  alias AshEvents.Test.Events

  test "handles ash_state_machine validations" do
    actor = %SystemActor{name: "system"}

    org =
      Accounts.create_org_state_machine!(%{name: "Test State Machine"},
        actor: actor
      )

    Accounts.set_org_state_machine_inactive!(org, actor: actor)
    Events.replay_events_state_machine!([])
  end
end
