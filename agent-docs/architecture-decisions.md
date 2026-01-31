<!--
SPDX-FileCopyrightText: 2024 Torkild G. Kjevik

SPDX-License-Identifier: MIT
-->

# AshEvents Architecture Decisions

Key architectural decisions and their reasoning for AI assistant context.

## 2026-01-18: Event-Driven Replay Philosophy for Rerouted Actions

**Change**: Established that replay logic should not filter or transform event data for rerouted actions. Events are passed as-is; the target action is responsible for handling the data.

**Why**: This matches the behavior of other event-driven frameworks where an event is just data, and it's up to the recipient(s) to process it however they see fit. The alternative (replay logic being "smart" about filtering/transforming) would hide problems and make debugging harder.

**Impact**: Clear separation of concerns between event storage and event consumption.

**Key Principles**:
1. **Events are facts** - The event log stores what happened (`event.data` + `event.changed_attributes`). How that data is consumed is the recipient's responsibility.
2. **Explicit contracts** - Target actions explicitly define what they expect via `accept` list, `arguments`, and `skip_unknown_inputs`.
3. **No magic filtering** - Replay passes all merged data to rerouted actions. Runtime errors from mismatches are preferable to silent data loss.
4. **Developer responsibility** - Developers must ensure their rerouted actions can handle the events they receive, just like any event-driven system.

**Replay Behavior**:
- **Normal replay** (same resource/action): Uses `replay_non_input_attribute_changes` strategy (`:force_change` or `:as_arguments`)
- **Rerouted replay** (via `replay_overrides`): Merges all data into input, no `force_change`, target action handles filtering

**Pattern for Rerouted Backfill Actions**:
```elixir
defmodule TargetResource do
  events do
    event_log MyEventLog
    ignore_actions [:backfill_action]  # Only used for backfilling
  end

  actions do
    create :backfill_action do
      accept [:id, :email, :name, ...]  # Fields you need
      skip_unknown_inputs :*             # Ignore fields you don't care about
    end
  end

  attributes do
    uuid_primary_key :id do
      writable? true  # Required if accepting id as input
    end
  end
end
```

**Key Files**:
- `lib/event_log/replay.ex` - Separate handling for normal vs rerouted replay
- `lib/events/changes/apply_changed_attributes.ex` - Only used for normal replay with `:force_change` strategy

## 2026-01-18: Rerouted Upsert Action Handling

**Change**: Added special handling for rerouted actions that use `upsert? true`. Replay checks if the record exists by `event.record_id` and either updates (if exists) or creates (if not exists).

**Why**: PostgreSQL upsert (ON CONFLICT) doesn't work reliably in the replay context because:
1. When passing `id` as input alongside an ON CONFLICT on a different column (e.g., email), the primary key constraint fails before ON CONFLICT can trigger
2. Nested transactions during replay may interfere with upsert behavior

**Impact**: Rerouted upsert actions work correctly during replay.

**Key Behavior**:
- `upsert? true` on rerouted actions serves as a **flag** for replay logic, not for database upsert
- If record exists: update only the fields specified in `upsert_fields`
- If record doesn't exist: create normally with merged data

**Example Pattern**:
```elixir
create :sign_in_with_magic_link_replay do
  upsert? true                    # Flag for replay to apply upsert logic
  upsert_identity :unique_email   # Not used by DB, but documents intent
  upsert_fields [:email]          # Fields to update if record exists
  accept [:id, :email]            # id needed for new users
  skip_unknown_inputs [:*]
end
```

**Key Files**:
- `lib/event_log/replay.ex` - `handle_action/5` checks for rerouted upserts, `replay_rerouted_upsert_as_update/5` handles updates

## 2025-09-21: Array Binary Attribute Support

**Change**: Enhanced binary attribute encoding system to support arrays of binary values (`{:array, :binary}`)
**Why**: Single binary values were supported but arrays of binary data (cryptographic keys, binary tokens, encoded data collections) were not properly encoded/decoded during event storage and replay
**Impact**: Complete binary attribute support for both single values and arrays
**Key Files**:
- `lib/event_log/replay.ex` - Enhanced `decode_values_with_encoders()` for array binary decoding
- `test/support/accounts/user.ex` - Added `binary_keys` array binary attribute
- `test/ash_events/binary_attributes_test.exs` - Comprehensive tests
**Benefits**: Encoding metadata system (`"base64"` field encoding type) scales naturally to arrays by applying element-wise encoding while preserving array structure

## 2025-09-19: Changed Attributes Tracking Implementation

**Change**: Added comprehensive changed attributes tracking and replay functionality
**Why**: Event replay was incomplete for resources with business logic that modified attributes beyond original input parameters. Default values, auto-generated attributes (slugs, UUIDs, computed fields), and attributes modified by Ash changes/extensions were not captured in events
**Impact**: Complete state reconstruction for complex business logic scenarios. Two-strategy approach (`:force_change` vs `:as_arguments`) provides flexibility for different replay requirements
**Key Files**:
- `lib/event_log/transformers/add_attributes.ex` - Added `changed_attributes` field
- `lib/events/events.ex` - Added `replay_non_input_attribute_changes` DSL option
- `lib/events/changes/apply_changed_attributes.ex` - New change module
- `lib/events/action_wrapper_helpers.ex` - Capture changed attributes during event creation
- `lib/event_log/replay.ex` - Pass changed attributes context during replay
**Key Insights**:
- Event sourcing requires capturing not just input parameters but also all business logic transformations
- Separating original input (`event.data`) from business logic changes (`event.changed_attributes`) provides clear audit trails
- Context propagation in Ash action pipelines requires careful timing

## 2025-08-21: Parameter Filtering Enhancement

**Change**: Implemented filtering to ignore non-attribute/argument params when creating events
**Why**: Event creation was failing when extra parameters were present that weren't part of action schema
**Impact**: More robust event creation that handles real-world usage patterns with extra parameters
**Key Files**: `lib/events/*_action_wrapper.ex` and related event creation logic
**Benefits**: Event creation forgiving of parameter mismatches for complex applications

## 2025-07-17: Attribute/Argument Casting Improvements

**Change**: Enhanced casting of all attributes and arguments before event creation
**Why**: Events were being created with improperly cast values, causing issues during replay
**Impact**: More reliable event replay due to proper data type consistency
**Key Insights**: Proper type casting is critical for event replay functionality - data must be consistent

## 2025-07-17: Atom Conversion Safety

**Change**: Added safe atom conversion logic before dumping values
**Why**: Runtime errors when trying to convert values to atoms that didn't exist
**Impact**: More robust event handling with complex data types
**Key Insights**: Atom safety is crucial in event systems - need defensive programming for dynamic data

## 2025-06-25: Replay Change Module Improvements

**Change**: Enhanced handling of options templates in replay change modules
**Why**: Complex change modules with templates weren't replaying correctly
**Impact**: Sophisticated change modules now properly replayed
**Key Files**: `lib/event_log/replay.ex` and `lib/events/replay_change_wrapper.ex`

## 2025-06-25: Validation Module Replay Handling

**Change**: Improved validation module handling in replay change wrapper
**Why**: Validation modules during replay were causing issues with event processing
**Impact**: Event replay properly handles resources with validation modules
**Key Insights**: Replay must account for all Ash resource features, including validations

---

## Core Architecture Patterns

### Action Wrapper Architecture
**Current State**: Action wrappers (`create_action_wrapper.ex`, `update_action_wrapper.ex`, `destroy_action_wrapper.ex`) handle event creation
**Key Patterns**:
- Common functionality in `action_wrapper_helpers.ex`
- Parameter filtering and validation before event creation
- Consistent actor attribution handling
- Safe type casting and data serialization

### Replay Functionality Architecture
**Current State**: Centralized replay in `lib/event_log/replay.ex` with two distinct modes
**Key Patterns**:
- **Normal replay**: Uses `replay_non_input_attribute_changes` strategy, `ApplyChangedAttributes` change for `:force_change`
- **Rerouted replay**: Merges all event data into input, target action handles filtering via `skip_unknown_inputs`
- Replay change wrapper for handling complex change modules
- Template option handling for dynamic change configurations
- Validation module integration during replay
- Clear records implementation for clean replay state
- **Philosophy**: Events are data, consumers decide how to process them (see 2026-01-18 decision)

### DSL Extension Architecture
**Current State**: Two main extensions (EventLog and Events) with transformers and verifiers
**Key Patterns**:
- DSL definitions in main extension files
- Implementation logic in transformers
- Validation in verifiers
- Generated documentation from DSL definitions

---

## Entry Guidelines

### What to Include
- **Architectural decisions** that affect internal development
- **Implementation pattern changes** that change how code should be written
- **Internal bug fixes** that reveal important development insights
- **Development workflow improvements** and tool changes

### What to Exclude
- **User-facing feature additions** (these go in CHANGELOG.md)
- **Routine maintenance** without architectural impact
- **Documentation updates** without workflow changes

**Last Updated**: 2026-01-18
