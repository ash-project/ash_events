# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.ManualActionTest do
  @moduledoc """
  Regression tests for https://github.com/ash-project/ash_events/issues/99.

  AshEvents installs its own manual implementation on every tracked action, so a
  `manual` declared by the resource must be rejected at compile time instead of
  being silently replaced.
  """
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  defmodule Domain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      allow_unregistered? true
    end
  end

  defp compile_resource(name, events_block, actions_block) do
    source = """
    defmodule #{name} do
      use Ash.Resource,
        domain: AshEvents.ManualActionTest.Domain,
        data_layer: Ash.DataLayer.Ets,
        extensions: [AshEvents.Events]

      events do
        event_log AshEvents.EventLogs.EventLog
        #{events_block}
      end

      attributes do
        uuid_primary_key :id
        attribute :name, :string, public?: true
      end

      actions do
        defaults [:read]

        #{actions_block}
      end
    end
    """

    # Ash resources define protocol implementations, which emit consolidation
    # warnings when compiled at runtime. They are irrelevant to these tests.
    capture_io(:stderr, fn -> Code.compile_string(source) end)
  end

  @manual "manual fn changeset, _ctx -> {:ok, changeset.data} end"

  @tracked_actions [
    create: """
    create :create do
      accept [:name]
      #{@manual}
    end
    """,
    update: """
    update :update do
      accept [:name]
      #{@manual}
    end
    """,
    destroy: """
    destroy :destroy do
      #{@manual}
    end
    """
  ]

  for {type, actions_block} <- @tracked_actions do
    test "a manual #{type} action tracked by AshEvents fails to compile with a DslError" do
      type = unquote(type)

      error =
        assert_raise Spark.Error.DslError, fn ->
          compile_resource(
            "AshEvents.ManualActionTest.Tracked#{Macro.camelize(to_string(type))}",
            "",
            unquote(actions_block)
          )
        end

      assert error.message =~ "Action :#{type} declares a manual implementation"
      assert error.message =~ "ignore_actions [:#{type}]"
      assert error.path == [:actions, type, type, :manual]
    end
  end

  test "a manual action excluded with ignore_actions keeps its own manual implementation" do
    compile_resource(
      "AshEvents.ManualActionTest.Ignored",
      "ignore_actions [:destroy]",
      @tracked_actions[:destroy]
    )

    assert %{manual: {Ash.Resource.ManualDestroy.Function, _}} =
             Ash.Resource.Info.action(AshEvents.ManualActionTest.Ignored, :destroy)
  end

  test "a manual action left out of only_actions keeps its own manual implementation" do
    compile_resource(
      "AshEvents.ManualActionTest.OnlyActions",
      "only_actions [:create]",
      @tracked_actions[:destroy]
    )

    assert %{manual: {Ash.Resource.ManualDestroy.Function, _}} =
             Ash.Resource.Info.action(AshEvents.ManualActionTest.OnlyActions, :destroy)
  end
end
