# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.AdvisoryLockKeyGenerator.Default do
  @moduledoc """
  Default implementation of the `AshEvents.AdvisoryLockKeyGenerator` behaviour.
  Handles the attribute-strategy for multitenancy, if the tenant value used is an
  integer or uuid. For other scenarios, users must implemeent a custom implementation
  and declare it in their event-log resource configuration.
  """
  use AshEvents.AdvisoryLockKeyGenerator

  def generate_key!(changeset, default_integer) do
    case Ash.Resource.Info.multitenancy_strategy(changeset.resource) do
      nil ->
        default_integer

      :context ->
        default_integer

      :attribute ->
        cond do
          is_integer(changeset.tenant) ->
            changeset.tenant

          valid_uuid?(changeset.tenant) ->
            uuid_to_int(changeset.tenant)

          true ->
            raise "Unsupported tenant type: #{inspect(changeset.tenant)}. You must implement a custom AdvisoryLockKeyGenerator module."
        end
    end
  end

  defp uuid_to_int(uuid) when is_binary(uuid) do
    # Remove dashes and decode the UUID as a 128-bit binary
    <<hi::binary-size(8), lo::binary-size(8)>> =
      uuid
      |> String.replace("-", "")
      |> Base.decode16!(case: :mixed)

    <<hi_int::signed-32, _rest::binary>> = hi
    <<lo_int::signed-32, _rest::binary>> = lo

    [hi_int, lo_int]
  end

  def valid_uuid?(uuid) do
    case Ecto.UUID.cast(uuid) do
      {:ok, _} -> true
      :error -> false
    end
  end
end
