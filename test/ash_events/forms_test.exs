defmodule AshEvents.FormsTest do
  alias AshEvents.Test.Events.SystemActor
  use AshEvents.RepoCase, async: false

  alias AshEvents.Test.Accounts

  test "handles ash phoenix forms correctly" do
    form_params = %{
      "string_key" => "string_value",
      "email" => "user@example.com",
      given_name: "John",
      family_name: "Doe",
      non_existent: "value"
    }

    form =
      AshPhoenix.Form.for_create(Accounts.User, :create_with_form,
        params: form_params,
        context: %{ash_events_metadata: %{source: "Signup form"}},
        actor: %SystemActor{name: "test_runner"}
      )

    {:ok, _user} = AshPhoenix.Form.submit(form, params: form_params)
  end
end
