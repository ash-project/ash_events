defmodule AshEvents.Test.ClearRecords do
  use AshEvents.ClearRecordsForReplay
  alias AshEvents.TestRepo

  def clear_records!(_opts) do
    {_, nil} = TestRepo.delete_all("user_roles")
    {_, nil} = TestRepo.delete_all("users")
    :ok
  end
end
