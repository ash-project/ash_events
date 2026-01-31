<!--
SPDX-FileCopyrightText: 2024 Torkild G. Kjevik

SPDX-License-Identifier: MIT
-->

# AshEvents - AI Assistant Guide

## Project Overview

**AshEvents** is an Ash Framework extension providing event capabilities for Ash resources, enabling complete audit trails and powerful event replay functionality.

**Key Features**: Event logging, event replay, actor attribution, changed attributes tracking, version management, encryption support

## Critical Development Rules

### Rule 1: Always Set Actor Attribution
| Wrong | Correct | Purpose |
|-------|---------|---------|
| `Ash.create!(changeset)` | `Ash.create!(changeset, actor: user)` | Actor tracking |
| `Ash.update!(changeset)` | `Ash.update!(changeset, actor: user)` | Audit trail |
| `Ash.destroy!(record)` | `Ash.destroy!(record, actor: user)` | Compliance |

**Why**: Events without actors lose audit information and may fail during replay.

### Rule 2: Use Test Environment
| Wrong | Correct | Purpose |
|-------|---------|---------|
| `mix ecto.reset` | `mix test.reset` | Reset database |
| Direct iex debugging | Write proper tests | Debug issues |

**Why**: Test resources only compile in `:test` environment.

## Essential Workflows

### Database Management
```bash
mix test.reset                    # Drop, create, migrate test database
mix test.create                   # Create test database
mix test.migrate                  # Run migrations
mix test.generate_migrations      # Generate migrations
```

### Testing
```bash
mix test                          # Run all tests
mix test --trace                  # Detailed output
mix check                         # All quality checks
```

### Quality Checks
```bash
mix format                        # Format code
mix credo --strict               # Linting
mix dialyzer                     # Type checking
```

## Configuration Examples

### Event Log Resource
```elixir
defmodule MyApp.Events.EventLog do
  use Ash.Resource, extensions: [AshEvents.EventLog]

  event_log do
    clear_records_for_replay MyApp.Events.ClearAllRecords
    primary_key_type Ash.Type.UUIDv7
    persist_actor_primary_key :user_id, MyApp.User
  end
end
```

### Resource with Events
```elixir
defmodule MyApp.User do
  use Ash.Resource, extensions: [AshEvents.Events]

  events do
    event_log MyApp.Events.EventLog
    current_action_versions create: 1, update: 1
    replay_non_input_attribute_changes [create: :force_change]
  end
end
```

## Codebase Navigation

### Key Files

| Purpose | Location |
|---------|----------|
| EventLog DSL | `lib/event_log/event_log.ex` |
| Events DSL | `lib/events/events.ex` |
| Replay logic | `lib/event_log/replay.ex` |
| Action wrappers | `lib/events/*_action_wrapper.ex` |
| Wrapper helpers | `lib/events/action_wrapper_helpers.ex` |
| Test resources | `test/support/accounts/` |
| Event log examples | `test/support/event_logs/` |

## Command Reference

| Command | Purpose |
|---------|---------|
| `mix test.reset` | Reset test database (preferred) |
| `mix test` | Run all tests |
| `mix test --trace` | Tests with detailed output |
| `mix format` | Format code |
| `mix credo --strict` | Linting |
| `mix dialyzer` | Type checking |
| `mix spark.cheat_sheets` | Regenerate DSL docs |

## Documentation Index

### Core Documentation

| File | Purpose |
|------|---------|
| [architecture-decisions.md](agent-docs/architecture-decisions.md) | Key decisions with reasoning |
| [development-workflows.md](agent-docs/development-workflows.md) | Development patterns |
| [testing-and-validation.md](agent-docs/testing-and-validation.md) | Test organization |
| [troubleshooting.md](agent-docs/troubleshooting.md) | Quick diagnosis |

### Feature Documentation

| File | Purpose |
|------|---------|
| [features/event-log.md](agent-docs/features/event-log.md) | EventLog extension |
| [features/events-extension.md](agent-docs/features/events-extension.md) | Events extension |
| [features/replay.md](agent-docs/features/replay.md) | Event replay |
| [features/changed-attributes.md](agent-docs/features/changed-attributes.md) | Changed attributes tracking |

### Task-to-Documentation Mapping

| Task Type | Read First |
|-----------|------------|
| Modify EventLog DSL | [features/event-log.md](agent-docs/features/event-log.md) |
| Modify Events DSL | [features/events-extension.md](agent-docs/features/events-extension.md) |
| Event Replay issues | [features/replay.md](agent-docs/features/replay.md) |
| Changed attributes | [features/changed-attributes.md](agent-docs/features/changed-attributes.md) |
| Debugging | [troubleshooting.md](agent-docs/troubleshooting.md) |
| Testing patterns | [testing-and-validation.md](agent-docs/testing-and-validation.md) |

## Key Architecture Concepts

### Event Creation Flow
```
Action Called → Action Wrapper → Event Created → Actor Attributed → Original Action
```

### Event Replay Flow
```
Clear Records → Fetch Events (chronological) → Replay Actions → Reconstruct State
```

### Replay Strategies
| Strategy | Behavior | Use Case |
|----------|----------|----------|
| `:force_change` | Apply exact values | Timestamps, computed fields |
| `:as_arguments` | Merge into input | Recompute during replay |

## Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| Events not created | Missing actor | Add `actor: user` to action |
| "clear_records must be specified" | Missing implementation | Implement `ClearRecordsForReplay` |
| State mismatch after replay | Wrong strategy | Use `:force_change` |
| Tests failing randomly | Stale database | Run `mix test.reset` |
| Actor not persisted | Type mismatch | Check `persist_actor_primary_key` config |

## Safety Checklist

- [ ] Actor attribution set on all actions
- [ ] `mix test.reset` before debugging
- [ ] `mix test` passes
- [ ] `mix format` applied
- [ ] Clear records covers all tracked resources
- [ ] Replay strategies configured appropriately
- [ ] Version management for schema evolution

## External Documentation

| Doc | Purpose | Note |
|-----|---------|------|
| [README.md](README.md) | User overview | End-user focused |
| [usage-rules.md](usage-rules.md) | Consumer patterns | For package users |
| [CHANGELOG.md](CHANGELOG.md) | Version history | User-facing changes |
| `documentation/dsls/` | DSL reference | AUTO-GENERATED |
