# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.TemporalEventsTest do
  @moduledoc """
  Tracking Ash temporal resources with AshEvents.
  """
  use AshEvents.RepoCase, async: false

  import ExUnit.CaptureIO
  require Ash.Query

  alias AshEvents.Accounts.TrackedSubscription
  alias AshEvents.Accounts.TrackedSubscriptionNoRecordedAt
  alias AshEvents.EventLogs.EventLog
  alias AshEvents.EventLogs.EventLogTemporal
  alias AshEvents.EventLogs.SystemActor

  @actor %SystemActor{name: "test_runner"}

  @t1 ~U[2025-01-01 00:00:00.000000Z]
  @t2 ~U[2025-03-01 00:00:00.000000Z]
  @t3 ~U[2025-06-01 00:00:00.000000Z]
  @t4 ~U[2025-09-01 00:00:00.000000Z]

  defmodule UnsafeValidation do
    @moduledoc false
    use Ash.Resource.Validation

    @impl true
    def validate(_changeset, _opts, _context), do: :ok
  end

  defmodule Domain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      allow_unregistered? true
    end
  end

  defp compile_resource(name, opts) do
    temporal_block =
      if Keyword.get(opts, :temporal?, true) do
        """
        temporal do
          strategy :context
          attribute :valid_at
        end
        """
      else
        ""
      end

    source = """
    defmodule #{name} do
      use Ash.Resource,
        domain: AshEvents.TemporalEventsTest.Domain,
        data_layer: Ash.DataLayer.Ets,
        extensions: [AshEvents.Events]

      #{temporal_block}

      events do
        event_log #{inspect(Keyword.fetch!(opts, :event_log))}
        #{Keyword.get(opts, :events_block, "")}
      end

      attributes do
        uuid_primary_key :id
        attribute :plan, :string, public?: true
        create_timestamp :inserted_at
        update_timestamp :updated_at
      end

      actions do
        defaults [:read, create: [:plan]]
      end
    end
    """

    # Ash resources define protocol implementations, which emit consolidation
    # warnings when compiled at runtime. They are irrelevant to these tests.
    capture_io(:stderr, fn -> Code.compile_string(source) end)
  end

  describe "record_as_of?" do
    test "adds as_of and as_of_range to an event log that sets it" do
      as_of = Ash.Resource.Info.attribute(EventLogTemporal, :as_of)
      as_of_range = Ash.Resource.Info.attribute(EventLogTemporal, :as_of_range)

      assert %{type: Ash.Type.UtcDatetimeUsec, allow_nil?: true} = as_of
      assert %{type: Ash.Type.Range, allow_nil?: true} = as_of_range
      assert as_of_range.constraints[:inner_type] == Ash.Type.UtcDatetimeUsec
    end

    test "an event log without it has neither attribute" do
      assert Ash.Resource.Info.attribute(EventLog, :as_of) == nil
      assert Ash.Resource.Info.attribute(EventLog, :as_of_range) == nil
    end

    test "as_of and as_of_range are AshEvents fields, so public_fields accepts them" do
      fields = AshEvents.EventLog.Transformers.AddAttributes.ash_events_fields()
      assert :as_of in fields
      assert :as_of_range in fields
    end

    test "as_of and as_of_range stay plain attributes on an encrypted event log" do
      source = """
      defmodule AshEvents.TemporalEventsTest.CloakedTemporalLog do
        use Ash.Resource,
          domain: AshEvents.TemporalEventsTest.Domain,
          data_layer: Ash.DataLayer.Ets,
          extensions: [AshEvents.EventLog]

        event_log do
          clear_records_for_replay AshEvents.EventLogs.ClearRecordsTemporal
          cloak_vault AshEvents.Vault
          record_as_of? true
        end

        actions do
          defaults [:read]
        end
      end
      """

      capture_io(:stderr, fn -> Code.compile_string(source) end)
      log = AshEvents.TemporalEventsTest.CloakedTemporalLog

      assert %{type: Ash.Type.Binary} = Ash.Resource.Info.attribute(log, :encrypted_data)
      assert %{type: Ash.Type.UtcDatetimeUsec} = Ash.Resource.Info.attribute(log, :as_of)
      assert %{type: Ash.Type.Range} = Ash.Resource.Info.attribute(log, :as_of_range)
      refute Ash.Resource.Info.attribute(log, :encrypted_as_of)
      refute Ash.Resource.Info.attribute(log, :encrypted_as_of_range)

      accept = Ash.Resource.Info.action(log, :create).accept
      assert :as_of in accept
      assert :as_of_range in accept
    end

    test "a non-temporal resource tracked into an event log without it compiles" do
      output =
        compile_resource("AshEvents.TemporalEventsTest.NonTemporal",
          event_log: EventLog,
          temporal?: false
        )

      refute output =~ "Spark.Error.DslError"
    end
  end

  # Spark reports verifier errors as compile warnings, not exceptions, so the
  # tests read them from the captured compiler output.
  describe "verifiers" do
    test "a temporal resource tracked into an event log without record_as_of? fails to compile" do
      output = compile_resource("AshEvents.TemporalEventsTest.NoRecordAsOf", event_log: EventLog)

      assert output =~ "Spark.Error.DslError"
      assert output =~ "events -> event_log"

      assert output =~
               "AshEvents.TemporalEventsTest.NoRecordAsOf is a temporal resource, but its event log " <>
                 "AshEvents.EventLogs.EventLog does not set `record_as_of?`, so its events could not " <>
                 "record the application time of each write. Add `record_as_of? true` to the " <>
                 "`event_log` section of AshEvents.EventLogs.EventLog, and generate a migration " <>
                 "for the `as_of` and `as_of_range` attributes it adds."
    end

    test "a temporal resource tracked into an event log with record_as_of? compiles" do
      output =
        compile_resource("AshEvents.TemporalEventsTest.RecordAsOf", event_log: EventLogTemporal)

      refute output =~ "Spark.Error.DslError"
      assert Ash.Resource.Info.temporal?(AshEvents.TemporalEventsTest.RecordAsOf)
    end

    for {option, attribute} <- [create_timestamp: :inserted_at, update_timestamp: :updated_at] do
      test "a temporal resource that sets #{option} fails to compile" do
        option = unquote(option)
        name = "AshEvents.TemporalEventsTest.Temporal#{Macro.camelize(to_string(option))}"

        output =
          compile_resource(name,
            event_log: EventLogTemporal,
            events_block: "#{option} #{inspect(unquote(attribute))}"
          )

        assert output =~ "Spark.Error.DslError"
        assert output =~ "events -> #{option}"

        assert output =~
                 "#{name} is a temporal resource, so it can't set `#{option}`. On a temporal " <>
                   "resource the create and update timestamps hold application time (`as_of`), " <>
                   "and an event's `occurred_at` is system time: it comes from the resource's " <>
                   "`recorded_at` attribute, or the wall clock when there is none."
      end
    end
  end

  describe "temporal safety" do
    for module <- [
          AshEvents.Events.Changes.StoreChangesetParams,
          AshEvents.Events.Changes.ApplyReplayPrimaryKey,
          AshEvents.Events.Changes.ApplyChangedAttributes,
          AshEvents.Events.Changes.ApplyReplayRecordedAt,
          AshEvents.Events.Validations.Never,
          AshEvents.Events.Validations.ReplayOnly
        ] do
      test "#{inspect(module)} declares itself temporal safe" do
        assert Ash.Temporal.temporal_safe?(unquote(module), [])
      end
    end

    test "ReplayChangeWrapper is as temporal safe as the change it wraps" do
      wrapper = AshEvents.Events.ReplayChangeWrapper

      assert Ash.Temporal.temporal_safe?(wrapper,
               change: %Ash.Resource.Change{change: {TrackedSubscription.UpcasePlan, []}}
             )

      refute Ash.Temporal.temporal_safe?(wrapper,
               change: %Ash.Resource.Change{change: {TrackedSubscription.UnsafeChange, []}}
             )
    end

    test "ReplayValidationWrapper is as temporal safe as the validation it wraps" do
      wrapper = AshEvents.Events.ReplayValidationWrapper
      safe_opts = [attribute: :plan, min: 1]

      assert Ash.Temporal.temporal_safe?(wrapper,
               validation: %Ash.Resource.Validation{
                 validation: {Ash.Resource.Validation.StringLength, safe_opts},
                 module: Ash.Resource.Validation.StringLength,
                 opts: safe_opts
               },
               message: nil
             )

      refute Ash.Temporal.temporal_safe?(wrapper,
               validation: %Ash.Resource.Validation{
                 validation: {UnsafeValidation, []},
                 module: UnsafeValidation,
                 opts: []
               },
               message: nil
             )
    end

    test "a tracked update with a temporal-safe change and validation runs" do
      sub = create!(TrackedSubscription, "bronze", @t1)

      updated = update!(sub, :update_with_safe_change, "gold", @t2)

      assert updated.plan == "GOLD"
      assert Enum.map(events(), & &1.action) == [:create, :update_with_safe_change]
    end

    test "a tracked update with an unsafe change raises NotTemporalSafe and writes no event" do
      sub = create!(TrackedSubscription, "bronze", @t1)

      error =
        assert_raise Ash.Error.Framework, fn ->
          update!(sub, :update_with_unsafe_change, "gold", @t2)
        end

      assert [%Ash.Error.Framework.NotTemporalSafe{} = not_safe] = error.errors
      assert not_safe.module == AshEvents.Events.ReplayChangeWrapper
      assert not_safe.type == :change

      assert Exception.message(not_safe) =~
               "AshEvents.Events.ReplayChangeWrapper is not temporal safe, but " <>
                 "AshEvents.Accounts.TrackedSubscription.update_with_unsafe_change runs on a " <>
                 "temporal resource."

      assert Enum.map(events(), & &1.action) == [:create]
    end
  end

  describe "tracked writes" do
    test "a backdated create and update run and each writes an event" do
      sub = create!(TrackedSubscription, "bronze", @t1)
      update!(sub, :update, "gold", @t2)

      assert Ash.get!(TrackedSubscription, sub.id, as_of: @t1).plan == "bronze"
      assert Ash.get!(TrackedSubscription, sub.id, as_of: @t2).plan == "gold"

      assert [
               %{
                 action: :create,
                 action_type: :create,
                 record_id: id,
                 system_actor: "test_runner"
               },
               %{action: :update, action_type: :update, record_id: id}
             ] = events()

      assert id == sub.id
    end
  end

  describe "as_of capture" do
    test "a backdated create records its instant in as_of" do
      sub = create!(TrackedSubscription, "bronze", @t1)

      assert [%{as_of: @t1, as_of_range: nil}] = events()
      assert [%{valid_at: {@t1, nil}}] = versions(sub.id)
    end

    test "a range update records its range in as_of_range" do
      sub = create!(TrackedSubscription, "bronze", @t1)
      update!(sub, :update, "gold", range(@t2, @t3))

      assert [_create, %{as_of: nil, as_of_range: %Ash.Range{} = as_of_range}] = events()
      assert {as_of_range.lower, as_of_range.upper} == {@t2, @t3}

      assert [
               %{plan: "bronze", valid_at: {@t1, @t2}},
               %{plan: "gold", valid_at: {@t2, @t3}},
               %{plan: "bronze", valid_at: {@t3, nil}}
             ] = versions(sub.id)
    end

    test "a range with an unbounded upper is recorded as a range, not an instant" do
      sub = create!(TrackedSubscription, "bronze", @t1)
      update!(sub, :update, "gold", range(@t2, nil))

      assert [_create, %{as_of: nil, as_of_range: %Ash.Range{} = as_of_range}] = events()
      assert {as_of_range.lower, as_of_range.upper} == {@t2, nil}

      assert [
               %{plan: "bronze", valid_at: {@t1, @t2}},
               %{plan: "gold", valid_at: {@t2, nil}}
             ] = versions(sub.id)

      assert_replays_identically()
    end

    test "a write without as_of records the now Ash pinned for it" do
      sub =
        TrackedSubscription
        |> Ash.Changeset.for_create(:create, %{plan: "bronze"}, actor: @actor)
        |> Ash.create!()

      [%{valid_at: {pinned, nil}, recorded_at: recorded_at}] = versions(sub.id)
      assert [%{as_of: ^pinned, as_of_range: nil, occurred_at: ^recorded_at}] = events()
      assert pinned == recorded_at
    end

    test "events of a non-temporal resource on an event log without record_as_of? are unaffected" do
      user =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(
          :create,
          %{email: "as_of@example.com", given_name: "As", family_name: "Of"},
          actor: @actor
        )
        |> Ash.create!()

      [event] =
        EventLog
        |> Ash.Query.filter(record_id == ^user.id)
        |> Ash.read!(authorize?: false)

      refute Map.has_key?(event, :as_of)
      refute Map.has_key?(event, :as_of_range)
    end

    # Documented limitation: a non-temporal tracked record written inside a
    # temporal write inherits its as_of through Ash's shared context, exactly as
    # when the as_of is passed directly. Its timestamps follow it, and so does an
    # occurred_at taken from its events create_timestamp.
    test "a non-temporal tracked write given an as_of stamps its timestamps and occurred_at with it" do
      backdated = ~U[2020-01-01 00:00:00.000000Z]

      user =
        AshEvents.Accounts.User
        |> Ash.Changeset.for_create(
          :create,
          %{email: "inherits@example.com", given_name: "In", family_name: "Herits"},
          as_of: backdated,
          actor: @actor
        )
        |> Ash.create!()

      assert user.created_at == backdated
      assert user.updated_at == backdated

      assert [%{occurred_at: ^backdated}] =
               EventLog
               |> Ash.Query.filter(record_id == ^user.id)
               |> Ash.read!(authorize?: false)
    end

    test "events of a non-temporal resource on an event log with record_as_of? have neither set" do
      compile_resource("AshEvents.TemporalEventsTest.NonTemporalOnTemporalLog",
        event_log: EventLogTemporal,
        temporal?: false
      )

      AshEvents.TemporalEventsTest.NonTemporalOnTemporalLog
      |> Ash.Changeset.for_create(:create, %{plan: "bronze"}, as_of: @t1, actor: @actor)
      |> Ash.create!()

      assert [%{as_of: nil, as_of_range: nil}] = events()
    end

    test "an as_of that is neither an instant nor a range raises" do
      changeset = %{Ash.Changeset.new(TrackedSubscription) | as_of: :not_a_time}

      assert_raise ArgumentError,
                   "expected the as_of of a write to the temporal resource " <>
                     "AshEvents.Accounts.TrackedSubscription to be a DateTime or an " <>
                     "Ash.Range, got: :not_a_time",
                   fn -> AshEvents.Events.ActionWrapperHelpers.as_of_params(changeset) end
    end

    # The tracked write's as_of rides in Ash's shared context; the event log is
    # never temporal, so its own defaults must not resolve to that as_of.
    test "an event log's utc_now default is the wall clock, not the write's as_of" do
      source = """
      defmodule AshEvents.TemporalEventsTest.LogWithDefault do
        use Ash.Resource,
          domain: AshEvents.TemporalEventsTest.Domain,
          data_layer: Ash.DataLayer.Ets,
          extensions: [AshEvents.EventLog]

        event_log do
          clear_records_for_replay AshEvents.EventLogs.ClearRecordsTemporal
          primary_key_type Ash.Type.UUIDv7
          record_as_of? true
        end

        attributes do
          attribute :logged_at, :utc_datetime_usec, default: &DateTime.utc_now/0
        end

        actions do
          defaults [:read]
        end
      end
      """

      capture_io(:stderr, fn -> Code.compile_string(source) end)
      log = AshEvents.TemporalEventsTest.LogWithDefault

      compile_resource("AshEvents.TemporalEventsTest.TrackedIntoLogWithDefault", event_log: log)

      backdated = ~U[2020-01-01 00:00:00.000000Z]
      before = DateTime.utc_now()

      AshEvents.TemporalEventsTest.TrackedIntoLogWithDefault
      |> Ash.Changeset.for_create(:create, %{plan: "bronze"}, as_of: backdated, actor: @actor)
      |> Ash.create!()

      after_write = DateTime.utc_now()

      assert [%{as_of: ^backdated, logged_at: logged_at}] = Ash.read!(log, authorize?: false)
      assert_wall_clock(logged_at, before, after_write)
    end

    # staleUpdateWritesNoEventTest
    test "T6: a backdated update with nothing valid at as_of is a StaleRecord and writes no event" do
      sub = create!(TrackedSubscription, "bronze", @t2)

      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Changes.StaleRecord{}]}} =
               sub
               |> Ash.Changeset.for_update(:update, %{plan: "gold"}, as_of: @t1, actor: @actor)
               |> Ash.update()

      assert Enum.map(events(), & &1.action) == [:create]
      assert [%{plan: "bronze", valid_at: {@t2, nil}}] = versions(sub.id)
    end

    test "a backdated hard destroy with nothing valid at as_of is a StaleRecord and writes no event" do
      sub = create!(TrackedSubscription, "bronze", @t2)

      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Changes.StaleRecord{}]}} =
               sub
               |> Ash.Changeset.for_destroy(:destroy, %{}, as_of: @t1, actor: @actor)
               |> Ash.destroy()

      assert Enum.map(events(), & &1.action) == [:create]
      assert [%{plan: "bronze", valid_at: {@t2, nil}}] = versions(sub.id)
    end
  end

  # On a temporal resource `occurred_at` is system time: the written version's
  # `recorded_at`, never the application-time `as_of` the write was backdated to.
  describe "occurred_at" do
    test "a backdated create's occurred_at is the version's recorded_at" do
      sub = create!(TrackedSubscription, "bronze", @t1)

      [%{recorded_at: recorded_at, inserted_at: @t1, updated_at: @t1}] = versions(sub.id)
      assert [%{occurred_at: ^recorded_at, as_of: @t1}] = events()
      assert recorded_at != @t1
    end

    test "a backdated update's occurred_at is the new version's recorded_at" do
      sub = create!(TrackedSubscription, "bronze", @t1)
      update!(sub, :update, "gold", @t2)

      [_bronze, %{plan: "gold", valid_at: {@t2, nil}, recorded_at: recorded_at}] =
        versions(sub.id)

      assert [_create, %{occurred_at: ^recorded_at, as_of: @t2}] = events()
      assert recorded_at != @t2
    end

    test "an upsert's occurred_at is the written version's recorded_at, on insert and on update" do
      id = Ash.UUID.generate()
      upsert!(id, "bronze", @t1)

      [%{valid_at: {@t1, nil}, recorded_at: inserted_recorded_at}] = versions(id)

      upsert!(id, "gold", @t2)

      [
        %{plan: "bronze", valid_at: {@t1, @t2}, recorded_at: ^inserted_recorded_at},
        %{plan: "gold", valid_at: {@t2, nil}, recorded_at: updated_recorded_at}
      ] = versions(id)

      assert [
               %{occurred_at: ^inserted_recorded_at, as_of: @t1},
               %{occurred_at: ^updated_recorded_at, as_of: @t2}
             ] = events()

      assert inserted_recorded_at != @t1
      assert updated_recorded_at != @t2
    end

    test "a soft destroy's occurred_at is the archived version's recorded_at" do
      sub = create!(TrackedSubscription, "bronze", @t1)

      sub
      |> Ash.Changeset.for_destroy(:archive, %{}, as_of: @t2, actor: @actor)
      |> Ash.destroy!()

      [
        %{valid_at: {@t1, @t2}, archived_at: nil},
        %{valid_at: {@t2, nil}, archived_at: @t2, recorded_at: recorded_at}
      ] = versions(sub.id)

      assert [_create, %{action: :archive, occurred_at: ^recorded_at, as_of: @t2}] = events()
      assert recorded_at != @t2
    end

    test "a hard destroy's occurred_at is the wall clock" do
      sub = create!(TrackedSubscription, "bronze", @t1)

      before = DateTime.utc_now()

      sub
      |> Ash.Changeset.for_destroy(:destroy, %{}, as_of: @t2, actor: @actor)
      |> Ash.destroy!()

      after_write = DateTime.utc_now()

      assert [_create, %{action: :destroy, occurred_at: occurred_at, as_of: @t2}] = events()
      assert_wall_clock(occurred_at, before, after_write)
      assert [%{valid_at: {@t1, @t2}}] = versions(sub.id)
    end

    test "temporal_occurred_at takes recorded_at from the changeset's change" do
      recorded_at = ~U[2026-01-01 00:00:00.000000Z]

      changeset =
        TrackedSubscription
        |> Ash.Changeset.new()
        |> Ash.Changeset.force_change_attribute(:recorded_at, recorded_at)

      assert {^changeset, ^recorded_at} =
               AshEvents.Events.ActionWrapperHelpers.temporal_occurred_at(changeset)
    end

    test "temporal_occurred_at stamps recorded_at with the wall clock when nothing changes it" do
      sub = create!(TrackedSubscription, "bronze", @t1)
      # An update changeset whose data has a recorded_at, but which doesn't change it.
      changeset = Ash.Changeset.new(sub)

      before = DateTime.utc_now()

      {changeset, occurred_at} =
        AshEvents.Events.ActionWrapperHelpers.temporal_occurred_at(changeset)

      assert_wall_clock(occurred_at, before, DateTime.utc_now())
      assert occurred_at != sub.recorded_at
      assert Ash.Changeset.fetch_change(changeset, :recorded_at) == {:ok, occurred_at}
    end

    test "temporal_occurred_at is the wall clock on a resource without recorded_at" do
      changeset = Ash.Changeset.new(TrackedSubscriptionNoRecordedAt)
      before = DateTime.utc_now()

      assert {^changeset, occurred_at} =
               AshEvents.Events.ActionWrapperHelpers.temporal_occurred_at(changeset)

      assert_wall_clock(occurred_at, before, DateTime.utc_now())
    end

    test "temporal_occurred_at is nil on a non-temporal resource" do
      changeset = Ash.Changeset.new(AshEvents.Accounts.User)

      assert {^changeset, nil} =
               AshEvents.Events.ActionWrapperHelpers.temporal_occurred_at(changeset)
    end

    test "without recorded_at, occurred_at is the wall clock" do
      before = DateTime.utc_now()
      sub = create!(TrackedSubscriptionNoRecordedAt, "bronze", @t1)
      update!(sub, :update, "gold", @t2)
      after_write = DateTime.utc_now()

      assert [
               %{as_of: @t1, occurred_at: created_at},
               %{as_of: @t2, occurred_at: updated_at}
             ] = events()

      assert_wall_clock(created_at, before, after_write)
      assert_wall_clock(updated_at, before, after_write)
    end
  end

  # Replay of EventLogTemporal must reproduce every version of every tracked
  # temporal record. Each test names the model test (model-tests.qnt) it mirrors.
  describe "replay" do
    # backdatedCreateTest
    test "T1: a backdated create replays to the same version" do
      sub = create!(TrackedSubscription, "bronze", @t1)

      assert [%{valid_at: {@t1, nil}, inserted_at: @t1, updated_at: @t1}] = versions(sub.id)
      assert_replays_identically()
    end

    # instantUpdateSplitsTest
    test "T2: an instant update replays to the same split" do
      sub = create!(TrackedSubscription, "bronze", @t1)
      update!(sub, :update, "gold", @t2)

      assert [
               %{plan: "bronze", valid_at: {@t1, @t2}},
               %{plan: "gold", valid_at: {@t2, nil}, inserted_at: @t1, updated_at: @t2}
             ] = versions(sub.id)

      assert_replays_identically()
    end

    # rangeUpdateLeftoverTest
    test "T3: a range update replays with the leftover keeping its timestamps" do
      sub = create!(TrackedSubscription, "bronze", @t1)
      [%{recorded_at: bronze_recorded_at}] = versions(sub.id)
      update!(sub, :update, "gold", range(@t2, @t3))

      assert [
               %{plan: "bronze", valid_at: {@t1, @t2}},
               %{plan: "gold", valid_at: {@t2, @t3}, updated_at: @t2},
               %{
                 plan: "bronze",
                 valid_at: {@t3, nil},
                 updated_at: @t1,
                 recorded_at: ^bronze_recorded_at
               }
             ] = versions(sub.id)

      assert_replays_identically()
    end

    # rangeUpdateDoesNotSpanTest (Decision 14: pins today's behaviour)
    test "T4: a range update over two versions touches only the first, original and replay alike" do
      sub = create!(TrackedSubscription, "bronze", @t1)
      update!(sub, :update, "silver", @t3)
      update!(sub, :update, "gold", range(@t2, @t4))

      assert [
               %{plan: "bronze", valid_at: {@t1, @t2}},
               %{plan: "gold", valid_at: {@t2, @t3}},
               %{plan: "silver", valid_at: {@t3, nil}, updated_at: @t3}
             ] = versions(sub.id)

      assert_replays_identically()
    end

    # destroyTrimsTest
    test "T5: a destroy replays to the same trimmed period" do
      sub = create!(TrackedSubscription, "bronze", @t1)
      update!(sub, :update, "gold", @t2)
      destroy!(sub, :destroy, @t4)

      assert [
               %{plan: "bronze", valid_at: {@t1, @t2}},
               %{plan: "gold", valid_at: {@t2, @t4}}
             ] = versions(sub.id)

      assert_replays_identically()
    end

    # upsertIntoGapTest, instance upsertAsCreate (Decision 9)
    test "T7: an upsert into a gap before a later version replays to the same bounded period" do
      id = Ash.UUID.generate()
      upsert!(id, "silver", @t3)
      upsert!(id, "bronze", @t1)

      assert [
               %{plan: "bronze", valid_at: {@t1, @t3}},
               %{plan: "silver", valid_at: {@t3, nil}}
             ] = versions(id)

      assert_replays_identically()
    end

    # upsertUpdatesTest
    test "T8: an upsert onto a valid version replays to the same split" do
      id = Ash.UUID.generate()
      upsert!(id, "bronze", @t1)
      upsert!(id, "gold", @t2)

      assert [
               %{plan: "bronze", valid_at: {@t1, @t2}},
               %{plan: "gold", valid_at: {@t2, nil}, updated_at: @t2}
             ] = versions(id)

      assert_replays_identically()
    end

    # backdatedCreateTest with as_of = the stamp
    test "T9: a write without as_of replays at the now Ash pinned for it" do
      sub =
        TrackedSubscription
        |> Ash.Changeset.for_create(:create, %{plan: "bronze"}, actor: @actor)
        |> Ash.create!()

      sub
      |> Ash.Changeset.for_update(:update, %{plan: "gold"}, actor: @actor)
      |> Ash.update!()

      assert [%{plan: "bronze"}, %{plan: "gold"}] = versions(sub.id)
      assert_replays_identically()
    end

    # replayPrefix
    test "T10: replay up to each event reproduces the state after that write" do
      a = create!(TrackedSubscription, "bronze", @t1)
      b_id = Ash.UUID.generate()

      writes = [
        fn -> update!(a, :update, "silver", @t3) end,
        fn -> upsert!(b_id, "bronze", @t2) end,
        fn -> destroy!(a, :destroy, @t4) end,
        # A correction recorded later, backdated into the middle of a's history.
        fn -> update!(a, :update, "gold", @t2) end,
        fn -> update!(a, :update, "platinum", range(@t1, @t2)) end,
        fn -> upsert!(b_id, "silver", @t3) end,
        fn -> archive!(b_id, @t4) end,
        fn -> upsert!(b_id, "gold", @t1) end,
        fn -> create!(TrackedSubscriptionNoRecordedAt, "bronze", @t2) end
      ]

      prefixes =
        [{last_event_id(), snapshot()}] ++
          Enum.map(writes, fn write ->
            write.()
            {last_event_id(), snapshot()}
          end)

      assert length(Enum.uniq_by(prefixes, &elem(&1, 0))) == length(writes) + 1

      for {event_id, expected} <- prefixes do
        :ok = AshEvents.EventLogs.replay_events_temporal!(%{last_event_id: event_id})

        assert snapshot() == expected, "replay up to event #{event_id} differs"
      end
    end

    # todayTests.issue103Test, now fixed
    test "T11: replaying a backdated create and update keeps both periods (#103)" do
      sub = create!(TrackedSubscription, "bronze", @t1)
      update!(sub, :update, "gold", @t2)

      :ok = AshEvents.EventLogs.replay_events_temporal!()

      assert [
               %{plan: "bronze", valid_at: {@t1, @t2}, inserted_at: @t1, updated_at: @t1},
               %{plan: "gold", valid_at: {@t2, nil}, inserted_at: @t1, updated_at: @t2}
             ] = versions(sub.id)
    end

    test "a soft destroy replays to the same archived version" do
      sub = create!(TrackedSubscription, "bronze", @t1)
      archive!(sub.id, @t2)

      assert [
               %{valid_at: {@t1, @t2}, archived_at: nil},
               %{valid_at: {@t2, nil}, archived_at: @t2}
             ] = versions(sub.id)

      assert_replays_identically()
    end

    test "a resource without recorded_at replays to the same versions" do
      sub = create!(TrackedSubscriptionNoRecordedAt, "bronze", @t1)
      update!(sub, :update, "gold", @t2)

      assert %{no_recorded_at: [_bronze, _gold]} = snapshot()
      assert_replays_identically()
    end

    test "a correction recorded later but backdated replays identically" do
      sub = create!(TrackedSubscription, "bronze", @t1)
      update!(sub, :update, "silver", @t3)
      update!(sub, :update, "gold", @t2)

      assert [
               %{plan: "bronze", valid_at: {@t1, @t2}},
               %{plan: "gold", valid_at: {@t2, @t3}},
               %{plan: "silver", valid_at: {@t3, nil}}
             ] = versions(sub.id)

      assert_replays_identically()
    end

    # Nothing is valid now, so replay must read the record as of the update.
    test "a backdated update to a record whose history ended replays identically" do
      sub = create!(TrackedSubscription, "bronze", @t1)
      destroy!(sub, :destroy, @t3)
      update!(sub, :update, "gold", @t2)

      assert [
               %{plan: "bronze", valid_at: {@t1, @t2}},
               %{plan: "gold", valid_at: {@t2, @t3}}
             ] = versions(sub.id)

      assert_replays_identically()
    end

    # Nothing is valid now either, so replay must read the record as of the destroy.
    test "a backdated destroy into an ended history replays identically" do
      sub = create!(TrackedSubscription, "bronze", @t1)
      destroy!(sub, :destroy, @t3)
      destroy!(sub, :destroy, @t2)

      assert [%{plan: "bronze", valid_at: {@t1, @t2}}] = versions(sub.id)
      assert Enum.map(events(), & &1.action) == [:create, :destroy, :destroy]

      assert_replays_identically()
    end

    # point_in_time cuts on occurred_at, which is system time, not as_of.
    test "point_in_time replay cuts on when a write was recorded, not on its as_of" do
      sub = create!(TrackedSubscription, "bronze", @t1)
      expected = versions(sub.id)

      :ok = AshEvents.EventLogs.replay_events_temporal!(%{point_in_time: @t2})
      assert versions(sub.id) == []

      :ok = AshEvents.EventLogs.replay_events_temporal!(%{point_in_time: DateTime.utc_now()})
      assert versions(sub.id) == expected
    end

    test "an :as_arguments action replays with its recorded_at" do
      sub = create!(TrackedSubscription, "bronze", @t1)
      update!(sub, :update_with_safe_change, "gold", @t2)

      assert [%{plan: "bronze"}, %{plan: "GOLD"}] = versions(sub.id)
      assert_replays_identically()
    end
  end

  describe "ApplyReplayRecordedAt" do
    @replayed_at ~U[2026-01-01 00:00:00.000000Z]
    @replay_context %{ash_events_replay?: true, ash_events_replay_recorded_at: @replayed_at}

    test "forces recorded_at on a replayed create" do
      changeset =
        Ash.Changeset.for_create(TrackedSubscription, :create, %{plan: "bronze"},
          as_of: @t1,
          context: @replay_context
        )

      assert Ash.Changeset.fetch_change(changeset, :recorded_at) == {:ok, @replayed_at}
    end

    test "forces recorded_at on a replayed soft destroy" do
      sub = create!(TrackedSubscription, "bronze", @t1)

      changeset =
        Ash.Changeset.for_destroy(sub, :archive, %{}, as_of: @t2, context: @replay_context)

      assert Ash.Changeset.fetch_change(changeset, :recorded_at) == {:ok, @replayed_at}
    end

    test "leaves a replayed hard destroy alone" do
      sub = create!(TrackedSubscription, "bronze", @t1)

      changeset =
        Ash.Changeset.for_destroy(sub, :destroy, %{}, as_of: @t2, context: @replay_context)

      assert Ash.Changeset.fetch_change(changeset, :recorded_at) == :error
    end

    test "leaves a write outside replay alone" do
      changeset =
        Ash.Changeset.for_create(TrackedSubscription, :create, %{plan: "bronze"},
          as_of: @t1,
          context: %{ash_events_replay_recorded_at: @replayed_at}
        )

      assert Ash.Changeset.fetch_change(changeset, :recorded_at) == :error
    end

    test "sets recorded_at atomically when Ash upgrades the replay to an atomic update" do
      changeset =
        TrackedSubscription
        |> Ash.Changeset.new()
        |> Ash.Changeset.set_context(@replay_context)

      assert AshEvents.Events.Changes.ApplyReplayRecordedAt.atomic(changeset, [], %{}) ==
               {:atomic, %{recorded_at: @replayed_at}}
    end

    test "does nothing on a resource without recorded_at" do
      changeset =
        Ash.Changeset.for_create(TrackedSubscriptionNoRecordedAt, :create, %{plan: "bronze"},
          as_of: @t1,
          context: @replay_context
        )

      assert AshEvents.Events.Changes.ApplyReplayRecordedAt.atomic(changeset, [], %{}) ==
               {:ok, changeset}
    end
  end

  describe "bulk" do
    test "a bulk create records as_of on every event" do
      assert %Ash.BulkResult{status: :success, records: records} =
               Ash.bulk_create(
                 [%{plan: "bronze"}, %{plan: "silver"}],
                 TrackedSubscription,
                 :create,
                 as_of: @t1,
                 actor: @actor,
                 return_records?: true,
                 return_errors?: true
               )

      assert length(records) == 2
      assert [%{as_of: @t1}, %{as_of: @t1}] = events()
      assert_occurred_at_is_recorded_at(records)
      assert_replays_identically()
    end

    test "a streamed bulk update records as_of on every event" do
      create!(TrackedSubscription, "bronze", @t1)
      create!(TrackedSubscription, "silver", @t1)

      assert %Ash.BulkResult{status: :success, records: records} =
               Ash.bulk_update(TrackedSubscription, :update, %{plan: "gold"},
                 strategy: :stream,
                 as_of: @t2,
                 actor: @actor,
                 return_records?: true,
                 return_errors?: true
               )

      assert length(records) == 2

      assert [_, _, %{action: :update, as_of: @t2}, %{action: :update, as_of: @t2}] = events()

      # Ash's manual bulk path doesn't apply update defaults; the wrapper does.
      for record <- records do
        assert [%{updated_at: @t1}, %{updated_at: @t2} = gold] = versions(record.id)

        assert %{occurred_at: occurred_at} =
                 Enum.find(events(), &(&1.action == :update and &1.record_id == record.id))

        assert occurred_at == gold.recorded_at
      end

      assert_replays_identically()
    end

    test "a streamed bulk destroy records as_of on every event" do
      create!(TrackedSubscription, "bronze", @t1)
      create!(TrackedSubscription, "silver", @t1)

      assert %Ash.BulkResult{status: :success} =
               Ash.bulk_destroy(TrackedSubscription, :destroy, %{},
                 strategy: :stream,
                 as_of: @t2,
                 actor: @actor,
                 return_errors?: true
               )

      assert [_, _, %{action: :destroy, as_of: @t2}, %{action: :destroy, as_of: @t2}] = events()
      assert_replays_identically()
    end

    test "a streamed bulk soft destroy records as_of on every event" do
      create!(TrackedSubscription, "bronze", @t1)
      create!(TrackedSubscription, "silver", @t1)

      assert %Ash.BulkResult{status: :success} =
               Ash.bulk_destroy(TrackedSubscription, :archive, %{},
                 strategy: :stream,
                 as_of: @t2,
                 actor: @actor,
                 return_errors?: true
               )

      assert [_, _, %{action: :archive, as_of: @t2}, %{action: :archive, as_of: @t2}] = events()

      for event <- Enum.drop(events(), 2) do
        assert [_, %{updated_at: @t2, archived_at: @t2}] = versions(event.record_id)
      end

      assert_replays_identically()
    end

    # Records as input: given a query, Ash validates as_of as a read option
    # before it reaches the range check, and raises on the range.
    test "a bulk update over a range is refused and writes no events" do
      sub = create!(TrackedSubscription, "bronze", @t1)

      assert %Ash.BulkResult{
               status: :error,
               errors: [%Ash.Error.Framework{errors: [%Ash.Error.Framework.NotAtomicOverRange{}]}]
             } =
               Ash.bulk_update([sub], :update, %{plan: "gold"},
                 strategy: :stream,
                 as_of: range(@t2, @t3),
                 actor: @actor,
                 return_errors?: true
               )

      assert Enum.map(events(), & &1.action) == [:create]
    end
  end

  # Writes

  defp create!(resource, plan, as_of) do
    resource
    |> Ash.Changeset.for_create(:create, %{plan: plan}, as_of: as_of, actor: @actor)
    |> Ash.create!()
  end

  defp update!(record, action, plan, as_of) do
    record
    |> Ash.Changeset.for_update(action, %{plan: plan}, as_of: as_of, actor: @actor)
    |> Ash.update!()
  end

  defp upsert!(id, plan, as_of) do
    TrackedSubscription
    |> Ash.Changeset.for_create(:create_upsert, %{id: id, plan: plan},
      as_of: as_of,
      actor: @actor
    )
    |> Ash.create!()
  end

  defp destroy!(record, action, as_of) do
    record
    |> Ash.Changeset.for_destroy(action, %{}, as_of: as_of, actor: @actor)
    |> Ash.destroy!()
  end

  defp archive!(id, as_of) do
    TrackedSubscription
    |> Ash.get!(id, as_of: as_of)
    |> destroy!(:archive, as_of)
  end

  defp range(lower, upper), do: %Ash.Range{lower: lower, upper: upper, bounds: :"[)"}

  # Reads

  defp events do
    EventLogTemporal
    |> Ash.Query.sort(id: :asc)
    |> Ash.read!(authorize?: false)
  end

  defp last_event_id do
    case List.last(events()) do
      nil -> 0
      event -> event.id
    end
  end

  # Every version of a TrackedSubscription, ordered by the start of its period.
  defp versions(id) do
    """
    SELECT plan, valid_at, inserted_at, updated_at, recorded_at, archived_at
    FROM tracked_subscriptions
    WHERE id = $1
    ORDER BY lower(valid_at)
    """
    |> AshEvents.TestRepo.query!([Ecto.UUID.dump!(id)])
    |> Map.fetch!(:rows)
    |> Enum.map(fn [plan, valid_at, inserted_at, updated_at, recorded_at, archived_at] ->
      assert valid_at.lower_inclusive and not valid_at.upper_inclusive

      %{
        plan: plan,
        valid_at: {bound(valid_at.lower), bound(valid_at.upper)},
        inserted_at: utc(inserted_at),
        updated_at: utc(updated_at),
        recorded_at: utc(recorded_at),
        archived_at: archived_at && utc(archived_at)
      }
    end)
  end

  defp bound(value) when value in [nil, :unbound], do: nil
  defp bound(value), do: utc(value)

  defp utc(%NaiveDateTime{} = value), do: DateTime.from_naive!(value, "Etc/UTC")
  defp utc(%DateTime{} = value), do: DateTime.shift_zone!(value, "Etc/UTC")

  # All versions of the tracked temporal tables, as stored.
  defp snapshot do
    %{
      tracked_subscriptions:
        rows("""
        SELECT id, valid_at, plan, inserted_at, updated_at, recorded_at, archived_at
        FROM tracked_subscriptions
        ORDER BY id, lower(valid_at)
        """),
      no_recorded_at:
        rows("""
        SELECT id, valid_at, plan, inserted_at, updated_at
        FROM tracked_subscriptions_no_recorded_at
        ORDER BY id, lower(valid_at)
        """)
    }
  end

  defp rows(sql), do: AshEvents.TestRepo.query!(sql).rows

  # Assertions

  # Replays EventLogTemporal and asserts every version of every tracked temporal
  # record is back exactly as it was.
  defp assert_replays_identically do
    expected = snapshot()
    :ok = AshEvents.EventLogs.replay_events_temporal!()
    assert snapshot() == expected
  end

  defp assert_wall_clock(value, before, after_write) do
    assert DateTime.compare(value, before) != :lt and DateTime.compare(value, after_write) != :gt,
           "expected #{value} to be the wall clock of the write (between #{before} and #{after_write})"
  end

  # Each record's event carries the recorded_at of the version it wrote.
  defp assert_occurred_at_is_recorded_at(records) do
    occurred_at = Map.new(events(), &{&1.record_id, &1.occurred_at})

    for record <- records do
      [%{recorded_at: recorded_at}] = versions(record.id)
      assert Map.fetch!(occurred_at, record.id) == recorded_at
    end
  end
end
