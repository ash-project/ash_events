# SPDX-FileCopyrightText: 2024 Torkild G. Kjevik
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EventLogs.ClearRecords do
  @moduledoc false
  use AshEvents.ClearRecordsForReplay
  alias AshEvents.TestRepo

  def clear_records!(_opts) do
    {_, nil} = TestRepo.delete_all("user_roles")
    {_, nil} = TestRepo.delete_all("users")
    {_, nil} = TestRepo.delete_all("routed_users")
    {_, nil} = TestRepo.delete_all("users_embedded")
    {_, nil} = TestRepo.delete_all("users_with_auto_attrs")
    :ok
  end
end

defmodule AshEvents.EventLogs.ClearRecordsUuidV7 do
  @moduledoc false
  use AshEvents.ClearRecordsForReplay
  alias AshEvents.TestRepo

  def clear_records!(_opts) do
    {_, nil} = TestRepo.delete_all("users_uuidv7")
    :ok
  end
end

defmodule AshEvents.EventLogs.ClearRecordsCloaked do
  @moduledoc false
  use AshEvents.ClearRecordsForReplay
  alias AshEvents.TestRepo

  def clear_records!(_opts) do
    {_, nil} = TestRepo.delete_all("orgs_cloaked")
    :ok
  end
end

defmodule AshEvents.EventLogs.ClearRecordsStateMachine do
  @moduledoc false
  use AshEvents.ClearRecordsForReplay
  alias AshEvents.TestRepo

  def clear_records!(_opts) do
    {_, nil} = TestRepo.delete_all("org_state_machine")
    :ok
  end
end
