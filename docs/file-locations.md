# File Locations Reference

## Core Extensions
- `lib/events/events.ex` - Events extension DSL definition
- `lib/event_log/event_log.ex` - EventLog extension DSL definition

## Action Wrappers
- `lib/events/create_action_wrapper.ex` - Wraps create actions
- `lib/events/update_action_wrapper.ex` - Wraps update actions  
- `lib/events/destroy_action_wrapper.ex` - Wraps destroy actions
- `lib/events/replay_change_wrapper.ex` - Handles replay-specific changes
- `lib/events/action_wrapper_helpers.ex` - Common wrapper utilities

## Event Processing
- `lib/event_log/replay.ex` - Event replay logic and action handling
- `lib/events/changes/store_changeset_params.ex` - Stores changeset data in events
- `lib/event_log/clear_records.ex` - Behavior for clearing records before replay

## Transformers & Verifiers
- `lib/events/transformers/add_actions.ex` - Adds wrapped actions to resources
- `lib/event_log/transformers/add_actions.ex` - Adds replay action to event log
- `lib/event_log/transformers/add_attributes.ex` - Adds event log attributes
- `lib/event_log/transformers/validate_belongs_to_actor.ex` - Validates actor config
- `lib/event_log/verifiers/verify_actor_modules.ex` - Verifies actor resources exist

## Security & Concurrency
- `lib/event_log/advisory_lock_key_generator.ex` - Advisory lock behavior
- `lib/event_log/advisory_lock_key_generator_default.ex` - Default lock implementation
- `lib/event_log/changes/encrypt.ex` - Encryption for event data
- `lib/event_log/calculations/decrypt.ex` - Decryption for event data

## Actor Management
- `lib/event_log/persist_actor_primary_key.ex` - Actor configuration entity

## Installation
- `lib/mix/tasks/ash_events.install.ex` - Mix task for project setup

## Test Support
- `test/support/events/` - Test event log resources
- `test/support/accounts/` - Test resources with events enabled
- `test/support/test_*.ex` - Test utilities and configuration

## Key File Patterns
- `*_wrapper.ex` - Action interception and event creation
- `transformers/*.ex` - Compile-time resource modification
- `verifiers/*.ex` - Compile-time validation
- `changes/*.ex` - Runtime changeset modifications
- `calculations/*.ex` - Runtime data processing