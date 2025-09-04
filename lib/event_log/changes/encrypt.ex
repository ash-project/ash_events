defmodule AshEvents.EventLog.Changes.Encrypt do
  @moduledoc false
  use Ash.Resource.Change

  def change(cs, opts, _ctx) do
    data = Ash.Changeset.get_argument(cs, :data)
    metadata = Ash.Changeset.get_argument(cs, :metadata)
    changed_attributes = Ash.Changeset.get_argument(cs, :changed_attributes)

    vault = opts[:cloak_vault]

    encrypted_data =
      data
      |> Jason.encode!()
      |> vault.encrypt!()
      |> Base.encode64()

    encrypted_metadata =
      metadata
      |> Jason.encode!()
      |> vault.encrypt!()
      |> Base.encode64()

    encrypted_changed_attributes =
      changed_attributes
      |> Jason.encode!()
      |> vault.encrypt!()
      |> Base.encode64()

    cs
    |> Ash.Changeset.change_attribute(:encrypted_data, encrypted_data)
    |> Ash.Changeset.change_attribute(:encrypted_metadata, encrypted_metadata)
    |> Ash.Changeset.change_attribute(:encrypted_changed_attributes, encrypted_changed_attributes)
  end
end
