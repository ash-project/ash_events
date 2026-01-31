# AshEvents Test Coverage Improvement Plan

## Overview

**Current State:**
- 21 test files, ~3,410 lines of test code
- ~68% overall coverage
- Strong coverage for core functionality (events, replay, authentication)
- Critical gap: 13 verifier modules with only ~8% coverage

**Target State (Gold Standard):**
- Systematic organization by concern
- Comprehensive verifier testing
- Reusable test helpers and assertions
- Edge case and error scenario coverage
- All transformers and mix tasks tested

**Reference:** ash_typescript has 131 test files, ~1,647 tests, ~42,595 lines

---

## Work Tracking Rules

> **IMPORTANT:** Mark each task as completed **immediately** after finishing it.
> Do not postpone completion marking until the end of a session.
> This ensures accurate progress tracking and prevents duplicate work.

---

## Phase 1: Test Infrastructure & Organization

**Goal:** Establish proper test infrastructure and organization before adding tests.

### Tasks

- [ ] **1.1** Create `test/support/test_helpers.ex` module with reusable setup functions:
  - `create_user/1` - Create test user with actor
  - `create_event/2` - Create test event with options
  - `run_replay/2` - Execute replay with assertions
  - `assert_event_created/2` - Verify event was logged
  - `assert_event_matches/2` - Verify event data matches expectations
  - `with_actor/2` - Wrap action with actor

- [ ] **1.2** Create `test/support/assertions.ex` module with custom assertions:
  - `assert_events_count/2` - Assert number of events created
  - `assert_actor_attributed/2` - Assert actor is properly set
  - `assert_replay_successful/1` - Assert replay completed without errors
  - `assert_changed_attributes/3` - Assert changed attributes match

- [ ] **1.3** Reorganize test directory structure:
  ```
  test/ash_events/
  ├── event_log/           # EventLog DSL tests
  │   ├── verifiers/       # Verifier tests
  │   └── transformers/    # Transformer tests
  ├── events/              # Events extension tests
  │   ├── verifiers/       # Verifier tests
  │   └── changes/         # Change module tests
  ├── replay/              # Replay mechanism tests
  ├── integration/         # End-to-end workflows
  └── errors/              # Error scenarios
  ```

- [ ] **1.4** Add shared test setup module `test/support/shared_setup.ex`:
  - Common database setup
  - Event log clearing helpers
  - Tenant setup helpers

---

## Phase 2: Verifier Testing (Critical Gap)

**Goal:** Test all 13 verifier modules that currently have minimal coverage.

### EventLog Verifiers

- [ ] **2.1** Create `test/ash_events/event_log/verifiers/verify_actor_modules_test.exs`:
  - Test valid actor module configurations
  - Test invalid actor module types (non-modules)
  - Test missing actor module
  - Test error messages are clear

- [ ] **2.2** Create `test/ash_events/event_log/verifiers/verify_advisory_lock_config_test.exs`:
  - Test valid advisory lock configuration
  - Test invalid lock generator modules
  - Test missing configuration scenarios
  - Test multitenancy lock configuration

- [ ] **2.3** Create `test/ash_events/event_log/verifiers/verify_clear_records_for_replay_test.exs`:
  - Test valid clear records configuration
  - Test missing clear_records_for_replay error
  - Test invalid clear records module
  - Test clear records function validation

- [ ] **2.4** Create `test/ash_events/event_log/verifiers/verify_cloak_vault_test.exs`:
  - Test valid Cloak vault configuration
  - Test missing vault when encryption enabled
  - Test invalid vault module
  - Test vault connection verification

- [ ] **2.5** Create `test/ash_events/event_log/verifiers/verify_public_fields_test.exs`:
  - Test valid public_fields configuration
  - Test invalid field names
  - Test field type validation
  - *(Some coverage exists - extend it)*

- [ ] **2.6** Create `test/ash_events/event_log/verifiers/verify_record_id_type_test.exs`:
  - Test valid record ID types (UUID, UUIDv7, integer)
  - Test invalid record ID types
  - Test type mismatch scenarios

- [ ] **2.7** Create `test/ash_events/event_log/verifiers/verify_replay_overrides_test.exs`:
  - Test valid replay override configurations
  - Test invalid override actions
  - Test missing override handlers

- [ ] **2.8** Create `test/ash_events/event_log/verifiers/verify_persist_actor_primary_key_test.exs`:
  - Test valid actor primary key persistence
  - Test type mismatches
  - Test missing required configuration

### Events Extension Verifiers

- [ ] **2.9** Create `test/ash_events/events/verifiers/verify_actions_test.exs`:
  - Test action wrapping configuration
  - Test invalid action names
  - Test action type validation

- [ ] **2.10** Create `test/ash_events/events/verifiers/verify_event_log_test.exs`:
  - Test valid event_log reference
  - Test missing event_log configuration
  - Test invalid event_log module

- [ ] **2.11** Create `test/ash_events/events/verifiers/verify_replay_non_input_attribute_changes_test.exs`:
  - Test valid replay strategies (:force_change, :as_arguments)
  - Test invalid strategy values
  - Test strategy per action configuration

- [ ] **2.12** Create `test/ash_events/events/verifiers/verify_store_sensitive_attributes_test.exs`:
  - Test sensitive attribute configuration
  - Test invalid attribute names
  - Test attribute type validation

- [ ] **2.13** Create `test/ash_events/events/verifiers/verify_timestamps_test.exs`:
  - Test timestamp field configuration
  - Test timestamp precision settings
  - Test missing timestamp fields

---

## Phase 3: Transformer Testing

**Goal:** Test transformer modules that set up DSL attributes and actions.

### Tasks

- [ ] **3.1** Create `test/ash_events/event_log/transformers/add_attributes_test.exs`:
  - Test attribute injection into EventLog
  - Test attribute types and constraints
  - Test attribute naming conventions
  - Test encryption attribute setup

- [ ] **3.2** Create `test/ash_events/event_log/transformers/add_actions_test.exs`:
  - Test action injection for replay
  - Test action argument setup
  - Test action authorization settings

- [ ] **3.3** Create `test/ash_events/events/transformers/wrap_actions_test.exs`:
  - Test action wrapper injection
  - Test create/update/destroy wrapping
  - Test bulk action wrapping
  - Test action argument preservation

---

## Phase 4: Action Wrapper Helpers Testing

**Goal:** Add direct tests for action wrapper helpers (currently only indirectly tested).

### Tasks

- [ ] **4.1** Create `test/ash_events/events/action_wrapper_helpers_test.exs`:
  - Test `get_event_data/2` - extracting event data from changeset
  - Test `build_event_changeset/3` - creating event changeset
  - Test `extract_changed_attributes/2` - tracking attribute changes
  - Test `store_actor_info/2` - actor attribution logic
  - Test edge cases: nil actor, system actor, missing fields

- [ ] **4.2** Create `test/ash_events/events/changes/store_changeset_params_test.exs`:
  - Test parameter extraction from changesets
  - Test argument handling
  - Test nested parameter structures
  - *(Some indirect coverage exists - add direct tests)*

- [ ] **4.3** Create `test/ash_events/events/changes/apply_changed_attributes_test.exs`:
  - Test attribute application logic
  - Test :force_change strategy
  - Test :as_arguments strategy
  - *(Some indirect coverage exists - add direct tests)*

---

## Phase 5: Error Scenarios & Edge Cases

**Goal:** Comprehensive error scenario testing like ash_typescript's error_handling_test.exs.

### Tasks

- [ ] **5.1** Create `test/ash_events/errors/event_creation_errors_test.exs`:
  - Test event creation without actor (should fail gracefully)
  - Test event creation with invalid data
  - Test event creation during transaction rollback
  - Test concurrent event creation conflicts

- [ ] **5.2** Create `test/ash_events/errors/replay_errors_test.exs`:
  - Test replay with missing events
  - Test replay with corrupted event data
  - Test replay with missing actor modules
  - Test replay with schema version mismatch
  - Test replay interruption and recovery
  - Test replay with no events (empty log)

- [ ] **5.3** Create `test/ash_events/errors/encryption_errors_test.exs`:
  - Test decryption with wrong key
  - Test encryption with missing vault
  - Test encrypted data migration scenarios
  - Test key rotation handling

- [ ] **5.4** Create `test/ash_events/errors/clear_records_errors_test.exs`:
  - Test clear records partial failure
  - Test clear records with constraints
  - Test clear records timeout scenarios

- [ ] **5.5** Create `test/ash_events/errors/advisory_lock_errors_test.exs`:
  - Test lock acquisition failure
  - Test lock timeout scenarios
  - Test lock release failures

---

## Phase 6: Mix Task Testing

**Goal:** Test mix installation task.

### Tasks

- [ ] **6.1** Create `test/ash_events/mix/install_test.exs`:
  - Test installation scaffolding
  - Test file generation
  - Test configuration injection
  - Test idempotent installation (running twice)
  - Test installation with existing files

---

## Phase 7: Integration & Workflow Testing

**Goal:** Add comprehensive integration tests covering complete workflows.

### Tasks

- [ ] **7.1** Create `test/ash_events/integration/complete_lifecycle_test.exs`:
  - Full CRUD cycle with events
  - Verify all events captured
  - Verify actor attribution throughout
  - Verify replay reconstructs state exactly

- [ ] **7.2** Create `test/ash_events/integration/multitenancy_test.exs`:
  - Test events with tenant context
  - Test replay within tenant
  - Test cross-tenant isolation
  - Test tenant advisory locks

- [ ] **7.3** Create `test/ash_events/integration/version_migration_test.exs`:
  - Test schema evolution with versioned events
  - Test replay across version boundaries
  - Test forward/backward compatibility

- [ ] **7.4** Create `test/ash_events/integration/high_volume_test.exs`:
  - Test bulk event creation (1000+ events)
  - Test replay performance with large event log
  - Test memory usage during replay
  - Test streaming replay for large datasets

- [ ] **7.5** Enhance existing `test/ash_events/replay_test.exs`:
  - Add point-in-time replay tests
  - Add selective event replay tests
  - Add replay with event filtering
  - Add replay idempotency tests

---

## Phase 8: Specialized Feature Testing

**Goal:** Ensure complete coverage of specialized features.

### Tasks

- [ ] **8.1** Enable and fix `test/ash_events/binary_attributes_test.exs`:
  - Remove `@describetag :skip`
  - Fix binary encoding/decoding tests
  - Add array of binaries tests
  - Coordinate with Ash core if needed

- [ ] **8.2** Enhance `test/ash_events/encryption_test.exs`:
  - Test encryption with different algorithms
  - Test encrypted metadata
  - Test encrypted actor data
  - Test encryption performance impact

- [ ] **8.3** Enhance `test/ash_events/state_machine_test.exs`:
  - Test all state transition scenarios
  - Test invalid transition attempts
  - Test state machine replay edge cases

- [ ] **8.4** Enhance `test/ash_events/embedded_resources_test.exs`:
  - Test deeply nested embedded resources (3+ levels)
  - Test embedded resource arrays
  - Test embedded resource updates
  - Test embedded resource deletion

- [ ] **8.5** Create `test/ash_events/features/custom_advisory_lock_generators_test.exs`:
  - Test custom lock generator implementation
  - Test generator with custom key formats
  - Test generator error handling

---

## Phase 9: Documentation & Examples

**Goal:** Ensure test documentation and examples are comprehensive.

### Tasks

- [ ] **9.1** Add `@moduledoc` and `@doc` to all test helper modules:
  - Document purpose and usage
  - Provide examples

- [ ] **9.2** Create `test/support/TESTING.md`:
  - Document test organization
  - Explain helper modules
  - Provide patterns for adding new tests

- [ ] **9.3** Add inline documentation to complex test scenarios:
  - Explain what is being tested
  - Document expected behavior
  - Note any workarounds or known issues

---

## Progress Summary

| Phase | Description | Tasks | Completed |
|-------|-------------|-------|-----------|
| 1 | Test Infrastructure | 4 | 0 |
| 2 | Verifier Testing | 13 | 0 |
| 3 | Transformer Testing | 3 | 0 |
| 4 | Action Wrapper Helpers | 3 | 0 |
| 5 | Error Scenarios | 5 | 0 |
| 6 | Mix Task Testing | 1 | 0 |
| 7 | Integration Testing | 5 | 0 |
| 8 | Specialized Features | 5 | 0 |
| 9 | Documentation | 3 | 0 |
| **Total** | | **42** | **0** |

---

## Expected Outcome

After completing all phases:

- **Test files:** ~60-70 (from 21)
- **Test coverage:** ~95%+ (from 68%)
- **Test lines:** ~10,000+ (from 3,410)
- **All verifiers tested:** Yes (from 8%)
- **All transformers tested:** Yes (from indirect)
- **Error scenarios:** Comprehensive
- **Integration tests:** Complete lifecycle coverage

---

## Notes

- Phases can be worked on in parallel where there are no dependencies
- Phase 2 (Verifiers) is the highest priority - this is the critical gap
- Each task should include both positive and negative test cases
- Use existing test patterns from ash_typescript as reference
- Maintain async: false for database-dependent tests
