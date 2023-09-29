defmodule AshEventSourceTest do
  use ExUnit.Case

  require Ash.Query

  defmodule Api do
    use Ash.Api

    resources do
      allow_unregistered?(true)
    end
  end

  defmodule Event do
    use Ash.Resource,
      data_layer: Ash.DataLayer.Ets

    actions do
      defaults [:read, :create, :update, :destroy]

      update :process do
        change set_attribute(:processed, true)
      end
    end

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute :input, :map, allow_nil?: false
      attribute :resource, :atom, allow_nil?: false
      attribute :action, :atom, allow_nil?: false
      attribute :processed, :boolean, allow_nil?: false, default: false
      attribute :timestamp, :utc_datetime_usec do
        default &DateTime.utc_now/0
        allow_nil? false
        writable? false
      end
    end
  end

  defmodule Profile do
    use Ash.Resource,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshEventSource]

    event_source do
      event_resource(Event)
    end

    actions do
      defaults [:create, :read, :update, :destroy]
    end

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key :id
      attribute :bio, :string
    end

    relationships do
      belongs_to :user, AshEventSourceTest.User do
        allow_nil? false
        attribute_writable? true
      end
    end

    code_interface do
      define_for Api
      define :create
    end
  end

  defmodule User do
    use Ash.Resource,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshEventSource]

    event_source do
      event_resource(Event)
    end

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:username, :string, allow_nil?: false)
    end

    actions do
      defaults([:read, :update, :destroy])
      create :create do
        primary? true

        change after_action(fn _changeset, result ->
          Profile.create!(%{user_id: result.id, bio: "Initial Bio!"})

          {:ok, result}
        end)
      end
    end

    code_interface do
      define_for(Api)
      define(:create)
    end

    relationships do
      has_one :profile, Profile
    end
  end

  test "test" do
    User.create!(%{username: "fred"})
    # IO.inspect("FIRST EVENT CREATED")
    Api.read!(Event) |> IO.inspect()
    Api.read!(User) |> IO.inspect()
    Api.read!(Profile) |> IO.inspect()
    # process()
    # IO.inspect("FIRST EVENT PROCESSED")
    # Api.read!(Event) |> IO.inspect()
    # Api.read!(User) |> IO.inspect()
    # Api.read!(Profile) |> IO.inspect()
    # process()
    # IO.inspect("SECOND EVENT PROCESSED")
    # Api.read!(Event) |> IO.inspect()
    # Api.read!(User) |> IO.inspect()
    # Api.read!(Profile) |> IO.inspect()
  end

  defp process() do
    Event
    |> Ash.Query.sort(timestamp: :asc, id: :desc)
    |> Ash.Query.filter(processed == false)
    |> Api.read!()
    |> Enum.each(fn event ->
      event.resource
      |> Ash.Changeset.for_create(event.action, event.input)
      |> Api.create!()

      event
      |> Ash.Changeset.for_update(:process)
      |> Api.update!()
    end)
  end
end
