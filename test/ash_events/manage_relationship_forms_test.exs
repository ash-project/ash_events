# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.ManageRelationshipFormsTest do
  use ExUnit.Case, async: true

  # Regression test for https://github.com/ash-project/ash_events/issues/87
  # AshPhoenix.Form.Auto needs to detect manage_relationship changes on actions
  # wrapped by AshEvents, so that nested forms (inputs_for) work correctly.

  test "AshPhoenix auto forms detect manage_relationship on AshEvents-wrapped actions" do
    auto_forms = AshPhoenix.Form.Auto.auto(AshEvents.Accounts.User, :create_with_roles)

    assert Keyword.has_key?(auto_forms, :user_role),
           "Expected auto forms to include :user_role, got: #{inspect(Keyword.keys(auto_forms))}"
  end

  test "AshPhoenix.Form.for_create works with forms: [auto?: true] on wrapped actions" do
    form =
      AshPhoenix.Form.for_create(AshEvents.Accounts.User, :create_with_roles,
        forms: [auto?: true]
      )

    assert Keyword.has_key?(form.form_keys, :user_role),
           "Expected :user_role in form_keys, got: #{inspect(Keyword.keys(form.form_keys))}"
  end
end
