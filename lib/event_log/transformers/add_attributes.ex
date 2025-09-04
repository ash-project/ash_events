defmodule AshEvents.EventLog.Transformers.AddAttributes do
  @moduledoc false
  use Spark.Dsl.Transformer

  def before?(_), do: true

  def transform(dsl) do
    record_primary_id_type = AshEvents.EventLog.Info.event_log_record_id_type!(dsl)
    persist_actor_primary_keys = AshEvents.EventLog.Info.event_log(dsl)

    cloaked? =
      case AshEvents.EventLog.Info.event_log_cloak_vault(dsl) do
        :error -> false
        {:ok, _} -> true
      end

    case AshEvents.EventLog.Info.event_log_primary_key_type!(dsl) do
      :integer ->
        Ash.Resource.Builder.add_attribute(dsl, :id, :integer,
          primary_key?: true,
          writable?: false,
          generated?: true,
          allow_nil?: false
        )

      Ash.Type.UUIDv7 ->
        Ash.Resource.Builder.add_attribute(dsl, :id, Ash.Type.UUIDv7,
          primary_key?: true,
          writable?: false,
          allow_nil?: false,
          default: &Ash.UUIDv7.generate/0
        )
    end
    |> Ash.Resource.Builder.add_attribute(:record_id, record_primary_id_type, allow_nil?: false)
    |> Ash.Resource.Builder.add_attribute(:version, :integer, allow_nil?: false, default: 1)
    |> then(fn dsl ->
      if cloaked? do
        dsl
        |> Ash.Resource.Builder.add_attribute(:encrypted_metadata, :binary, allow_nil?: false)
        |> Ash.Resource.Builder.add_attribute(:encrypted_data, :binary, allow_nil?: false)
        |> Ash.Resource.Builder.add_attribute(:encrypted_changed_attributes, :binary,
          allow_nil?: false
        )
        |> Ash.Resource.Builder.add_calculation(
          :data,
          :map,
          {AshEvents.EventLog.Calculations.Decrypt, [field: :encrypted_data]},
          public?: false,
          allow_nil?: false,
          sensitive?: true,
          description: "This is where the action params (attrs & args) are stored."
        )
        |> Ash.Resource.Builder.add_calculation(
          :changed_attributes,
          :map,
          {AshEvents.EventLog.Calculations.Decrypt, [field: :encrypted_changed_attributes]},
          public?: true,
          allow_nil?: false,
          sensitive?: true,
          description:
            "Attributes that were changed but not present in the original action input."
        )
        |> Ash.Resource.Builder.add_calculation(
          :metadata,
          :map,
          {AshEvents.EventLog.Calculations.Decrypt, [field: :encrypted_metadata]},
          public?: false,
          allow_nil?: false,
          sensitive?: true,
          description: "Any relevant metadata you want to store with the event."
        )
      else
        dsl
        |> Ash.Resource.Builder.add_attribute(:metadata, :map,
          allow_nil?: false,
          default: %{},
          description: "Any relevant metadata you want to store with the event."
        )
        |> Ash.Resource.Builder.add_attribute(:data, :map,
          allow_nil?: false,
          default: %{},
          description: "This is where the action params (attrs & args) are stored."
        )
        |> Ash.Resource.Builder.add_attribute(:changed_attributes, :map,
          allow_nil?: false,
          default: %{},
          public?: true,
          description:
            "Attributes that were changed but not present in the original action input."
        )
      end
    end)
    |> Ash.Resource.Builder.add_new_attribute(:occurred_at, :utc_datetime_usec,
      allow_nil?: false,
      default: &__MODULE__.datetime_default/0
    )
    |> Ash.Resource.Builder.add_attribute(:resource, :atom, allow_nil?: false)
    |> Ash.Resource.Builder.add_attribute(:action, :atom, allow_nil?: false)
    |> Ash.Resource.Builder.add_attribute(:action_type, :atom,
      allow_nil?: false,
      constraints: [one_of: [:create, :update, :destroy]]
    )
    |> then(fn dsl ->
      Enum.reduce(persist_actor_primary_keys, dsl, fn persist, dsl ->
        Ash.Resource.Builder.add_attribute(
          dsl,
          persist.name,
          persist.attribute_type,
          public?: persist.public?,
          allow_nil?: persist.allow_nil?
        )
      end)
    end)
  end

  def datetime_default do
    DateTime.utc_now(:microsecond)
  end
end
