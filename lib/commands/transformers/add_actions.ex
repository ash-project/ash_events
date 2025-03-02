defmodule AshEvents.Commands.Resource.Transformers.AddActions do
  @moduledoc false
  use Spark.Dsl.Transformer

  # def before?(_), do: false
  # def after?(_), do: true

  def transform(dsl) do
    commands = AshEvents.Commands.Resource.Info.commands(dsl)
    event_resource = AshEvents.Commands.Resource.Info.commands_event_resource!(dsl)

    Enum.reduce(commands, {:ok, dsl}, fn command, {:ok, dsl} ->
      Ash.Resource.Builder.add_action(dsl, :action, command.name,
        transaction?: true,
        returns: command.returns,
        arguments: [
          %Ash.Resource.Actions.Argument{
            name: :entity_id,
            allow_nil?: false,
            type: :uuid,
            default: &Ash.UUID.generate/0,
            description: "The id of the entity that the command will act upon.",
            sensitive?: false
          },
          %Ash.Resource.Actions.Argument{
            name: :data,
            allow_nil?: false,
            type: :map,
            default: %{},
            description: "The event data.",
            sensitive?: false
          },
          %Ash.Resource.Actions.Argument{
            name: :metadata,
            allow_nil?: false,
            type: :map,
            default: %{},
            description: "The metadata to store with the event.",
            sensitive?: false
          }
        ],
        run:
          {AshEvents.Commands.Resource.RunCommand,
           [event_resource: event_resource, command: command]}
      )
    end)
  end
end
