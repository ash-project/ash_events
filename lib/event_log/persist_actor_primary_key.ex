# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EventLog.PersistActorPrimaryKey do
  @moduledoc """
    Adds a field (not relationship) on the event log resource that will be used to persist the actor primary key.
  """

  defstruct [
    :allow_nil?,
    :attribute_type,
    :destination,
    :public?,
    :name
  ]

  @type t :: %__MODULE__{
          allow_nil?: boolean,
          public?: boolean,
          attribute_type: term,
          destination: Ash.Resource.t(),
          name: atom
        }

  @schema [
    name: [
      type: :atom,
      doc: "The name of the field to use for the actor primary_key (e.g. :user_id)",
      required: true
    ],
    allow_nil?: [
      type: :boolean,
      default: true,
      doc: """
      Whether this attribute can be nil. If false, the attribute will be required.
      """
    ],
    attribute_type: [
      type: :any,
      default: Application.compile_env(:ash, :default_belongs_to_type, :uuid),
      doc: "The type of the generated attribute. See `Ash.Type` for more."
    ],
    public?: [
      type: :boolean,
      default: false,
      doc: "Whether this relationship should be included in public interfaces"
    ],
    destination: [
      type: Ash.OptionsHelpers.ash_resource(),
      doc: "The resource of the actor (e.g. MyApp.Accounts.User)"
    ]
  ]

  @doc false
  def schema, do: @schema
end
