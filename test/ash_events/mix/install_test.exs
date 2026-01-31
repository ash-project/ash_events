# SPDX-FileCopyrightText: 2024 ash_events contributors <https://github.com/ash-project/ash_events/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.Mix.InstallTest do
  @moduledoc """
  Tests for the Mix.Tasks.AshEvents.Install task.

  This module tests that the installation task is properly defined.
  The actual installation behavior depends on Igniter being available.
  """
  use ExUnit.Case, async: true

  describe "module definition" do
    test "Mix.Tasks.AshEvents.Install is defined" do
      assert Code.ensure_loaded?(Mix.Tasks.AshEvents.Install)
    end

    test "module has run/1 function" do
      assert function_exported?(Mix.Tasks.AshEvents.Install, :run, 1)
    end

    test "module has @shortdoc attribute" do
      # The module should have documentation
      {:docs_v1, _annotation, _lang, _format, moduledoc, _metadata, _docs} =
        Code.fetch_docs(Mix.Tasks.AshEvents.Install)

      assert moduledoc != :hidden
      assert moduledoc != :none
    end
  end

  describe "with Igniter available" do
    test "has info/2 callback when Igniter is loaded" do
      if Code.ensure_loaded?(Igniter) do
        assert function_exported?(Mix.Tasks.AshEvents.Install, :info, 2)
      end
    end

    test "has igniter/1 callback when Igniter is loaded" do
      if Code.ensure_loaded?(Igniter) do
        assert function_exported?(Mix.Tasks.AshEvents.Install, :igniter, 1)
      end
    end
  end

  describe "task metadata" do
    test "task is in the ash group when Igniter is available" do
      if Code.ensure_loaded?(Igniter) and
           function_exported?(Mix.Tasks.AshEvents.Install, :info, 2) do
        info = Mix.Tasks.AshEvents.Install.info([], nil)
        assert info.group == :ash
      end
    end
  end
end
