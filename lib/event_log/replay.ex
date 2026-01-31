# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EventLog.Actions.Replay do
  @moduledoc """
  Action module used by the event log resource to replay events.
  """
  require Ash.Query
  require Logger

  # For normal replay (same resource/action), we use the configured strategy
  defp get_replay_strategy(resource, action_name) do
    replay_config = AshEvents.Events.Info.events_replay_non_input_attribute_changes!(resource)
    Keyword.get(replay_config, action_name, :force_change)
  end

  # For normal replay: prepare input based on strategy
  defp prepare_replay_input(event, resource, action_name) do
    changed_attributes = Map.get(event, :changed_attributes, %{})
    replay_strategy = get_replay_strategy(resource, action_name)

    case replay_strategy do
      :as_arguments ->
        Map.merge(event.data, changed_attributes)

      :force_change ->
        event.data
    end
  end

  # For normal replay: include changed_attributes in context for ApplyChangedAttributes
  defp prepare_replay_context(event) do
    changed_attributes = Map.get(event, :changed_attributes, %{})

    %{
      ash_events_replay?: true,
      changed_attributes: changed_attributes
    }
  end

  # For rerouted replay: pass the original input data plus any changed_attributes
  # that the target action explicitly accepts.
  #
  # The philosophy: only pass input, let new action compute derived values.
  # But some computed values can't be recomputed (e.g., email from expired token,
  # hashed_password when plain password is gone). By explicitly accepting such
  # fields in the replay action, the developer signals they need them.
  #
  # Identity (primary key) and timestamps are handled separately via force_change.
  #
  # Important: We filter event.data to only include keys the action accepts.
  # This allows routing events to completely different resources (projections)
  # that have different attributes.
  defp prepare_rerouted_input(event, action) do
    changed_attributes = Map.get(event, :changed_attributes, %{})
    action_accepts = MapSet.new(action.accept || [])

    # Also collect argument names so we don't filter out valid arguments
    action_arguments =
      (action.arguments || [])
      |> Enum.map(& &1.name)
      |> MapSet.new()

    valid_keys = MapSet.union(action_accepts, action_arguments)

    # Filter event.data to only include keys the action accepts or has as arguments
    filtered_data =
      event.data
      |> Enum.filter(fn {key, _value} ->
        key_atom = if is_binary(key), do: String.to_existing_atom(key), else: key
        MapSet.member?(valid_keys, key_atom)
      end)
      |> Map.new()

    # Add any changed_attributes that:
    # 1. Are explicitly accepted by the action
    # 2. Are NOT already in event.data (don't override input)
    additional_from_changed =
      changed_attributes
      |> Enum.filter(fn {key, _value} ->
        attr_name = if is_binary(key), do: String.to_existing_atom(key), else: key
        MapSet.member?(action_accepts, attr_name) and not Map.has_key?(event.data, key)
      end)
      |> Map.new()

    Map.merge(filtered_data, additional_from_changed)
  end

  # For rerouted replay: minimal context, no changed_attributes
  # (the new action's logic should compute values, not use old computed values)
  defp prepare_rerouted_context do
    %{ash_events_replay?: true}
  end

  # Force change identity and timestamp attributes for rerouted create replays.
  # This ensures the record has the correct id and timestamps regardless of
  # what the new action's changes might compute.
  defp force_change_identity_and_timestamps(changeset, event, resource) do
    [primary_key] = Ash.Resource.Info.primary_key(resource)

    # Get configured timestamp attributes from the Events DSL
    create_timestamp_attr =
      case AshEvents.Events.Info.events_create_timestamp(resource) do
        {:ok, attr} -> attr
        :error -> nil
      end

    update_timestamp_attr =
      case AshEvents.Events.Info.events_update_timestamp(resource) do
        {:ok, attr} -> attr
        :error -> nil
      end

    # Build the map of attributes to force change
    attrs_to_force =
      %{primary_key => event.record_id}
      |> maybe_add_timestamp(create_timestamp_attr, event.occurred_at)
      |> maybe_add_timestamp(update_timestamp_attr, event.occurred_at)

    Ash.Changeset.force_change_attributes(changeset, attrs_to_force)
  end

  # Force change only the update_timestamp for rerouted update replays.
  # The record already has its identity (id), we just need to restore the timestamp.
  defp force_change_update_timestamp(changeset, event, resource) do
    update_timestamp_attr =
      case AshEvents.Events.Info.events_update_timestamp(resource) do
        {:ok, attr} -> attr
        :error -> nil
      end

    if update_timestamp_attr do
      Ash.Changeset.force_change_attributes(changeset, %{update_timestamp_attr => event.occurred_at})
    else
      changeset
    end
  end

  defp maybe_add_timestamp(attrs, nil, _value), do: attrs
  defp maybe_add_timestamp(attrs, attr_name, value), do: Map.put(attrs, attr_name, value)

  defp get_record_if_exists(resource, record_id, opts) do
    case Ash.get(resource, record_id, opts) do
      {:ok, record} -> {:ok, record}
      {:error, _} -> {:error, :not_found}
    end
  end

  defp replay_as_create(event, resource, action, opts, rerouted?, record_id_mode) do
    action_struct =
      if is_atom(action),
        do: Ash.Resource.Info.action(resource, action),
        else: action

    action_name = action_struct.name

    {input, context} =
      if rerouted? do
        {prepare_rerouted_input(event, action_struct), prepare_rerouted_context()}
      else
        {prepare_replay_input(event, resource, action_name), prepare_replay_context(event)}
      end

    merged_context = Map.merge(opts[:context] || %{}, context)
    updated_opts = Keyword.put(opts, :context, merged_context)
    changeset = Ash.Changeset.for_create(resource, action, input, updated_opts)

    # For rerouted replays with :force_change_attribute mode, force change identity
    # (primary key) and timestamps. The new action's changes compute everything else.
    # For normal replays, ApplyChangedAttributes handles this via the context.
    changeset =
      if rerouted? and record_id_mode == :force_change_attribute do
        force_change_identity_and_timestamps(changeset, event, resource)
      else
        changeset
      end

    Ash.create!(changeset)

    :ok
  end

  # For rerouted upsert replay when record exists
  # Updates only the fields specified in the action's upsert_fields.
  defp replay_rerouted_upsert_as_update(event, resource, action_struct, existing_record, opts) do
    context = prepare_rerouted_context()

    # Find the update action first so we can filter by its accept list
    update_action = find_update_action_for_rerouted_upsert(resource)

    # Prepare input using the update action's accept list to determine
    # which changed_attributes should be included
    input = prepare_rerouted_input(event, update_action)

    # Determine which fields to update based on upsert_fields
    fields_to_update = get_upsert_fields(action_struct, resource)

    # Get the fields the update action accepts
    update_accepts =
      (update_action.accept || [])
      |> MapSet.new()

    # Filter input to only include:
    # 1. Fields from upsert_fields (or all if :replace_all)
    # 2. AND fields that the update action accepts
    filtered_input =
      input
      |> Enum.filter(fn {key, _value} ->
        field_name = if is_binary(key), do: String.to_existing_atom(key), else: key

        in_upsert_fields =
          fields_to_update == :all or field_name in fields_to_update

        in_accept_list = MapSet.member?(update_accepts, field_name)

        in_upsert_fields and in_accept_list
      end)
      |> Map.new()

    # If there are no fields to update, skip
    if filtered_input == %{} do
      :ok
    else
      merged_context = Map.merge(opts[:context] || %{}, context)
      updated_opts = Keyword.put(opts, :context, merged_context)

      changeset =
        Ash.Changeset.for_update(
          existing_record,
          update_action.name,
          filtered_input,
          updated_opts
        )

      # Force change update_timestamp to preserve the original event time
      changeset = force_change_update_timestamp(changeset, event, resource)

      Ash.update!(changeset)

      :ok
    end
  end

  defp get_upsert_fields(action_struct, resource) do
    case action_struct.upsert_fields do
      nil ->
        # Default: update all accepted fields
        action_struct.accept || []

      :replace_all ->
        :all

      {:replace, fields} when is_list(fields) ->
        fields

      {:replace_all_except, except_fields} when is_list(except_fields) ->
        resource
        |> Ash.Resource.Info.attributes()
        |> Enum.map(& &1.name)
        |> Enum.reject(&(&1 in except_fields))

      fields when is_list(fields) ->
        fields

      _ ->
        :all
    end
  end

  defp find_update_action_for_rerouted_upsert(resource) do
    actions = Ash.Resource.Info.actions(resource)

    # Filter out auto-generated replay update actions - we want user-defined actions
    user_update_actions =
      Enum.filter(actions, fn action ->
        action.type == :update and
          not String.starts_with?(to_string(action.name), "ash_events_replay_")
      end)

    # Preference order:
    # 1. Primary update action
    # 2. Action named exactly :update (standard naming convention)
    # 3. Any other update action
    primary_update = Enum.find(user_update_actions, & &1.primary?)
    standard_update = Enum.find(user_update_actions, &(&1.name == :update))

    cond do
      primary_update ->
        primary_update

      standard_update ->
        standard_update

      true ->
        case Enum.find(user_update_actions, fn _ -> true end) do
          nil ->
            raise "No update action found on #{resource} for rerouted upsert replay. " <>
                    "Please add an update action to handle upsert updates during replay."

          action ->
            action
        end
    end
  end

  # For normal (non-rerouted) upsert replay when record exists
  defp replay_upsert_as_update(event, resource, action, existing_record, opts) do
    action_name = if is_atom(action), do: action, else: action.name

    # Use the auto-generated update action for this upsert
    replay_action_name = String.to_existing_atom("ash_events_replay_#{action_name}_update")
    actions = Ash.Resource.Info.actions(resource)

    update_action =
      case Enum.find(actions, &(&1.name == replay_action_name and &1.type == :update)) do
        nil ->
          raise "Expected auto-generated replay update action #{replay_action_name} for upsert action #{action_name} on #{resource}, but it was not found. This indicates a bug in the AshEvents transformer."

        action ->
          action
      end

    # For upsert replay as update, always use force_change behavior:
    # - Pass only event.data as input (not changed_attributes)
    # - Apply changed_attributes via ApplyChangedAttributes change
    # This ensures the record ends up in the same state as if the create path was taken.
    input = event.data
    context = prepare_replay_context(event)
    merged_context = Map.merge(opts[:context] || %{}, context)
    updated_opts = Keyword.put(opts, :context, merged_context)

    changeset = Ash.Changeset.for_update(existing_record, update_action.name, input, updated_opts)
    Ash.update!(changeset)

    :ok
  end

  # For rerouted events with record_id mode other than :force_change_attribute,
  # we call the target action as a create action regardless of the original event type.
  # This enables routing events to projection resources that don't track individual records.
  defp handle_action(event, resource, action, opts, true = _rerouted?, record_id_mode)
       when record_id_mode in [:as_argument, :ignore] do
    replay_as_create_for_projection(event, resource, action, opts, record_id_mode)
  end

  defp handle_action(
         %{action_type: :create} = event,
         resource,
         action,
         opts,
         rerouted?,
         record_id_mode
       ) do
    action_struct = Ash.Resource.Info.action(resource, action)

    if rerouted? do
      # For rerouted creates, check if this is an upsert action and record exists
      if action_struct.upsert? do
        case get_record_if_exists(resource, event.record_id, opts) do
          {:ok, existing_record} ->
            # Record exists - update with upsert_fields as defined in the action
            replay_rerouted_upsert_as_update(
              event,
              resource,
              action_struct,
              existing_record,
              opts
            )

          {:error, :not_found} ->
            # Record doesn't exist, create it
            replay_as_create(event, resource, action, opts, rerouted?, record_id_mode)
        end
      else
        # Non-upsert rerouted create - just call the action
        replay_as_create(event, resource, action, opts, rerouted?, record_id_mode)
      end
    else
      if action_struct.upsert? do
        # For normal upsert replay, check if record exists to use proper action
        case get_record_if_exists(resource, event.record_id, opts) do
          {:ok, existing_record} ->
            replay_upsert_as_update(event, resource, action, existing_record, opts)

          {:error, :not_found} ->
            replay_as_create(event, resource, action, opts, rerouted?, record_id_mode)
        end
      else
        replay_as_create(event, resource, action_struct, opts, rerouted?, record_id_mode)
      end
    end
  end

  defp handle_action(
         %{action_type: :update} = event,
         resource,
         action,
         opts,
         rerouted?,
         _record_id_mode
       ) do
    action_struct =
      if is_atom(action),
        do: Ash.Resource.Info.action(resource, action),
        else: action

    action_name = action_struct.name

    case Ash.get(resource, event.record_id, opts) do
      {:ok, record} ->
        {input, context} =
          if rerouted? do
            {prepare_rerouted_input(event, action_struct), prepare_rerouted_context()}
          else
            {prepare_replay_input(event, resource, action_name), prepare_replay_context(event)}
          end

        merged_context = Map.merge(opts[:context] || %{}, context)
        updated_opts = Keyword.put(opts, :context, merged_context)
        changeset = Ash.Changeset.for_update(record, action, input, updated_opts)

        # For rerouted replays, force change update_timestamp to preserve original event time.
        # For normal replays, ApplyChangedAttributes handles this via the context.
        changeset =
          if rerouted? do
            force_change_update_timestamp(changeset, event, resource)
          else
            changeset
          end

        Ash.update!(changeset)

        :ok

      _ ->
        Logger.warning(
          "Record #{event.record_id} not found when processing update event #{event.id}"
        )
    end
  end

  defp handle_action(
         %{action_type: :destroy} = event,
         resource,
         action,
         opts,
         rerouted?,
         _record_id_mode
       ) do
    case Ash.get(resource, event.record_id, opts) do
      {:ok, record} ->
        context =
          if rerouted? do
            prepare_rerouted_context()
          else
            prepare_replay_context(event)
          end

        merged_context = Map.merge(opts[:context] || %{}, context)
        updated_opts = Keyword.put(opts, :context, merged_context)
        changeset = Ash.Changeset.for_destroy(record, action, %{}, updated_opts)
        Ash.destroy!(changeset)

        :ok

      _ ->
        Logger.warning(
          "Record #{event.record_id} not found when processing destroy event #{event.id}"
        )
    end
  end

  # For projection-style rerouted actions where record_id is passed as argument or ignored.
  # This calls the target action as a create, regardless of the original event type.
  defp replay_as_create_for_projection(event, resource, action, opts, record_id_mode) do
    action_struct =
      if is_atom(action),
        do: Ash.Resource.Info.action(resource, action),
        else: action

    # Start with event.data, add accepted changed_attributes
    input = prepare_rerouted_input(event, action_struct)

    # Add record_id as argument if mode is :as_argument
    input =
      if record_id_mode == :as_argument do
        Map.put(input, :record_id, event.record_id)
      else
        input
      end

    context = prepare_rerouted_context()
    merged_context = Map.merge(opts[:context] || %{}, context)
    updated_opts = Keyword.put(opts, :context, merged_context)

    changeset = Ash.Changeset.for_create(resource, action, input, updated_opts)
    Ash.create!(changeset)

    :ok
  end

  def run(input, run_opts, ctx) do
    opts =
      Ash.Context.to_opts(ctx,
        authorize?: false
      )

    ctx = Map.put(opts[:context] || %{}, :ash_events_replay?, true)
    opts = Keyword.replace(opts, :context, ctx)

    case AshEvents.EventLog.Info.event_log_clear_records_for_replay(input.resource) do
      {:ok, module} ->
        module.clear_records!(opts)

      :error ->
        raise "clear_records_for_replay must be specified on #{input.resource} when doing a replay."
    end

    cloak_vault =
      case AshEvents.EventLog.Info.event_log_cloak_vault(input.resource) do
        {:ok, vault} -> vault
        :error -> nil
      end

    overrides = run_opts[:overrides]
    point_in_time = input.arguments[:point_in_time]
    last_event_id = input.arguments[:last_event_id]

    cond do
      last_event_id != nil ->
        input.resource
        |> Ash.Query.filter(id <= ^last_event_id)

      point_in_time != nil ->
        input.resource
        |> Ash.Query.filter(occurred_at <= ^point_in_time)

      true ->
        input.resource
    end
    |> Ash.Query.sort(id: :asc)
    |> then(fn query ->
      if cloak_vault,
        do: Ash.Query.load(query, [:data, :metadata, :changed_attributes]),
        else: query
    end)
    |> Ash.stream!(opts)
    |> Stream.map(fn event ->
      override =
        Enum.find(overrides, fn
          %{event_resource: event_resource, event_action: event_action, versions: versions} ->
            event.resource == event_resource and
              event.action == event_action and
              event.version in versions
        end)

      if override do
        # Rerouted actions: call target action with configured record_id handling
        Enum.each(override.route_to, fn route_to ->
          record_id_mode = route_to.record_id || :force_change_attribute

          handle_action(
            event,
            route_to.resource,
            route_to.action,
            opts,
            _rerouted? = true,
            record_id_mode
          )
        end)
      else
        # Normal replay: use configured strategy with force_change support
        handle_action(event, event.resource, event.action, opts, _rerouted? = false, nil)
      end
    end)
    |> Stream.take_while(fn
      :ok -> true
      _res -> false
    end)
    |> Enum.reduce_while(:ok, fn
      :ok, _acc -> {:cont, :ok}
      error, _acc -> {:halt, error}
    end)
  end
end
