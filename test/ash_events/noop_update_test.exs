# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.NoopUpdateTest do
  @moduledoc false
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts.User
  alias AshEvents.EventLogs.{EventLog, SystemActor}

  test "an update that changes nothing writes no event and keeps updated_at" do
    actor = %SystemActor{name: "test"}

    user =
      User
      |> Ash.Changeset.for_create(:create, %{
        email: "noop@example.com",
        given_name: "Same",
        family_name: "Name"
      })
      |> Ash.create!(actor: actor)

    events_before = Ash.read!(EventLog)

    updated =
      user
      |> Ash.Changeset.for_update(:update_with_map_arg, %{given_name: "Same", family_name: "Name"})
      |> Ash.update!(actor: actor)

    assert Ash.read!(EventLog) |> length() == length(events_before)
    assert updated.updated_at == user.updated_at

    reloaded = Ash.get!(User, user.id, authorize?: false)
    assert reloaded.updated_at == user.updated_at
  end

  test "an update that changes an attribute still writes an event" do
    actor = %SystemActor{name: "test"}

    user =
      User
      |> Ash.Changeset.for_create(:create, %{
        email: "changed@example.com",
        given_name: "Old",
        family_name: "Name"
      })
      |> Ash.create!(actor: actor)

    events_before = Ash.read!(EventLog)

    user
    |> Ash.Changeset.for_update(:update_with_map_arg, %{given_name: "New"})
    |> Ash.update!(actor: actor)

    assert Ash.read!(EventLog) |> length() == length(events_before) + 1
  end

  test "a bulk update that changes nothing writes no event" do
    actor = %SystemActor{name: "test"}

    user =
      User
      |> Ash.Changeset.for_create(:create, %{
        email: "bulk-noop@example.com",
        given_name: "Same",
        family_name: "Name"
      })
      |> Ash.create!(actor: actor)

    events_before = Ash.read!(EventLog)

    %Ash.BulkResult{status: :success} =
      Ash.bulk_update!([user], :update_with_map_arg, %{given_name: "Same"},
        actor: actor,
        strategy: :stream,
        return_errors?: true
      )

    assert Ash.read!(EventLog) |> length() == length(events_before)
    assert Ash.get!(User, user.id, authorize?: false).updated_at == user.updated_at
  end
end
