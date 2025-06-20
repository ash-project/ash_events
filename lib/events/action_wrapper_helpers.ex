defmodule AshEvents.Events.ActionWrapperHelpers do
  @moduledoc """
  Helper functions used by the action wrappers.
  """

  def create_event!(changeset, original_params, module_opts, opts) do
    pg_repo = AshPostgres.DataLayer.Info.repo(changeset.resource)

    if pg_repo do
      lock_key =
        module_opts[:advisory_lock_key_generator].generate_key!(
          changeset,
          module_opts[:advisory_lock_key_default]
        )

      if is_list(lock_key) do
        [key1, key2] = lock_key
        Ecto.Adapters.SQL.query(pg_repo, "SELECT pg_advisory_xact_lock($1, $2)", [key1, key2])
      else
        Ecto.Adapters.SQL.query(pg_repo, "SELECT pg_advisory_xact_lock($1)", [lock_key])
      end
    end

    params =
      changeset.attributes
      |> Map.merge(changeset.arguments)
      |> Map.merge(original_params)
      |> Map.take(changeset.action.accept ++ Enum.map(changeset.action.arguments, & &1.name))

    event_log_resource = module_opts[:event_log]
    [primary_key] = Ash.Resource.Info.primary_key(changeset.resource)
    persist_actor_primary_keys = AshEvents.EventLog.Info.event_log(event_log_resource)
    actor = opts[:actor]

    record_id =
      if changeset.action_type == :create do
        Map.get(changeset.attributes, primary_key)
      else
        Map.get(changeset.data, primary_key)
      end

    metadata = Map.get(changeset.context, :ash_events_metadata, %{})

    event_params =
      %{
        data: params,
        record_id: record_id,
        resource: changeset.resource,
        action: module_opts[:action],
        action_type: changeset.action_type,
        metadata: metadata,
        version: module_opts[:version]
      }

    event_params =
      Enum.reduce(persist_actor_primary_keys, event_params, fn persist_actor_primary_key, input ->
        if is_struct(actor) and actor.__struct__ == persist_actor_primary_key.destination do
          primary_key = Map.get(actor, hd(Ash.Resource.Info.primary_key(actor.__struct__)))
          Map.put(input, persist_actor_primary_key.name, primary_key)
        else
          input
        end
      end)

    has_atomics? = not Enum.empty?(changeset.atomics)

    event_log_resource
    |> Ash.Changeset.for_create(:create, event_params, opts)
    |> then(fn cs ->
      if has_atomics? do
        Ash.Changeset.add_error(
          cs,
          Ash.Error.Changes.InvalidChanges.exception(
            message: "atomic changes are not compatible with ash_events"
          )
        )
      else
        cs
      end
    end)
    |> Ash.create!()
  end
end
