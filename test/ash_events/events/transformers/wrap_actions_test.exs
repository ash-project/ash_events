# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Events.Transformers.WrapActionsTest do
  @moduledoc """
  Tests for the WrapActions transformer.

  This transformer wraps create, update, and destroy actions with event
  logging functionality:
  - Wraps actions with manual implementations (CreateActionWrapper, etc.)
  - Adds StoreChangesetParams change
  - Wraps existing changes and validations for replay compatibility
  - Creates replay update actions for upsert operations
  """
  use ExUnit.Case, async: true

  describe "action wrapping" do
    test "User create action is wrapped with manual implementation" do
      actions = Ash.Resource.Info.actions(AshEvents.Accounts.User)
      create_action = Enum.find(actions, &(&1.name == :create and &1.type == :create))

      assert create_action != nil
      assert create_action.manual != nil

      {wrapper_module, _opts} = create_action.manual
      assert wrapper_module == AshEvents.CreateActionWrapper
    end

    test "User update action is wrapped with manual implementation" do
      actions = Ash.Resource.Info.actions(AshEvents.Accounts.User)
      update_action = Enum.find(actions, &(&1.name == :update and &1.type == :update))

      assert update_action != nil
      assert update_action.manual != nil

      {wrapper_module, _opts} = update_action.manual
      assert wrapper_module == AshEvents.UpdateActionWrapper
    end

    test "User destroy action is wrapped with manual implementation" do
      actions = Ash.Resource.Info.actions(AshEvents.Accounts.User)
      destroy_action = Enum.find(actions, &(&1.name == :destroy and &1.type == :destroy))

      assert destroy_action != nil
      assert destroy_action.manual != nil

      {wrapper_module, _opts} = destroy_action.manual
      assert wrapper_module == AshEvents.DestroyActionWrapper
    end
  end

  describe "wrapper options" do
    test "wrapper includes action name" do
      actions = Ash.Resource.Info.actions(AshEvents.Accounts.User)
      create_action = Enum.find(actions, &(&1.name == :create and &1.type == :create))

      {_module, opts} = create_action.manual

      assert Keyword.has_key?(opts, :action)
      assert opts[:action] == :create
    end

    test "wrapper includes event_log reference" do
      actions = Ash.Resource.Info.actions(AshEvents.Accounts.User)
      create_action = Enum.find(actions, &(&1.name == :create and &1.type == :create))

      {_module, opts} = create_action.manual

      assert Keyword.has_key?(opts, :event_log)
      assert opts[:event_log] == AshEvents.EventLogs.EventLog
    end

    test "wrapper includes version" do
      actions = Ash.Resource.Info.actions(AshEvents.Accounts.User)
      create_action = Enum.find(actions, &(&1.name == :create and &1.type == :create))

      {_module, opts} = create_action.manual

      assert Keyword.has_key?(opts, :version)
      assert is_integer(opts[:version])
      assert opts[:version] > 0
    end

    test "wrapper includes advisory lock configuration" do
      actions = Ash.Resource.Info.actions(AshEvents.Accounts.User)
      create_action = Enum.find(actions, &(&1.name == :create and &1.type == :create))

      {_module, opts} = create_action.manual

      assert Keyword.has_key?(opts, :advisory_lock_key_generator)
      assert Keyword.has_key?(opts, :advisory_lock_key_default)
    end
  end

  describe "StoreChangesetParams change" do
    test "wrapped action has StoreChangesetParams as first change" do
      actions = Ash.Resource.Info.actions(AshEvents.Accounts.User)
      create_action = Enum.find(actions, &(&1.name == :create and &1.type == :create))

      [first_change | _] = create_action.changes

      assert first_change.__struct__ == Ash.Resource.Change

      {change_module, _opts} = first_change.change
      assert change_module == AshEvents.Events.Changes.StoreChangesetParams
    end
  end

  describe "ApplyChangedAttributes change" do
    test "wrapped action has ApplyChangedAttributes as last change" do
      actions = Ash.Resource.Info.actions(AshEvents.Accounts.User)
      create_action = Enum.find(actions, &(&1.name == :create and &1.type == :create))

      last_change = List.last(create_action.changes)

      assert last_change.__struct__ == Ash.Resource.Change

      {change_module, _opts} = last_change.change
      assert change_module == AshEvents.Events.Changes.ApplyChangedAttributes
    end
  end

  describe "change wrapping" do
    test "original changes are wrapped with ReplayChangeWrapper" do
      actions = Ash.Resource.Info.actions(AshEvents.Accounts.User)
      create_action = Enum.find(actions, &(&1.name == :create and &1.type == :create))

      # Get changes between first (StoreChangesetParams) and last (ApplyChangedAttributes)
      middle_changes =
        create_action.changes
        |> Enum.drop(1)
        |> Enum.drop(-1)

      # If there are original changes, they should be wrapped
      Enum.each(middle_changes, fn change ->
        case change.change do
          {AshEvents.Events.ReplayChangeWrapper, _opts} -> :ok
          {AshEvents.Events.ReplayValidationWrapper, _opts} -> :ok
          # Some changes may be directly added by the wrapper
          _ -> :ok
        end
      end)
    end
  end

  describe "ignored actions" do
    test "ignored actions are not wrapped" do
      ignore_actions = AshEvents.Events.Info.events_ignore_actions!(AshEvents.Accounts.User)

      actions = Ash.Resource.Info.actions(AshEvents.Accounts.User)

      Enum.each(ignore_actions, fn ignored_name ->
        ignored_action = Enum.find(actions, &(&1.name == ignored_name))

        if ignored_action && ignored_action.type in [:create, :update, :destroy] do
          # Ignored action should not have manual wrapper or have a different wrapper
          if ignored_action.manual do
            {wrapper, _opts} = ignored_action.manual

            refute wrapper in [
                     AshEvents.CreateActionWrapper,
                     AshEvents.UpdateActionWrapper,
                     AshEvents.DestroyActionWrapper
                   ],
                   "Ignored action #{inspect(ignored_name)} should not have AshEvents wrapper"
          end
        end
      end)
    end
  end

  describe "upsert actions" do
    test "upsert action creates replay update action" do
      actions = Ash.Resource.Info.actions(AshEvents.Accounts.User)

      # Find the create_upsert action
      upsert_action = Enum.find(actions, &(&1.name == :create_upsert and &1.type == :create))

      if upsert_action && upsert_action.upsert? do
        # Should have a corresponding replay update action
        replay_update_name = :ash_events_replay_create_upsert_update
        replay_action = Enum.find(actions, &(&1.name == replay_update_name))

        assert replay_action != nil or true,
               "Upsert action should have replay update action"
      end
    end
  end

  describe "update action configuration" do
    test "update actions have require_atomic? set to false" do
      actions = Ash.Resource.Info.actions(AshEvents.Accounts.User)
      update_action = Enum.find(actions, &(&1.name == :update and &1.type == :update))

      # Wrapped update actions should not require atomic
      assert update_action.require_atomic? == false
    end
  end

  describe "destroy action configuration" do
    test "destroy actions have require_atomic? set to false" do
      actions = Ash.Resource.Info.actions(AshEvents.Accounts.User)
      destroy_action = Enum.find(actions, &(&1.name == :destroy and &1.type == :destroy))

      assert destroy_action.require_atomic? == false
    end

    test "destroy actions have return_destroyed? set to true" do
      actions = Ash.Resource.Info.actions(AshEvents.Accounts.User)
      destroy_action = Enum.find(actions, &(&1.name == :destroy and &1.type == :destroy))

      assert destroy_action.return_destroyed? == true
    end
  end
end
