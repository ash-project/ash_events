<!--
SPDX-FileCopyrightText: 2024 Torkild G. Kjevik

SPDX-License-Identifier: MIT
-->

# Development Workflows

Essential development workflows and patterns for AshEvents development.

## Test-Driven Development

### Standard TDD Workflow
1. Create test showing desired behavior
2. Run test to see failure
3. Implement minimum code to make test pass
4. Refactor if needed
5. Run full test suite to verify no regressions

### Feature Development Pattern
1. **Plan the feature** - Understand scope and affected files
2. **Write test first** - Create failing test demonstrating expected behavior
3. **Implement minimally** - Make test pass with minimal code
4. **Refactor** - Clean up while keeping tests green
5. **Run full suite** - Ensure no regressions

## Interactive Debugging with IEx

**Use IEx for runtime exploration and debugging:**

```elixir
# Start IEx in test environment
iex -S mix

# Explore module exports
MyApp.EventLog.__ash_extension_config__()

# Test event creation manually
user = %MyApp.User{id: "123", email: "test@example.com"}
changeset = Ash.Changeset.for_create(MyApp.Post, :create, %{title: "Test"})
Ash.create!(changeset, actor: user)

# Check event log
Ash.read!(MyApp.EventLog)

# Test clear records
MyApp.ClearAllRecords.clear_records!([])

# Check event ordering
MyApp.EventLog
|> Ash.Query.sort(:inserted_at)
|> Ash.read!()
```

## Environment Specification

**Always use test environment for AshEvents commands:**

```bash
# ✅ CORRECT
mix test.reset                    # Reset test database
mix test                          # Run tests
mix test --trace                  # Detailed test output

# ❌ WRONG
mix ecto.reset                    # Wrong command for AshEvents
iex -S mix                        # Only for debugging, not for running commands
```

**Critical**: Test resources only compile in `:test` environment.

## Development Patterns

### DSL Development
When modifying EventLog or Events DSL:
1. Read existing DSL in `lib/event_log/event_log.ex` or `lib/events/events.ex`
2. Understand transformer chain in `lib/*/transformers/`
3. Check verifier validations in `lib/*/verifiers/`
4. Write tests first in `test/ash_events/`
5. Implement changes
6. Run `mix spark.cheat_sheets` if DSL structure changed

### Action Wrapper Changes
When modifying event creation behavior:
1. Read `lib/events/action_wrapper_helpers.ex` first
2. Understand flow in specific wrappers (`create_action_wrapper.ex`, etc.)
3. Write test demonstrating expected behavior
4. Implement changes
5. Test all action types (create, update, destroy)

### Replay Logic Changes
When modifying replay behavior:
1. Read `lib/event_log/replay.ex` thoroughly
2. Understand replay strategies (`:force_change`, `:as_arguments`)
3. Write replay test in `test/ash_events/replay_test.exs`
4. Test with various event types
5. Verify state reconstruction

## Critical Anti-Patterns

- **Don't** use `mix ecto.reset` - always use `mix test.reset`
- **Don't** skip running tests after changes
- **Don't** modify DSL without updating transformers
- **Don't** forget actor attribution in action calls
- **Don't** implement features without reading existing patterns first
- **Don't** ignore failing tests in unrelated areas
- **Don't** manually edit files in `documentation/dsls/` - they are auto-generated

## Extension Point Patterns

### Adding New DSL Options
1. Add schema option in extension file (`event_log.ex` or `events.ex`)
2. Create transformer if logic needed during compilation
3. Create verifier if validation needed
4. Add Info function if introspection needed
5. Write comprehensive tests
6. Run `mix spark.cheat_sheets` to update generated docs

### Adding New Action Wrappers
1. Study existing wrappers in `lib/events/`
2. Use `action_wrapper_helpers.ex` for common functionality
3. Handle parameter filtering
4. Ensure actor attribution flows through
5. Test with various configurations

### Adding Replay Features
1. Modify `lib/event_log/replay.ex`
2. Consider both `:force_change` and `:as_arguments` strategies
3. Handle encoding/decoding if new data types involved
4. Test with existing event types
5. Test with new feature-specific scenarios

## Code Organization Principles

### Separation of Concerns
- **DSL definitions**: Main extension files
- **Implementation logic**: Transformers
- **Validation**: Verifiers
- **Runtime behavior**: Action modules
- **Introspection**: Info modules

### Naming Conventions
- Transformers: `Add*` or `Wrap*` prefix
- Verifiers: `Verify*` prefix
- Info functions: `event_log_*` or `events_*` prefix

### File Location Guidelines
```
lib/
├── event_log/
│   ├── event_log.ex         # DSL definition
│   ├── transformers/        # Compilation logic
│   ├── verifiers/           # Validation logic
│   └── replay.ex            # Replay functionality
├── events/
│   ├── events.ex            # DSL definition
│   ├── transformers/        # Compilation logic
│   ├── verifiers/           # Validation logic
│   ├── *_action_wrapper.ex  # Action wrappers
│   └── action_wrapper_helpers.ex
└── mix/tasks/               # Mix tasks
```

## Key Success Factors

1. Always use test environment (`mix test.reset`)
2. Read existing patterns before implementing
3. Write tests before code
4. Use IEx for interactive debugging
5. Run full test suite after changes
6. Update architecture decisions for significant changes

**See also**: [testing-and-validation.md](testing-and-validation.md), [troubleshooting.md](troubleshooting.md)
