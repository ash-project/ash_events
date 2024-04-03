defmodule AshEventsTest do
  use ExUnit.Case

  require Ash.Query

  defmodule Domain do
    use Ash.Domain

    resources do
      allow_unregistered?(true)
    end
  end

  defmodule Event do
    use Ash.Resource,
      domain: Domain,
      data_layer: Ash.DataLayer.Ets

    actions do
      default_accept :*
      defaults([:read, :create, :update, :destroy])

      update :process do
        change(set_attribute(:processed, true))
      end
    end

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:input, :map, allow_nil?: false, public?: true)
      attribute(:resource, :atom, allow_nil?: false, public?: true)
      attribute(:action, :atom, allow_nil?: false, public?: true)
      attribute(:processed, :boolean, allow_nil?: false, default: false, public?: true)

      attribute :timestamp, :utc_datetime_usec do
        public? true
        default(&DateTime.utc_now/0)
        allow_nil?(false)
        writable?(false)
      end
    end
  end

  defmodule Profile do
    use Ash.Resource,
      domain: Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshEvents]

    events do
      event_resource(Event)
    end

    actions do
      default_accept :*
      defaults([:create, :read, :update, :destroy])
    end

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:bio, :string, public?: true)
    end

    relationships do
      belongs_to :user, AshEventsTest.User do
        public? true
        allow_nil?(false)
        attribute_writable?(true)
      end
    end

    code_interface do
      define(:create)
    end
  end

  defmodule User do
    use Ash.Resource,
      domain: Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshEvents]

    events do
      event_resource(Event)
    end

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:username, :string, allow_nil?: false, public?: true)
    end

    actions do
      default_accept :*
      defaults([:read, :update, :destroy])

      create :create do
        primary?(true)

        change(
          after_action(fn _changeset, result, _context ->
            Profile.create!(%{user_id: result.id, bio: "Initial Bio!"})

            {:ok, result}
          end)
        )
      end
    end

    code_interface do
      define(:create)
    end

    relationships do
      has_one(:profile, Profile, public?: true)
    end
  end

  test "test" do
    assert [] = Ash.read!(Event)
    User.create!(%{username: "fred"})
    assert [_, _] = Ash.read!(Event)
    assert [_] = Ash.read!(User)
    assert [_] = Ash.read!(Profile)
  end

  # defp process() do
  #   Event
  #   |> Ash.Query.sort(timestamp: :asc, id: :desc)
  #   |> Ash.Query.filter(processed == false)
  #   |> Api.read!()
  #   |> Enum.each(fn event ->
  #     event.resource
  #     |> Ash.Changeset.for_create(event.action, event.input)
  #     |> Api.create!()

  #     event
  #     |> Ash.Changeset.for_update(:process)
  #     |> Api.update!()
  #   end)
  # end
end
