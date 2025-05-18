defmodule AshEvents.Test.Events.ClearRecords do
  @moduledoc false
  use AshEvents.ClearRecordsForReplay
  alias AshEvents.TestRepo

  def clear_records!(_opts) do
    {_, nil} = TestRepo.delete_all("user_roles")
    {_, nil} = TestRepo.delete_all("users")
    {_, nil} = TestRepo.delete_all("routed_users")
    :ok
  end
end

defmodule AshEvents.Test.Events.ClearRecordsUuidV7 do
  @moduledoc false
  use AshEvents.ClearRecordsForReplay
  alias AshEvents.TestRepo

  def clear_records!(_opts) do
    {_, nil} = TestRepo.delete_all("users_uuidv7")
    :ok
  end
end
