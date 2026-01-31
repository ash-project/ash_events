<!--
SPDX-FileCopyrightText: 2024 Torkild G. Kjevik

SPDX-License-Identifier: MIT
-->

# Testing and Validation

Comprehensive guide for test organization and validation procedures.

## Test Structure

```
test/
├── test_helper.exs              # Test configuration and setup
├── ash_events/                  # Feature-focused tests
│   ├── event_log/               # EventLog DSL tests
│   │   ├── verifiers/           # Verifier module tests
│   │   └── transformers/        # Transformer module tests
│   ├── events/                  # Events extension tests
│   │   ├── verifiers/           # Verifier module tests
│   │   └── changes/             # Change module tests
│   ├── errors/                  # Error scenario tests
│   ├── features/                # Specialized feature tests
│   ├── integration/             # End-to-end workflow tests
│   ├── mix/                     # Mix task tests
│   ├── event_creation_test.exs  # Core event creation
│   ├── replay_test.exs          # Event replay functionality
│   ├── actor_attribution_test.exs
│   ├── changed_attributes_test.exs
│   ├── encryption_test.exs
│   ├── state_machine_test.exs
│   ├── embedded_resources_test.exs
│   └── ...                      # Other feature tests
└── support/                     # Test infrastructure
    ├── accounts/                # Test resources (User, Org, etc.)
    ├── event_logs/              # Test event log configurations
    ├── test_helpers.ex          # Reusable test utilities
    ├── assertions.ex            # Custom assertions
    ├── shared_setup.ex          # Setup callbacks
    ├── repo_case.ex             # Base test case
    ├── conn_case.ex             # Phoenix connection case
    ├── TESTING.md               # Detailed test documentation
    └── vault.ex                 # Encryption vault for tests
```

## Testing Commands

```bash
# Database management
mix test.reset                   # Drop, create, migrate test database
mix test.create                  # Create test database
mix test.migrate                 # Run migrations

# Run tests
mix test                         # Run all tests (~412 tests)
mix test --trace                 # Run with detailed output
mix test test/ash_events/replay_test.exs  # Run specific test file
mix test test/ash_events/integration/     # Run directory

# Quality checks
mix format                       # Format code
mix credo --strict               # Linting
mix dialyzer                     # Type checking
mix check                        # Run all quality checks
```

## Test Categories

### Unit Tests (`event_log/`, `events/`)

Test individual modules in isolation:

| Directory | Purpose |
|-----------|---------|
| `event_log/verifiers/` | EventLog DSL validation rules |
| `event_log/transformers/` | EventLog DSL transformations |
| `events/verifiers/` | Events extension validation |
| `events/changes/` | Change module behavior |

### Error Tests (`errors/`)

Test error handling and edge cases:
- `event_creation_errors_test.exs` - Event creation failures
- `replay_errors_test.exs` - Replay error scenarios
- `encryption_errors_test.exs` - Encryption edge cases
- `clear_records_errors_test.exs` - Clear records errors
- `advisory_lock_errors_test.exs` - Lock edge cases

### Integration Tests (`integration/`)

Test complete workflows:
- `complete_lifecycle_test.exs` - Full CRUD with events
- `high_volume_test.exs` - Performance and concurrency
- `version_migration_test.exs` - Schema evolution

### Feature Tests

Test specialized functionality:
- `encryption_test.exs` - AshCloak integration
- `state_machine_test.exs` - AshStateMachine integration
- `embedded_resources_test.exs` - Embedded resource handling
- `features/custom_advisory_lock_generators_test.exs` - Lock customization

## Test Helper Modules

### `AshEvents.Test.Helpers`

Utility functions for common operations:

```elixir
import AshEvents.Test.Helpers

# Create test users
user = create_user()
user = create_user(email: "other@example.com")

# Create system actors
actor = system_actor("my_worker")

# Event queries
events = get_all_events()
events = events_for_record(user.id)
count = event_count()

# Unique values
email = unique_email("prefix")
```

### `AshEvents.Test.Assertions`

Domain-specific assertions:

```elixir
import AshEvents.Test.Assertions

# Event count assertions
assert_events_count(3)
assert_events_count_for_resource(MyApp.User, 2)

# Event content assertions
assert_event_created(resource: MyApp.User, action: :create)
assert_event_data_contains(event, %{"email" => "test@example.com"})

# Actor assertions
assert_actor_attributed(event, user_id: user.id)
assert_actor_attributed(event, system_actor: "test_runner")

# Replay assertions
assert_replay_successful()
assert_state_after_replay(User, user.id, %{given_name: "John"})
```

### `AshEvents.Test.SharedSetup`

Setup callbacks for ExUnit:

```elixir
import AshEvents.Test.SharedSetup

# Use as setup callback
setup :create_user_setup           # Creates basic user
setup :create_user_with_events     # User + captured events
setup :create_user_with_updates    # User with update history
setup :create_multiple_users       # Multiple test users
setup :clear_events                # Clean event log
```

## Test Patterns

### Using RepoCase (Recommended)

Always use `AshEvents.RepoCase` for database tests:

```elixir
defmodule AshEvents.MyFeatureTest do
  use AshEvents.RepoCase, async: false

  alias AshEvents.EventLogs.SystemActor

  test "my test" do
    actor = %SystemActor{name: "test_runner"}
    # ... test code
  end
end
```

### SystemActor for Authorization Bypass

Use `SystemActor` when you need to bypass authorization policies:

```elixir
alias AshEvents.EventLogs.SystemActor

# SystemActor has is_system_actor: true which bypasses policies
actor = %SystemActor{name: "test_runner"}

{:ok, user} =
  MyApp.User
  |> Ash.Changeset.for_create(:create, %{name: "Test"})
  |> Ash.create(actor: actor)
```

### Testing with Actor Attribution

Always provide an actor for actions:

```elixir
test "creates event with actor" do
  actor = %SystemActor{name: "test_runner"}

  {:ok, user} =
    MyApp.User
    |> Ash.Changeset.for_create(:create, %{name: "Test"})
    |> Ash.create(actor: actor)

  events = events_for_record(user.id)
  assert hd(events).system_actor == "test_runner"
end
```

### Replay Test Pattern

Test replay scenarios with clear → replay → verify pattern:

```elixir
test "replay restores state" do
  actor = %SystemActor{name: "test"}

  # Create data
  {:ok, user} = create_user(actor: actor)
  original_id = user.id

  # Clear records (not events)
  AshEvents.EventLogs.ClearRecords.clear_records!([])

  # Replay events
  :ok = AshEvents.EventLogs.replay_events!()

  # Verify state
  {:ok, restored} = Ash.get(MyApp.User, original_id, actor: actor)
  assert restored.name == user.name
end
```

### Testing Encrypted Events

Use `Ash.load!/2` for encrypted calculations:

```elixir
test "encrypted data decrypts correctly" do
  Accounts.create_org_cloaked!(%{name: "Secret"})

  [event] = Ash.read!(EventLogCloaked)

  # IMPORTANT: Must load encrypted calculation
  event = Ash.load!(event, [:data])

  assert event.data["name"] == "Secret"
end
```

### Testing Resources with Limited Authorization

Some test resources have limited authorization policies. Use `authorize?: false` when needed:

```elixir
test "reads resource with limited policies" do
  # OrgStateMachine only has policies for :create and :set_inactive
  restored_orgs = Ash.read!(Accounts.OrgStateMachine, authorize?: false)
  # ...
end
```

## Pre-Change Baseline Checks

**Run these before making changes to establish working baseline:**

```bash
mix test.reset                   # Clean database state
mix test                         # All tests passing
mix format --check-formatted     # Formatting correct
mix credo --strict               # No linting issues
```

**If any baseline check fails, STOP and fix before proceeding.**

## Change-Specific Validations

### Event Creation Changes
```bash
mix test test/ash_events/event_creation_test.exs
mix test test/ash_events/actor_attribution_test.exs
mix test test/ash_events/events/
```

### Replay Logic Changes
```bash
mix test test/ash_events/replay_test.exs
mix test test/ash_events/changed_attributes_test.exs
mix test test/ash_events/integration/
```

### DSL Changes
```bash
mix compile --force --warnings-as-errors
mix test test/ash_events/event_log/
mix test test/ash_events/events/
mix spark.cheat_sheets           # Regenerate DSL docs
```

### Encryption Changes
```bash
mix test test/ash_events/encryption_test.exs
mix test test/ash_events/errors/encryption_errors_test.exs
```

## Adding New Tests

### For New Features
1. Create test file in appropriate directory
2. Use `AshEvents.RepoCase` for database tests
3. Include both positive and negative test cases
4. Test edge cases and error conditions
5. Run full test suite to verify no regressions

### Test File Template

```elixir
# SPDX-FileCopyrightText: 2024 ash_events contributors
#
# SPDX-License-Identifier: MIT

defmodule AshEvents.MyFeatureTest do
  @moduledoc """
  Tests for [feature description].

  This module tests:
  - [bullet point 1]
  - [bullet point 2]
  """
  use AshEvents.RepoCase, async: false

  alias AshEvents.EventLogs.SystemActor

  describe "feature context" do
    test "expected behavior" do
      actor = %SystemActor{name: "test_runner"}
      # Test implementation
    end

    test "handles edge case" do
      # Edge case test
    end
  end
end
```

## Test Resources

Test resources are defined in `test/support/accounts/`:

| Resource | Event Log | Notes |
|----------|-----------|-------|
| `User` | `EventLog` | Main test resource with all features |
| `UserUuidV7` | `EventLogUuidV7` | Simple config (no replay_overrides) |
| `UserEmbedded` | `EventLog` | Embedded resources |
| `UserRole` | `EventLog` | Created as side effect of User |
| `Org` | `EventLog` | Organization resource |
| `OrgCloaked` | `EventLogCloaked` | Encrypted (no destroy action) |
| `OrgStateMachine` | `EventLogStateMachine` | State machine (limited policies) |
| `OrgDetails` | N/A | Multitenant resource |
| `Upload` | `EventLog` | State machine with conditional transitions |

## Event Logs

Test event logs are defined in `test/support/event_logs/`:

| Event Log | Features | Used By |
|-----------|----------|---------|
| `EventLog` | Full features, replay_overrides | User, UserRole, Org, Upload |
| `EventLogUuidV7` | Simple config, no overrides | UserUuidV7 |
| `EventLogCloaked` | Encrypted with Cloak vault | OrgCloaked |
| `EventLogStateMachine` | State machine support | OrgStateMachine |

**Tip**: Use `EventLogUuidV7` for simpler replay testing - it has no `replay_overrides` configuration that routes actions.

## Final Validation Checklist

Before committing changes:

- [ ] `mix test.reset` - Clean database state
- [ ] `mix test` - All tests pass
- [ ] `mix format` - Code formatted
- [ ] `mix credo --strict` - No linting issues
- [ ] `mix dialyzer` - No type errors (for significant changes)

## Critical Testing Rules

1. **Always use actor attribution** - Tests must pass actor to actions
2. **Use RepoCase** - Not raw `ExUnit.Case` for database tests
3. **Reset database between test runs** - Use `mix test.reset`
4. **Use SystemActor for bypassing auth** - Has `is_system_actor: true`
5. **Load encrypted fields** - Use `Ash.load!/2` for encrypted calculations
6. **Test replay functionality** - New features should work with replay

**See also**: [development-workflows.md](development-workflows.md), [troubleshooting.md](troubleshooting.md)
