<!--
SPDX-FileCopyrightText: 2024 Torkild G. Kjevik

SPDX-License-Identifier: MIT
-->

# AshEvents Internal Development Changelog

## Overview

This changelog provides context for the current state of internal AshEvents development and tracks the evolution of implementation approaches. It helps agents understand why certain patterns exist and the reasoning behind architectural decisions.

⚠️ **Note**: This tracks internal development decisions. For user-facing changes, see [CHANGELOG.md](../CHANGELOG.md).

## Entry Format

Each entry includes:
- **Date**: When the change was made
- **Change**: What was modified/added/removed internally
- **Context**: Why the change was necessary for development
- **Files**: Which files were affected
- **Impact**: How this affects future internal development
- **Key Insights**: Lessons learned or patterns discovered

---

## 2026-09-12

### Event Log Notifications Propagated Out of the Action Wrappers (#92)
**Change**: `create_event!/5` now returns the notifications produced by the event write, and each action wrapper hands them back to Ash instead of discarding them. Notifiers on an event log resource previously never fired.
**Context**: Events are written with `return_notifications?: true`, which makes Ash hand the notifications to the caller rather than dispatching them. All three wrappers ignored the `Ash.create!/3` return value, so those notifications were silently dropped. Reported with a failing test by Rekkice in #92.
**Files**:
- `lib/events/action_wrapper_helpers.ex` - `create_event!/5` returns notifications; new `notifications_result/3` and `bulk_changeset?/1`
- `lib/events/create_action_wrapper.ex`, `lib/events/update_action_wrapper.ex` - return the notifications in the shape the enclosing pipeline expects
- `lib/events/destroy_action_wrapper.ex` - same for soft destroy and bulk destroy; `destroy_result/3` documents why single hard destroys still drop them; `tag_bulk_ref/2` lets Ash re-associate the changeset by ref
- `test/support/test_notifier.ex`, `test/support/event_logs/event_log.ex` - notifier that forwards notifications to a registered test pid
- `test/ash_events/notifications_test.exs` - regression tests per action type, single and bulk
- `test/ash_events/bulk_actions_test.exs` - per-resource notification breakdown instead of a bare count; the old counts encoded the dropped notifications
- `README.md` - Notifiers on the Event Log section, including the hard destroy limitation
**Impact**: Anything that hangs off the event log through a notifier (PubSub broadcast, outbox dispatch, projection updates) now works, for create, update, soft destroy and every bulk action. Single hard destroys are the one remaining gap.
**Key Insights**: Ash asks for two incompatible manual action result shapes. The single-record create/update pipelines accept only `{:ok, record, %{notifications: [...]}}` (`validate_manual_action_return_result!/3` raises `InvalidReturnType` on a bare list), while `Ash.Actions.BulkManualActionHelpers.process_non_bulk_result/6` passes the third element straight to `store_notification/3`, which treats a non-list as a single notification. The `:bulk_create`/`:bulk_update`/`:bulk_destroy` context key that the bulk pipelines put on their changesets is the only way to tell the two apart. The single destroy pipeline cannot carry notifications at all: `validate_manual_action_return_result!/3` accepts a bare list, but `manage_relationships/4` and the notify step after it only match `%{notifications: ...}`, so the 3-tuple falls through `other -> other` and takes the destroyed record's own notifications with it -- returning the 2-tuple and dropping only the event's notification is the lesser loss until Ash normalises that shape. `Ash.Notifier.notify/1` is not a workaround either: it returns notifications unsent when the resource is in a transaction, which is exactly where the wrapper runs.

---

## 2026-09-08

### Security Report Triage (reports 2873, 2874, 2879)
**Change**: Assessed three externally reported findings and applied targeted hardening. Plain event log payload columns (`data`, `changed_attributes`, `metadata`) are now `sensitive?: true`; the destroy wrapper propagates data layer failures instead of discarding them; the auto-generated `ash_events_replay_<name>_update` action is `public?: false` and carries a `ReplayOnly` validation that rejects any changeset without the `ash_events_replay?` context marker.
**Context**: See `agent-docs/cves/cve-summary.md` (local only, the folder is gitignored) for the full assessment. Key decision: the library will not attempt per-attribute redaction of `changed_attributes`. The `data` filter is param-keyed and cannot see derived values, replay needs derived secrets such as `hashed_password`, and the `store_sensitive_attributes` allowlist was already tried and reverted. The documented stance is now: use `cloak_vault` for any resource with sensitive data.
**Files**:
- `lib/event_log/transformers/add_attributes.ex` - `sensitive?: true` on plain payload attributes
- `lib/events/destroy_action_wrapper.ex` - propagates `data_layer.destroy/2` errors, writes the event only after the data layer call succeeds (matching the create wrapper), and rejects atomic changes before touching the data layer
- `lib/events/action_wrapper_helpers.ex` - `atomics_error/0` shared by the helper and the destroy wrapper
- `lib/events/validations/replay_only.ex` - new validation module
- `lib/events/transformers/wrap_actions.ex` - attach validation and update description of the generated action
- `test/ash_events/security_reports_test.exs` - regression tests, one `describe` per report, including bulk and atomic entry points
- `test/ash_events/replay_error_paths_test.exs` - create failing at the data layer, validations failing at replay time (with and without custom message), replay aborting mid-stream, and orphaned update/destroy events
- `test/support/event_logs/clear_records.ex` - now also clears `orgs` and `org_details`; both log to the plain event log but were never cleared, so any replay test that created an org failed on a duplicate id
- `README.md`, `usage-rules.md` - new Sensitive Data and Auto-Generated Replay Actions sections; removed stale `store_sensitive_attributes` text
**Impact**: Every wrapped action and the generated replay action now share the same trust model: the `ash_events_replay?` context key is the only thing that switches off event logging, and it is settable only by application code. Destroy failures on Postgres (stale record, FK restrict, permission errors) now surface as errors and no destroy event is committed for a surviving row, including in `Ash.bulk_destroy` with `strategy: :stream`, where Ash does not roll back the batch on a per-record manual action error. The update wrapper still writes its event before calling the data layer and has the same bulk exposure; it was left as is pending a decision.
**Key Insights**: Ecto omits `redact: true` fields from `inspect` output entirely rather than printing a placeholder; tests should assert absence of the field, not presence of a marker. AshPostgres returns `Ash.Error.Changes.StaleRecord` when a destroy affects zero rows, which makes "destroy the same struct twice" a reliable way to exercise the failure path. In bulk stream actions Ash tags manual action errors as `{:error, error, changeset}` and processes them outside the batch transaction, so the batch commits; `Ash.Actions.Helpers.rollback_if_in_transaction/3` also explicitly skips rollback for `StaleRecord`. The only reliable protection is to write the event after the data layer call succeeds. The replay generic action does not run in a transaction: a failing event raises `Ash.Error.Invalid` out of `replay_events/0`, records are already cleared, and events before the failure stay applied. Postgrex JSON-encodes `jsonb` parameters itself, so pass raw Elixir values when tampering with event data in tests, not `Jason.encode!` output.

---

## 2025-09-21

### Array Binary Attribute Support Implementation
**Change**: Enhanced binary attribute encoding system to support arrays of binary values (`{:array, :binary}`)
**Context**: The existing binary attribute encoding only handled single binary values. Arrays of binary data (e.g., lists of cryptographic keys, binary tokens, or encoded data collections) were not properly encoded/decoded during event storage and replay. This enhancement extends the Base64 encoding system to handle array structures while maintaining the same encoding metadata approach.
**Files**:
- `lib/event_log/replay.ex` - Enhanced `decode_values_with_encoders()` to handle array binary decoding
- `test/support/accounts/user.ex` - Added `binary_keys` array binary attribute and generator function
- `test/ash_events/binary_attributes_test.exs` - Added comprehensive array binary encoding/decoding tests
- `priv/test_repo/migrations/20250921142423_add_binary_keys_to_users.exs` - Migration for test infrastructure
- `event_field_encoders.md` - Updated documentation to include array binary support
**Impact**: AshEvents now provides complete binary attribute support for both single values and arrays. Agents can rely on array binary attributes working seamlessly with event storage and replay. The encoding metadata system scales naturally to array structures.
**Key Insights**: The existing encoding metadata approach (`"base64"` for field encoding type) scales effectively to arrays by applying element-wise encoding while preserving array structure. The replay logic needed minimal changes - just handling list values in addition to binary values when decoding Base64 data.

---

## 2025-09-19

### Agent Documentation Structure Scaffolding
**Change**: Created comprehensive agent documentation structure following scaffolding framework
**Context**: Needed proper internal development documentation separated from consumer documentation (usage-rules.md)
**Files**: `AGENTS.md`, `agent-docs/changelog.md`, `agent-docs/` directory structure
**Impact**: Agents now have proper guidance for working ON AshEvents development vs using AshEvents as dependency
**Key Insights**: Clear separation between consumer docs (usage-rules.md) and developer docs (agent-docs/) significantly improves development workflow

### Documentation Focus Clarification
**Change**: Clarified that usage-rules.md is consumer documentation, not internal development guidance
**Context**: Previous documentation incorrectly referenced usage-rules.md for internal development tasks
**Files**: `AGENTS.md`, updated understanding of documentation structure
**Impact**: Agents now correctly understand the distinction between internal development and consumer usage
**Key Insights**: Documentation scope must be clearly defined - internal vs external usage have completely different needs

### Documentation Update Guide Correction
**Change**: Fixed `agent-docs/documentation-update-guide.md` to reference existing `AGENTS.md` instead of non-existent `agent-docs/index.md`
**Context**: The documentation update guide was referencing a file that no longer exists, making the workflow guidance incorrect for agents
**Files**: `agent-docs/documentation-update-guide.md`
**Impact**: Agents now have correct guidance for updating documentation with proper entry point references
**Key Insights**: Documentation maintenance guides must stay current with actual file structure to remain useful

---

## 2025-09-19 (Continued)

### Changed Attributes Tracking Implementation
**Change**: Added comprehensive changed attributes tracking and replay functionality to AshEvents core
**Context**: Event replay was incomplete for resources with business logic that modified attributes beyond the original input parameters. Default values, auto-generated attributes (slugs, UUIDs, computed fields), and attributes modified by Ash changes/extensions were not being captured in events, causing incomplete state reconstruction during replay. This is a critical gap for real-world event sourcing applications where business logic transforms input data.
**Files**:
- `lib/event_log/transformers/add_attributes.ex` - Added `changed_attributes` field to event resources
- `lib/events/events.ex` - Added `replay_non_input_attribute_changes` DSL option
- `lib/events/changes/apply_changed_attributes.ex` - New change module for applying changed attributes during replay
- `lib/events/action_wrapper_helpers.ex` - Modified to capture changed attributes during event creation
- `lib/event_log/replay.ex` - Enhanced to pass changed attributes context during replay
- `test/ash_events/changed_attributes_test.exs` - Comprehensive test coverage
**Impact**: AshEvents now supports complete state reconstruction for complex business logic scenarios. This enables proper event sourcing for applications with extensive attribute transformations, default value applications, and computed field generation. The two-strategy approach (`:force_change` vs `:as_arguments`) provides flexibility for different replay requirements.
**Key Insights**:
- Event sourcing requires capturing not just input parameters but also all business logic transformations
- Separating original input (`event.data`) from business logic changes (`event.changed_attributes`) provides clear audit trails
- Context propagation in Ash action pipelines requires careful timing - changes must have context available from the start
- Both atom and string key handling is critical for form compatibility in web applications
- Testing replay functionality requires proper database cleanup patterns to avoid interference between create/destroy events

---

## 2025-08-21 (Inferred from CHANGELOG.md)

### Parameter Filtering Enhancement
**Change**: Implemented filtering to ignore non-attribute/argument params when creating events
**Context**: Event creation was failing when extra parameters were present that weren't part of action schema
**Files**: Likely `lib/events/*_action_wrapper.ex` files and related event creation logic
**Impact**: More robust event creation that handles real-world usage patterns with extra parameters
**Key Insights**: Event creation needs to be forgiving of parameter mismatches to work with complex applications

---

## 2025-07-17 (Inferred from CHANGELOG.md)

### Attribute/Argument Casting Improvements
**Change**: Enhanced casting of all attributes and arguments before event creation
**Context**: Events were being created with improperly cast values, causing issues during replay
**Files**: Event creation logic in action wrappers
**Impact**: More reliable event replay due to proper data type consistency
**Key Insights**: Proper type casting is critical for event replay functionality - data must be consistent

### Atom Conversion Safety
**Change**: Added safe atom conversion logic before dumping values
**Context**: Runtime errors when trying to convert values to atoms that didn't exist
**Files**: Event serialization/deserialization logic
**Impact**: More robust event handling with complex data types
**Key Insights**: Atom safety is crucial in event systems - need defensive programming for dynamic data

---

## 2025-07-02 (Inferred from CHANGELOG.md)

### Usage Rules Package Inclusion
**Change**: Added usage-rules.md to package files in mix.exs
**Context**: Consumer documentation wasn't being included in releases
**Files**: `mix.exs` package files configuration
**Impact**: Consumers now have proper documentation included with package installations
**Key Insights**: Consumer documentation must be explicitly included in package files for distribution

---

## 2025-06-25 (Inferred from CHANGELOG.md)

### Replay Change Module Improvements
**Change**: Enhanced handling of options templates in replay change modules
**Context**: Complex change modules with templates weren't replaying correctly
**Files**: Replay logic in `lib/event_log/replay.ex` and change wrapper functionality
**Impact**: More sophisticated change modules can now be properly replayed
**Key Insights**: Replay functionality must handle all possible change module patterns, including templated options

### Validation Module Replay Handling
**Change**: Improved validation module handling in replay change wrapper
**Context**: Validation modules during replay were causing issues with event processing
**Files**: `lib/events/replay_change_wrapper.ex` and related replay logic
**Impact**: Event replay now properly handles resources with validation modules
**Key Insights**: Replay must account for all Ash resource features, including validations

---

## Development Pattern Evolution

### Action Wrapper Architecture
**Current State**: Action wrappers (`create_action_wrapper.ex`, `update_action_wrapper.ex`, `destroy_action_wrapper.ex`) handle event creation
**Key Patterns**:
- Common functionality in `action_wrapper_helpers.ex`
- Parameter filtering and validation before event creation
- Consistent actor attribution handling
- Safe type casting and data serialization

### Replay Functionality Architecture
**Current State**: Centralized replay in `lib/event_log/replay.ex` with sophisticated change handling
**Key Patterns**:
- Replay change wrapper for handling complex change modules
- Template option handling for dynamic change configurations
- Validation module integration during replay
- Clear records implementation for clean replay state

### Testing Architecture
**Current State**: Comprehensive test coverage with realistic test resources
**Key Patterns**:
- Test resources in `test/support/` mirror real-world usage
- Specific test files for each feature area
- Mix aliases for database management (`mix test.reset`, etc.)
- Test environment configuration in `mix.exs`

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
- **Testing pattern evolution** and quality improvements
- **Build and deployment changes** affecting development

### What to Exclude
- **User-facing feature additions** (these go in CHANGELOG.md)
- **Routine maintenance** without architectural impact
- **External dependency updates** without internal impact
- **Documentation updates** without workflow changes

### Writing Style
- **Focus on development impact** rather than user impact
- **Include technical reasoning** for architectural decisions
- **Reference specific files and patterns** for future development
- **Highlight insights** that apply to future internal work
- **Use present tense** for current state descriptions
- **Use past tense** for completed changes

### Update Frequency
- **After significant architectural decisions** affecting development workflow
- **When development patterns change** or evolve
- **After complex bug fixes** that reveal important insights
- **When build or testing processes change**
- **After major internal refactoring** efforts

---

**Last Updated**: 2025-01-25
**Focus**: Internal development context and decisions
**Next Review**: After next major internal development milestone
