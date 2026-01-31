# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.EmbeddedResourcesTest do
  @moduledoc """
  Tests for embedded resources with events.

  This module tests:
  - Embedded resources in event data
  - Arrays of embedded resources
  - Partial updates to embedded resources
  - Replay with embedded resources
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts
  alias AshEvents.EventLogs

  describe "basic embedded resources" do
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

    test "embedded resource without initial value" do
      user =
        Accounts.create_user_embedded!(%{
          given_name: "No Address",
          family_name: "User",
          email: unique_email()
        })

      user = Ash.load!(user, [:address])
      assert user.address == nil

      # Update to add address
      user =
        Accounts.update_user_embedded!(user, %{
          address: %{
            street: "Added Street",
            city: "Added City",
            state: "Added State",
            zip_code: "Added Zip"
          }
        })

      user = Ash.load!(user, [:address])
      assert user.address.street == "Added Street"

      # Replay should preserve
      :ok = EventLogs.replay_events!()

      user = Accounts.get_user_embedded_by_id!(user.id)
      assert user.address.street == "Added Street"
    end
  end

  describe "embedded resource arrays" do
    test "empty array of embedded resources" do
      user =
        Accounts.create_user_embedded!(%{
          given_name: "Empty Array",
          family_name: "User",
          email: unique_email(),
          other_addresses: []
        })

      assert user.other_addresses == []

      :ok = EventLogs.replay_events!()

      user = Accounts.get_user_embedded_by_id!(user.id)
      assert user.other_addresses == []
    end

    test "array with single embedded resource" do
      user =
        Accounts.create_user_embedded!(%{
          given_name: "Single Array",
          family_name: "User",
          email: unique_email(),
          other_addresses: [
            %AshEvents.Accounts.Address{
              street: "Only Street",
              city: "Only City",
              state: "Only State",
              zip_code: "Only Zip"
            }
          ]
        })

      assert length(user.other_addresses) == 1
      assert hd(user.other_addresses).street == "Only Street"

      :ok = EventLogs.replay_events!()

      user = Accounts.get_user_embedded_by_id!(user.id)
      assert length(user.other_addresses) == 1
      assert hd(user.other_addresses).street == "Only Street"
    end

    test "update array by adding elements" do
      user =
        Accounts.create_user_embedded!(%{
          given_name: "Growing Array",
          family_name: "User",
          email: unique_email(),
          other_addresses: [
            %AshEvents.Accounts.Address{
              street: "First Street",
              city: "First City",
              state: "First State",
              zip_code: "First Zip"
            }
          ]
        })

      assert length(user.other_addresses) == 1

      # Add another address
      user =
        Accounts.update_user_embedded!(user, %{
          other_addresses: [
            %{
              street: "First Street",
              city: "First City",
              state: "First State",
              zip_code: "First Zip"
            },
            %{
              street: "Second Street",
              city: "Second City",
              state: "Second State",
              zip_code: "Second Zip"
            }
          ]
        })

      assert length(user.other_addresses) == 2

      :ok = EventLogs.replay_events!()

      user = Accounts.get_user_embedded_by_id!(user.id)
      assert length(user.other_addresses) == 2

      streets = Enum.map(user.other_addresses, & &1.street)
      assert "First Street" in streets
      assert "Second Street" in streets
    end
  end

  describe "embedded resource partial updates" do
    test "partial update preserves unmodified fields" do
      user =
        Accounts.create_user_embedded!(%{
          given_name: "Partial",
          family_name: "Update",
          email: unique_email(),
          address: %AshEvents.Accounts.Address{
            street: "Original Street",
            city: "Original City",
            state: "Original State",
            zip_code: "12345"
          }
        })

      # Update only one field
      user =
        Accounts.update_user_embedded!(user, %{
          address: %{street: "New Street"}
        })

      user = Ash.load!(user, [:address])

      # Street should be updated
      assert user.address.street == "New Street"

      # Other fields should be preserved
      assert user.address.city == "Original City"
      assert user.address.state == "Original State"
      assert user.address.zip_code == "12345"
    end

    test "complete replacement of embedded resource" do
      user =
        Accounts.create_user_embedded!(%{
          given_name: "Replace",
          family_name: "Test",
          email: unique_email(),
          address: %AshEvents.Accounts.Address{
            street: "Old Street",
            city: "Old City",
            state: "Old State",
            zip_code: "00000"
          }
        })

      # Replace entire address
      user =
        Accounts.update_user_embedded!(user, %{
          address: %AshEvents.Accounts.Address{
            street: "New Street",
            city: "New City",
            state: "New State",
            zip_code: "99999"
          }
        })

      user = Ash.load!(user, [:address])

      assert user.address.street == "New Street"
      assert user.address.city == "New City"
      assert user.address.state == "New State"
      assert user.address.zip_code == "99999"
    end
  end

  describe "embedded resource events" do
    test "events store embedded data correctly" do
      user =
        Accounts.create_user_embedded!(%{
          given_name: "Event Data",
          family_name: "Test",
          email: unique_email(),
          address: %AshEvents.Accounts.Address{
            street: "Event Street",
            city: "Event City",
            state: "Event State",
            zip_code: "EVENT"
          }
        })

      # Check event contains embedded data
      events = Ash.read!(AshEvents.EventLogs.EventLog)
      user_event = Enum.find(events, &(&1.record_id == user.id && &1.action_type == :create))

      assert user_event != nil

      # The embedded data should be in the event's data field
      assert user_event.data["given_name"] == "Event Data"
    end
  end

  # Helper functions

  defp unique_email(prefix \\ "embedded") do
    "#{prefix}_#{System.unique_integer([:positive])}@example.com"
  end
end
