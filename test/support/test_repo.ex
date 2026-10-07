# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.TestRepo do
  @moduledoc false
  use AshPostgres.Repo, otp_app: :ash_events

  def installed_extensions do
    ["uuid-ossp", "citext", "ash-functions", "btree_gist"]
  end

  def on_transaction_begin(data) do
    send(self(), data)
  end

  def prefer_transaction?, do: false

  def prefer_transaction_for_atomic_updates?, do: false

  # 18: the temporal-replay test resource (test/support/accounts/
  # temporal_coverage.ex) requires PostgreSQL 18's period machinery —
  # `AshPostgres.DataLayer.can?/3` gates the temporal data layer on this
  # floor. Non-temporal test usage is unchanged.
  def min_pg_version do
    %Version{major: 18, minor: 0, patch: 0}
  end

  def all_tenants, do: []
end
