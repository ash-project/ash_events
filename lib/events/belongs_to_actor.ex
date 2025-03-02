defmodule AshEvents.EventResource.BelongsToActor do
  @moduledoc "Represents a belongs_to_actor relationship on a event resource"

  defstruct [
    :allow_nil?,
    :domain,
    :attribute_type,
    :destination,
    :define_attribute?,
    :public?,
    :name
  ]

  @type t :: %__MODULE__{
          allow_nil?: boolean,
          public?: boolean,
          attribute_type: term,
          destination: Ash.Resource.t(),
          define_attribute?: boolean,
          name: atom
        }

  @schema [
    name: [
      type: :atom,
      doc: "The name of the relationship to use for the actor (e.g. :user)",
      required: true
    ],
    allow_nil?: [
      type: :boolean,
      default: true,
      doc: """
      Whether this relationship must always be present, e.g: must be included
      on creation, and never removed (it may be modified). The generated
      attribute will not allow nil values.
      """
    ],
    domain: [
      type: :atom,
      doc: """
      The Domain module to use when working with the related entity.
      """
    ],
    attribute_type: [
      type: :any,
      default: Application.compile_env(:ash, :default_belongs_to_type, :uuid),
      doc: "The type of the generated created attribute. See `Ash.Type` for more."
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
