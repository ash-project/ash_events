<!--
SPDX-FileCopyrightText: 2024 Torkild G. Kjevik

SPDX-License-Identifier: MIT
-->

# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## [v0.8.2](https://github.com/ash-project/ash_events/compare/v0.8.1...v0.8.2) (2026-09-18)




### Bug Fixes:

* events: raise a DslError when a tracked action declares manual (#99) by [@Torkan](https://github.com/Torkan)

## [v0.8.1](https://github.com/ash-project/ash_events/compare/v0.8.0...v0.8.1) (2026-09-12)




### Bug Fixes:

* events: pass a Validation.Context to wrapped validations by [@Torkan](https://github.com/Torkan)

* events: raise on advisory lock failure instead of discarding the error by [@Torkan](https://github.com/Torkan)

* events: propagate notifications from event creation instead of dropping them by [@Torkan](https://github.com/Torkan)

* honour before_action?: true on validations of event-tracked actions by Fábio Pacheco [(#97)](https://github.com/ash-project/ash_events/pull/97)

## [v0.8.0](https://github.com/ash-project/ash_events/compare/v0.7.0...v0.8.0) (2026-09-11)




### Improvements:

* encryption: drop redundant base64 layer on encrypted event fields by [@Torkan](https://github.com/Torkan)

  Encrypted `data`, `changed_attributes` and `metadata` columns now hold raw
  Cloak ciphertext. Rows written by earlier releases are base64 text and keep
  decrypting through a read-time fallback, so no migration is required.

### Upgrade Notes:

* Ash `~> 3.33` is now required.

* `data`, `changed_attributes` and `metadata` are marked `sensitive?: true` on
  plain event logs and are omitted from `inspect` output and logs.

* The generated `ash_events_replay_<action>_update` action is `public?: false`
  and rejects any call that does not carry the replay context flag.

* Destroy actions now return data layer errors (stale record, foreign key
  restrict) instead of succeeding and recording an event. Destroys with atomic
  changes return an error tuple instead of raising.

* A missing `clear_records_for_replay` surfaces as `Ash.Error.Unknown`.

### Bug Fixes:

* encryption: decrypt ciphertext stored as base64 by releases before 0.8.0 by [@Torkan](https://github.com/Torkan)

* events: propagate destroy failures and write the event only after the row is gone by [@Torkan](https://github.com/Torkan)

* events: make the generated replay update action private and replay-only by [@Torkan](https://github.com/Torkan)

* event_log: mark data, changed_attributes and metadata as sensitive on plain event logs by [@Torkan](https://github.com/Torkan)

* replay: restore binary attributes from embedded event data (#64) by [@Torkan](https://github.com/Torkan)

* handle nil original_params in bulk destroy with nested operations (#89) by diogomrts [(#89)](https://github.com/ash-project/ash_events/pull/89)

### Chores:

* deps: bump `ash_cloak` to 0.4.0 and `ash_phoenix` to 2.3.25, clearing the published
  advisories for those packages. Both are `only: [:dev, :test]` dependencies and are not
  shipped to consumers of this library.

* build: the test harness now runs on Elixir 1.20.4 / OTP 29.0.6, and the test-repo
  migrations were regenerated for `ash_functions` v6 (`ash_postgres` 2.13.1).

## [v0.7.0](https://github.com/ash-project/ash_events/compare/v0.6.0...v0.7.0) (2026-03-29)




### Bug Fixes:

* handle bulk_destroy with soft delete (#85) by [@Torkan](https://github.com/Torkan)

* implement atomic/3 on replay changes for ignored action compatibility by [@Torkan](https://github.com/Torkan)

* clear managed relationships during replay and capture belongs_to FKs in changed_attributes by [@Torkan](https://github.com/Torkan)

* preserve ManageRelationship visibility for AshPhoenix nested forms (#87) by [@Torkan](https://github.com/Torkan)

## [v0.6.0](https://github.com/ash-project/ash_events/compare/v0.5.1...v0.6.0) (2026-02-04)




### Features:

* destroy: add soft delete support and comprehensive tests by [@Torkan](https://github.com/Torkan)

* add store_sensitive_attributes dsl option by [@Torkan](https://github.com/Torkan)

### Bug Fixes:

* replay: support non-writable UUID primary keys during replay by [@Torkan](https://github.com/Torkan)

* action-wrappers: handle nil source_context to allow actions without actor by [@Torkan](https://github.com/Torkan)

* upsert: use update_timestamp for occurred_at when upsert updates existing record by [@Torkan](https://github.com/Torkan)

* tests: remove duplicate atomic create test assertion by [@Torkan](https://github.com/Torkan)

* mix: move preferred_cli_env to cli/0 callback by [@Torkan](https://github.com/Torkan)

* events: return notifications from event creation to prevent missed notification warnings by [@Torkan](https://github.com/Torkan)

## v0.5.1 (2025-09-19)




### Bug Fixes:

* silence compile warnings when adding advisory xact lock by Torkild G. Kjevik

### Improvements:

* remove redundant verifier by Torkild G. Kjevik

## v0.5.0 (2025-09-19)




### Features:

* Properly distinguish between action input and changed attributes when storing events. by Torkild Kjevik

* Add public_fields-DSL in order to set fields in event logs as public. by Torkild Kjevik.

* Add verifiers for most DSL settings. by Torkild Kjevik.

### Bug Fixes:

* Ensure where-clauses in wrapped changes are respected. by Torkild Kjevik

* add replay validation wrapper to preserve validation messages. by Torkild Kjevik

* Ensure occurred_at is identical to create & update timestamps, enable tracking of changed attributes not in action input. by Torkild Kjevik

* Respect update_default values for attributes when running update actions. by Torkild Kjevik

## v0.4.4 (2025-08-21)




### Bug Fixes:

* Ignore params that are not action attributes or arguments when creating event. by Torkild Kjevik

## v0.4.3 (2025-07-17)




### Bug Fixes:

* properly cast all attrs/args before creating event. by Torkild G. Kjevik

* try converting value to existing atom before dumping. by Torkild G. Kjevik

## v0.4.2 (2025-07-02)




### Bug Fixes:

* include usage-rules in the package files by Zach Daniel

## v0.4.1 (2025-07-02)




### Bug Fixes:

* handle opts templates when replaying change modules by Zach Daniel

* Proper handling of validation modules in replay change wrapper. by Torkild Kjevik

## v0.4.0 (2025-06-25)




### Features:

* add create_timestamp & update_timestamp in events block. by Torkild Kjevik

* Add allowed_change_modules. by Torkild Kjevik

### Bug Fixes:

* add proper handling of embedded resources. by Torkild Kjevik

* make ash_events work seamlessly with policies & other extensions. by Torkild Kjevik

* handle ash_state_machine transitions. by Torkild Kjevik

* verify actor resources used in persist_actor_primary_key. by Torkild Kjevik

## v0.3.0 (2025-06-04)




### Features:

* add only_actions field in events-section.

### Bug Fixes:

* pass context from the parent to the child

## v0.2.0 (2025-05-19)

* Add option for using UUIDv7 as event log primary key
* Add Postgres transactional advisory locks when inserting events


## v0.1.1 (2025-05-08)


### Features:

* Igniter installer


## v0.1.0 (2025-05-06)
### Breaking Changes:

### Features:

* Initial feature set
