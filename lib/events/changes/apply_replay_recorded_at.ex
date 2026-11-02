# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Events.Changes.ApplyReplayRecordedAt do
  @moduledoc """
  A change that runs last on every action AshEvents wraps, to set a temporal
  resource's `recorded_at` during replay.

  Replay puts the event's `occurred_at` in the context as
  `ash_events_replay_recorded_at` when it replays an event that captured its
  write's `as_of` onto a temporal resource. This change forces the resource's
  `recorded_at` attribute to it, so the replayed version is stamped with the
  system time of the original write rather than the replay's wall clock.

  It applies under every replay strategy and on the generated upsert replay
  update, which `ApplyChangedAttributes` doesn't cover, and does nothing on a hard
  destroy, which writes no version.
  """
  use Ash.Resource.Change

  @impl true
  def temporal_safe?(_opts), do: true

  # The generated upsert replay update isn't manual, so Ash may upgrade it to an
  # atomic update, which runs this callback instead of `change/3`.
  @impl true
  def atomic(cs, _opts, _ctx) do
    case replay_recorded_at(cs) do
      {attribute, value} -> {:atomic, %{attribute => value}}
      nil -> {:ok, cs}
    end
  end

  @impl true
  def change(cs, _opts, _ctx) do
    case replay_recorded_at(cs) do
      {attribute, value} -> Ash.Changeset.force_change_attribute(cs, attribute, value)
      nil -> cs
    end
  end

  defp replay_recorded_at(cs) do
    attribute = Ash.Resource.Info.temporal_recorded_at(cs.resource)
    value = cs.context[:ash_events_replay_recorded_at]

    if cs.context[:ash_events_replay?] && attribute && value && writes_version?(cs.action) do
      {attribute, value}
    end
  end

  defp writes_version?(%{type: :destroy, soft?: soft?}), do: soft?
  defp writes_version?(_action), do: true
end
