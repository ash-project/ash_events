# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.BeforeActionValidationTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias AshEvents.Accounts.Org

  test "before_action? validations aren't run while building the changeset" do
    # required_arg is omitted on purpose: the validation requires it, but since
    # it's before_action? the changeset is still valid until the action runs.
    changeset =
      Ash.Changeset.for_create(Org, :create_with_before_action_validation, %{name: "Acme"})

    assert changeset.valid?
    assert changeset.before_action != []
  end
end
