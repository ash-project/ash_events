# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EventLog.Transformers.AddAttributes do
  @moduledoc false
  use Spark.Dsl.Transformer

  # Canonical list of fields added by AshEvents extension
  @ash_events_fields [
    :id,
    :record_id,
    :version,
    :occurred_at,
    :as_of,
    :as_of_range,
    :resource,
    :action,
    :action_type,
    :metadata,
    :data,
    :changed_attributes,
    :encrypted_metadata,
    :encrypted_data,
    :encrypted_changed_attributes
  ]

  def before?(_), do: true

  @doc "Returns the canonical list of fields added by the AshEvents extension"
  def ash_events_fields, do: @ash_events_fields

  def transform(dsl) do
    record_primary_id_type = AshEvents.EventLog.Info.event_log_record_id_type!(dsl)
    persist_actor_primary_keys = AshEvents.EventLog.Info.event_log(dsl)
    public_fields = AshEvents.EventLog.Info.event_log_public_fields!(dsl)

    cloaked? = AshEvents.EventLog.Info.cloaked?(dsl)
    record_as_of? = AshEvents.EventLog.Info.event_log_record_as_of?(dsl)

    case AshEvents.EventLog.Info.event_log_primary_key_type!(dsl) do
      :integer ->
        Ash.Resource.Builder.add_attribute(dsl, :id, :integer,
          primary_key?: true,
          writable?: false,
          generated?: true,
          allow_nil?: false,
          public?: public_field?(public_fields, :id)
        )

      Ash.Type.UUIDv7 ->
        Ash.Resource.Builder.add_attribute(dsl, :id, Ash.Type.UUIDv7,
          primary_key?: true,
          writable?: false,
          allow_nil?: false,
          default: &Ash.UUIDv7.generate/0,
          public?: public_field?(public_fields, :id)
        )
    end
    |> Ash.Resource.Builder.add_attribute(:record_id, record_primary_id_type,
      allow_nil?: false,
      public?: public_field?(public_fields, :record_id)
    )
    |> Ash.Resource.Builder.add_attribute(:version, :integer,
      allow_nil?: false,
      default: 1,
      public?: public_field?(public_fields, :version)
    )
    |> then(fn dsl ->
      if cloaked? do
        dsl
        |> Ash.Resource.Builder.add_attribute(:encrypted_metadata, :binary,
          allow_nil?: false,
          public?: public_field?(public_fields, :encrypted_metadata)
        )
        |> Ash.Resource.Builder.add_attribute(:encrypted_data, :binary,
          allow_nil?: false,
          public?: public_field?(public_fields, :encrypted_data)
        )
        |> Ash.Resource.Builder.add_attribute(:encrypted_changed_attributes, :binary,
          allow_nil?: false,
          public?: public_field?(public_fields, :encrypted_changed_attributes)
        )
        |> Ash.Resource.Builder.add_calculation(
          :data,
          :map,
          {AshEvents.EventLog.Calculations.Decrypt, [field: :encrypted_data]},
          public?: public_field?(public_fields, :data),
          allow_nil?: false,
          sensitive?: true,
          description: "This is where the action params (attrs & args) are stored."
        )
        |> Ash.Resource.Builder.add_calculation(
          :changed_attributes,
          :map,
          {AshEvents.EventLog.Calculations.Decrypt, [field: :encrypted_changed_attributes]},
          public?: public_field?(public_fields, :changed_attributes),
          allow_nil?: false,
          sensitive?: true,
          description:
            "Attributes that were changed but not present in the original action input."
        )
        |> Ash.Resource.Builder.add_calculation(
          :metadata,
          :map,
          {AshEvents.EventLog.Calculations.Decrypt, [field: :encrypted_metadata]},
          public?: public_field?(public_fields, :metadata),
          allow_nil?: false,
          sensitive?: true,
          description: "Any relevant metadata you want to store with the event."
        )
      else
        dsl
        |> Ash.Resource.Builder.add_attribute(:metadata, :map,
          allow_nil?: false,
          default: %{},
          sensitive?: true,
          public?: public_field?(public_fields, :metadata),
          description: "Any relevant metadata you want to store with the event."
        )
        |> Ash.Resource.Builder.add_attribute(:data, :map,
          allow_nil?: false,
          default: %{},
          sensitive?: true,
          public?: public_field?(public_fields, :data),
          description: "This is where the action params (attrs & args) are stored."
        )
        |> Ash.Resource.Builder.add_attribute(:changed_attributes, :map,
          allow_nil?: false,
          default: %{},
          sensitive?: true,
          public?: public_field?(public_fields, :changed_attributes),
          description:
            "Attributes that were changed but not present in the original action input."
        )
      end
    end)
    |> Ash.Resource.Builder.add_new_attribute(:occurred_at, :utc_datetime_usec,
      allow_nil?: false,
      default: &__MODULE__.datetime_default/0,
      public?: public_field?(public_fields, :occurred_at)
    )
    |> then(fn dsl ->
      if record_as_of? do
        add_as_of_attributes(dsl, public_fields)
      else
        dsl
      end
    end)
    |> Ash.Resource.Builder.add_attribute(:resource, :atom,
      allow_nil?: false,
      public?: public_field?(public_fields, :resource)
    )
    |> Ash.Resource.Builder.add_attribute(:action, :atom,
      allow_nil?: false,
      public?: public_field?(public_fields, :action)
    )
    |> Ash.Resource.Builder.add_attribute(:action_type, :atom,
      allow_nil?: false,
      constraints: [one_of: [:create, :update, :destroy]],
      public?: public_field?(public_fields, :action_type)
    )
    |> then(fn dsl ->
      Enum.reduce(persist_actor_primary_keys, dsl, fn persist, dsl ->
        Ash.Resource.Builder.add_attribute(
          dsl,
          persist.name,
          persist.attribute_type,
          public?:
            public_field_with_actors?(public_fields, persist.name, persist_actor_primary_keys),
          allow_nil?: persist.allow_nil?
        )
      end)
    end)
  end

  # Plain attributes, never encrypted (even on a cloaked event log), because
  # replay reads them, like `occurred_at`.
  defp add_as_of_attributes(dsl, public_fields) do
    dsl
    |> Ash.Resource.Builder.add_new_attribute(:as_of, :utc_datetime_usec,
      allow_nil?: true,
      public?: public_field?(public_fields, :as_of),
      description:
        "The instant a temporal write took effect (application time). nil for non-temporal resources."
    )
    |> Ash.Resource.Builder.add_new_attribute(:as_of_range, Ash.Type.Range,
      allow_nil?: true,
      constraints: [
        inner_type: :utc_datetime_usec,
        lower: [inclusive?: true],
        upper: [inclusive?: false]
      ],
      public?: public_field?(public_fields, :as_of_range),
      description:
        "The period a temporal write applied to, when as_of was a range. nil otherwise."
    )
  end

  def datetime_default do
    DateTime.utc_now(:microsecond)
  end

  defp public_field?(public_fields, attribute_name) do
    case public_fields do
      :all ->
        # Only allow canonical AshEvents fields to be public
        Enum.member?(@ash_events_fields, attribute_name)

      list when is_list(list) ->
        # Only allow specific canonical AshEvents fields
        Enum.member?(@ash_events_fields, attribute_name) and Enum.member?(list, attribute_name)
    end
  end

  defp public_field_with_actors?(public_fields, attribute_name, persist_actor_primary_keys) do
    # Include persist_actor_primary_key fields in the allowed list
    actor_field_names = Enum.map(persist_actor_primary_keys, & &1.name)
    all_ash_events_fields = @ash_events_fields ++ actor_field_names

    case public_fields do
      :all ->
        Enum.member?(all_ash_events_fields, attribute_name)

      list when is_list(list) ->
        Enum.member?(all_ash_events_fields, attribute_name) and Enum.member?(list, attribute_name)
    end
  end
end
