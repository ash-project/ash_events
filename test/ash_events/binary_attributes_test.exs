# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.BinaryAttributesTest do
  @moduledoc """
  Tests for resources with binary attributes (e.g., hashes, encrypted data).

  Regression test for https://github.com/ash-project/ash_events/issues/64
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.Accounts
  alias AshEvents.EventLogs.EventLog
  alias AshEvents.EventLogs.SystemActor

  require Ash.Query

  @binary_hash :crypto.strong_rand_bytes(32)

  test "creating a resource with a binary attribute does not raise Jason.EncodeError" do
    org =
      Accounts.create_org!(
        %{name: "Binary Test Org", secret_hash: @binary_hash},
        actor: %SystemActor{name: "test_runner"}
      )

    assert org.name == "Binary Test Org"
    assert org.secret_hash == @binary_hash
  end

  test "binary attribute is stored in event data as base64" do
    Accounts.create_org!(
      %{name: "Binary Event Org", secret_hash: @binary_hash},
      actor: %SystemActor{name: "test_runner"}
    )

    [event] =
      EventLog
      |> Ash.Query.filter(
        resource == ^AshEvents.Accounts.Org and data[:name] == "Binary Event Org"
      )
      |> Ash.read!()

    assert event.data["secret_hash"] == Base.encode64(@binary_hash)
  end

  test "dump_value and cast_from_embedded round-trip binary values" do
    binary_attr = %Ash.Resource.Attribute{
      name: :secret_hash,
      type: :binary,
      constraints: []
    }

    dumped = AshEvents.Events.ActionWrapperHelpers.dump_value(@binary_hash, binary_attr)
    assert dumped == Base.encode64(@binary_hash)

    restored =
      AshEvents.Events.ActionWrapperHelpers.cast_from_embedded(dumped, binary_attr)

    assert restored == @binary_hash
  end

  test "cast_from_embedded passes through nil" do
    binary_attr = %Ash.Resource.Attribute{
      name: :secret_hash,
      type: :binary,
      constraints: []
    }

    assert AshEvents.Events.ActionWrapperHelpers.cast_from_embedded(nil, binary_attr) == nil
  end

  test "cast_from_embedded passes through non-binary attribute types unchanged" do
    string_attr = %Ash.Resource.Attribute{
      name: :name,
      type: :string,
      constraints: []
    }

    assert AshEvents.Events.ActionWrapperHelpers.cast_from_embedded("hello", string_attr) ==
             "hello"
  end
end
