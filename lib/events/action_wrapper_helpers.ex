# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Events.ActionWrapperHelpers do
  @moduledoc """
  Helper functions used by the action wrappers.
  """

  @doc """
  Reverses `dump_to_embedded` for a single attribute value.

  Used during replay to convert stored values (e.g., base64-encoded binaries)
  back to their original types before passing them as action input.
  """
  def cast_from_embedded(nil, _attribute), do: nil

  def cast_from_embedded(value, attribute) do
    if embedded_type?(attribute.type) do
      # Embedded resources are stored as partial maps and should be passed
      # through as-is — cast_input handles them correctly during replay.
      value
    else
      case Ash.Type.cast_from_embedded(attribute.type, value, attribute.constraints) do
        {:ok, restored} -> restored
        _ -> value
      end
    end
  end

  defp embedded_type?({:array, type}), do: embedded_type?(type)

  defp embedded_type?(type) do
    type = Ash.Type.get_type(type)
    is_atom(type) and type.embedded?()
  end

  def dump_value(nil, _attribute), do: nil

  def dump_value(values, %{type: {:array, attr_type}} = attribute) do
    item_constraints = attribute.constraints[:items]

    # This is a work around for a bug in Ash.Type.dump_to_embedded/3
    Enum.map(values, fn value ->
      {:ok, dumped_value} = Ash.Type.dump_to_embedded(attr_type, value, item_constraints)
      dumped_value
    end)
  end

  def dump_value(value, attribute) do
    {:ok, dumped_value} = Ash.Type.dump_to_embedded(attribute.type, value, attribute.constraints)
    dumped_value
  end

  def get_occurred_at(changeset, timestamp_attr) do
    case Ash.Changeset.get_attribute(changeset, timestamp_attr) do
      nil ->
        DateTime.utc_now()

      timestamp ->
        timestamp
    end
  end

  @doc """
  Returns the `occurred_at` of a write to a temporal resource, which is system
  time: the changeset's `recorded_at` value, or the wall clock. Returns `nil` for
  a non-temporal resource, whose wrappers keep their own `occurred_at` rules.

  Call it before the data layer write. When the resource has a `recorded_at`
  attribute that the changeset doesn't change, it is set to the wall clock on the
  returned changeset, so the written version and the event agree. `fetch_change`
  rather than `get_attribute`, because on an update the latter falls back to the
  old version's value.
  """
  @spec temporal_occurred_at(Ash.Changeset.t()) :: {Ash.Changeset.t(), DateTime.t() | nil}
  def temporal_occurred_at(changeset) do
    resource = changeset.resource

    cond do
      not Ash.Resource.Info.temporal?(resource) ->
        {changeset, nil}

      recorded_at = Ash.Resource.Info.temporal_recorded_at(resource) ->
        stamp_recorded_at(changeset, recorded_at)

      true ->
        {changeset, DateTime.utc_now()}
    end
  end

  @doc """
  Applies the update defaults to an update or soft-destroy changeset of a
  temporal resource, so `updated_at` follows `as_of` and `recorded_at` is stamped.

  Ash applies them before calling a manual update on its single-record path, but
  not on its manual single-changeset bulk path (`Ash.Actions.Update.Bulk`), so a
  streamed bulk update would keep the old `updated_at` and replay differently.
  Attributes the changeset already changes are left alone, so this is a no-op
  where Ash has applied the defaults. Non-temporal resources are left as they
  are.
  """
  @spec apply_temporal_update_defaults(Ash.Changeset.t()) :: Ash.Changeset.t()
  def apply_temporal_update_defaults(changeset) do
    if Ash.Resource.Info.temporal?(changeset.resource) do
      Ash.Changeset.set_defaults(changeset, :update, true)
    else
      changeset
    end
  end

  defp stamp_recorded_at(changeset, recorded_at) do
    case Ash.Changeset.fetch_change(changeset, recorded_at) do
      {:ok, %DateTime{} = occurred_at} ->
        {changeset, occurred_at}

      _ ->
        changeset =
          Ash.Changeset.force_change_attribute(changeset, recorded_at, DateTime.utc_now())

        {changeset, Ash.Changeset.get_attribute(changeset, recorded_at)}
    end
  end

  @doc """
  The application time of a write, as the event log's `as_of` and `as_of_range`
  attributes store it. Both are `nil` for a non-temporal resource, whatever
  `as_of` the changeset inherited.
  """
  @spec as_of_params(Ash.Changeset.t()) :: %{
          as_of: DateTime.t() | nil,
          as_of_range: Ash.Range.t() | nil
        }
  def as_of_params(changeset) do
    if Ash.Resource.Info.temporal?(changeset.resource) do
      case changeset.as_of do
        %DateTime{} = as_of ->
          %{as_of: as_of, as_of_range: nil}

        %Ash.Range{} = as_of_range ->
          %{as_of: nil, as_of_range: as_of_range}

        other ->
          raise ArgumentError,
                "expected the as_of of a write to the temporal resource " <>
                  "#{inspect(changeset.resource)} to be a DateTime or an Ash.Range, " <>
                  "got: #{inspect(other)}"
      end
    else
      %{as_of: nil, as_of_range: nil}
    end
  end

  defp cast_and_dump_value(value, attr_or_arg) do
    case Ash.Type.cast_input(attr_or_arg.type, value, attr_or_arg.constraints) do
      {:ok, cast_value} -> dump_value(cast_value, attr_or_arg)
      {:error, _} -> dump_value(value, attr_or_arg)
    end
  end

  @doc """
  Writes the event for `changeset` and returns the notifications it produced.

  The event is created with `return_notifications?: true`, which makes Ash hand
  the notifications back instead of dispatching them. Callers must therefore
  pass them on to Ash in the shape their action type expects, or notifiers on
  the event log resource never fire.
  """
  def create_event!(changeset, original_params, occurred_at, module_opts, opts) do
    pg_repo = AshPostgres.DataLayer.Info.repo(changeset.resource)

    if pg_repo do
      lock_key =
        module_opts[:advisory_lock_key_generator].generate_key!(
          changeset,
          module_opts[:advisory_lock_key_default]
        )

      case Code.ensure_loaded(Ecto.Adapters.SQL) do
        {:module, _} ->
          # `query!` so a failed lock acquisition (deadlock victim, lock_timeout)
          # surfaces with its real error code. Discarding the result leaves the
          # transaction aborted and the event insert below fails with a
          # misleading 25P02 instead.
          if is_list(lock_key) do
            [key1, key2] = lock_key

            Ecto.Adapters.SQL.query!(pg_repo, "SELECT pg_advisory_xact_lock($1, $2)", [key1, key2])
          else
            Ecto.Adapters.SQL.query!(pg_repo, "SELECT pg_advisory_xact_lock($1)", [lock_key])
          end

        {:error, _} ->
          raise "Ecto.Adapters.SQL not available when trying to set advisory lock"
      end
    end

    event_log_resource = module_opts[:event_log]

    params =
      original_params
      |> Enum.reduce(%{}, fn {key, value}, acc ->
        key =
          if is_binary(key) do
            try do
              String.to_existing_atom(key)
            rescue
              ArgumentError -> nil
            end
          else
            key
          end

        cond do
          attr = Ash.Resource.Info.attribute(changeset.resource, key) ->
            if not attr.sensitive? or AshEvents.EventLog.Info.cloaked?(event_log_resource) do
              Map.put(acc, key, cast_and_dump_value(value, attr))
            else
              Map.put(acc, key, nil)
            end

          arg = Enum.find(changeset.action.arguments, &(&1.name == key)) ->
            if not arg.sensitive? or AshEvents.EventLog.Info.cloaked?(event_log_resource) do
              Map.put(acc, key, cast_and_dump_value(value, arg))
            else
              Map.put(acc, key, nil)
            end

          true ->
            acc
        end
      end)

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

    # Calculate changed attributes from the final changeset state
    original_params = Map.get(changeset.context, :original_params, %{})
    original_param_keys = MapSet.new(Map.keys(original_params))

    # belongs_to FK attributes must always be captured in changed_attributes,
    # even when their name matches an original param key (e.g., argument :user_id
    # and FK attribute :user_id). During replay, managed relationships are skipped
    # entirely, so the FK must come from changed_attributes.
    belongs_to_fk_attrs =
      changeset.resource
      |> Ash.Resource.Info.relationships()
      |> Enum.filter(&(&1.type == :belongs_to))
      |> Enum.map(& &1.source_attribute)
      |> MapSet.new()

    changed_attributes =
      Enum.reduce(changeset.attributes, %{}, fn {attr_name, value}, acc ->
        is_belongs_to_fk = MapSet.member?(belongs_to_fk_attrs, attr_name)

        if not is_belongs_to_fk and
             (MapSet.member?(original_param_keys, attr_name) or
                MapSet.member?(original_param_keys, to_string(attr_name))) do
          acc
        else
          case Ash.Resource.Info.attribute(changeset.resource, attr_name) do
            nil -> acc
            attr -> Map.put(acc, attr_name, dump_value(value, attr))
          end
        end
      end)

    event_params =
      %{
        data: params,
        record_id: record_id,
        resource: changeset.resource,
        action: module_opts[:action],
        action_type: changeset.action_type,
        metadata: metadata,
        version: module_opts[:version],
        occurred_at: occurred_at,
        changed_attributes: changed_attributes
      }

    event_params =
      if AshEvents.EventLog.Info.event_log_record_as_of?(event_log_resource) do
        Map.merge(event_params, as_of_params(changeset))
      else
        event_params
      end

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
    |> Ash.Changeset.for_create(
      :create,
      event_params,
      event_log_opts(opts) ++ [authorize?: false]
    )
    |> then(fn cs ->
      if has_atomics? do
        Ash.Changeset.add_error(cs, atomics_error())
      else
        cs
      end
    end)
    |> Ash.create!(authorize?: false, return_notifications?: true)
    |> then(fn {_event, notifications} -> notifications end)
  end

  # A temporal write puts its instant in the shared context (`shared.as_of`),
  # which `Ash.Context.to_opts/1` hands on and `Ash.Changeset.set_context/2`
  # copies to the top level, where it becomes the changeset's `as_of`. The event
  # log is never temporal: without this, its `&DateTime.utc_now/0` defaults would
  # resolve to the tracked write's application time.
  defp event_log_opts(opts) do
    context =
      opts
      |> Keyword.get(:context, %{})
      |> Map.delete(:as_of)
      |> then(fn
        %{shared: shared} = context when is_map(shared) ->
          %{context | shared: Map.delete(shared, :as_of)}

        context ->
          context
      end)

    opts
    |> Keyword.delete(:as_of)
    |> Keyword.put(:context, context)
  end

  @doc """
  The error returned when an event-tracked action carries atomic changes, which
  cannot be recorded in an event.
  """
  def atomics_error do
    Ash.Error.Changes.InvalidChanges.exception(
      message: "atomic changes are not compatible with ash_events"
    )
  end
end
