defmodule AshEvents.EmbeddedResourcesTest do
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts
  alias AshEvents.EventLogs

  test "handles embedded resources" do
    user =
      Accounts.create_user_embedded!(%{
        given_name: "Embedded User",
        family_name: "Embedded Family",
        email: "embedded@example.com",
        address: %AshEvents.Accounts.Address{
          street: "Embedded Street",
          city: "Embedded City",
          state: "Embedded State",
          zip_code: "Embedded Zip"
        },
        other_addresses: [
          %AshEvents.Accounts.Address{
            street: "Other Embedded Street",
            city: "Other Embedded City",
            state: "Other Embedded State",
            zip_code: "Other Embedded Zip"
          },
          %AshEvents.Accounts.Address{
            street: "Another Embedded Street",
            city: "Another Embedded City",
            state: "Another Embedded State",
            zip_code: "Another Embedded Zip"
          }
        ]
      })

    user = Ash.load!(user, [:address])
    assert user.address.street == "Embedded Street"

    :ok = EventLogs.replay_events!()

    [user] = Ash.read!(Accounts.UserEmbedded)
    user = Ash.load!(user, [:address])
    assert user.address.street == "Embedded Street"

    assert user.other_addresses |> Enum.map(& &1.street) == [
             "Other Embedded Street",
             "Another Embedded Street"
           ]

    user =
      Accounts.update_user_embedded!(user, %{
        given_name: "Updated Embedded User",
        address: %{street: "Updated Embedded Street"},
        other_addresses: []
      })

    assert user.address.street == "Updated Embedded Street"
    assert user.address.city == "Embedded City"
    assert user.address.state == "Embedded State"
    assert user.address.zip_code == "Embedded Zip"
    assert user.other_addresses == []

    :ok = EventLogs.replay_events!()

    user = Accounts.get_user_embedded_by_id!(user.id)

    assert user.address.street == "Updated Embedded Street"
    assert user.address.city == "Embedded City"
    assert user.address.state == "Embedded State"
    assert user.address.zip_code == "Embedded Zip"
  end
end
