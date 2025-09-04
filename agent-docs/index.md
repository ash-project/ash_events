# AshEvents Internal Development Documentation Index

## Quick Access Guide

This index helps agents quickly find relevant documentation for **developing AshEvents itself**, optimizing context window usage for internal development tasks.

⚠️ **Note**: This documentation is for working **ON** the AshEvents project. For using AshEvents as a dependency, see [usage-rules.md](../usage-rules.md).

## Core Files (Always Start Here)

| File | Purpose | When to Use |
|------|---------|-------------|
| [AGENTS.md](../AGENTS.md) | Main agent guide | Start here for project overview, critical rules, and workflows |
| [quick-reference.md](quick-reference.md) | Development commands and patterns | Need immediate help with AshEvents development tasks |
| [validation-safety.md](validation-safety.md) | Testing and safety procedures | Before making any changes to AshEvents internals |
| [changelog.md](changelog.md) | Internal development context | Understanding why current patterns exist and development decisions |

## Internal Development Tasks

### Core Extension Development
| Task | Primary Documentation | Key Files |
|------|----------------------|-----------|
| **Modify EventLog DSL** | [AGENTS.md](../AGENTS.md) + [lib/event_log/event_log.ex](../lib/event_log/event_log.ex) | [lib/event_log/transformers/](../lib/event_log/transformers/) |
| **Modify Events DSL** | [AGENTS.md](../AGENTS.md) + [lib/events/events.ex](../lib/events/events.ex) | [lib/events/transformers/](../lib/events/transformers/) |
| **Add DSL Options** | [documentation/dsls/](../documentation/dsls/) | [lib/event_log/](../lib/event_log/), [lib/events/](../lib/events/) |
| **Work with Transformers** | [lib/event_log/transformers/](../lib/event_log/transformers/) | [lib/events/transformers/](../lib/events/transformers/) |
| **Work with Verifiers** | [lib/event_log/verifiers/](../lib/event_log/verifiers/) | Test files for validation patterns |

### Action Wrapper Development
| Task | Primary Documentation | Key Files |
|------|----------------------|-----------|
| **Modify Action Wrappers** | [lib/events/action_wrapper_helpers.ex](../lib/events/action_wrapper_helpers.ex) | [lib/events/*_action_wrapper.ex](../lib/events/) |
| **Add New Action Types** | [lib/events/transformers/add_actions.ex](../lib/events/transformers/add_actions.ex) | [test/ash_events/](../test/ash_events/) for patterns |
| **Debug Action Creation** | [validation-safety.md](validation-safety.md) | [test/ash_events/event_creation_test.exs](../test/ash_events/event_creation_test.exs) |

### Event Replay Development
| Task | Primary Documentation | Key Files |
|------|----------------------|-----------|
| **Modify Replay Logic** | [lib/event_log/replay.ex](../lib/event_log/replay.ex) | [test/ash_events/replay_test.exs](../test/ash_events/replay_test.exs) |
| **Work with Clear Records** | [lib/event_log/clear_records.ex](../lib/event_log/clear_records.ex) | [test/support/events/clear_records.ex](../test/support/events/clear_records.ex) |
| **Debug Replay Issues** | [validation-safety.md](validation-safety.md) | [test/ash_events/replay_test.exs](../test/ash_events/replay_test.exs) |

### Testing AshEvents Features
| Task | Primary Documentation | Key Files |
|------|----------------------|-----------|
| **Add Feature Tests** | [validation-safety.md](validation-safety.md) | [test/ash_events/](../test/ash_events/) |
| **Set up Test Resources** | [test/support/](../test/support/) patterns | [test/support/events/](../test/support/events/), [test/support/accounts/](../test/support/accounts/) |
| **Test Specific Scenarios** | Existing test files for patterns | [test/ash_events/encryption_test.exs](../test/ash_events/encryption_test.exs), [test/ash_events/changed_attributes_test.exs](../test/ash_events/changed_attributes_test.exs), [test/ash_events/state_machine_test.exs](../test/ash_events/state_machine_test.exs) |
| **Debug Test Failures** | [quick-reference.md](quick-reference.md) | [validation-safety.md](validation-safety.md) |

### Build and Documentation
| Task | Primary Documentation | Key Files |
|------|----------------------|-----------|
| **Generate Documentation** | [mix.exs](../mix.exs) docs configuration | [documentation/dsls/](../documentation/dsls/) |
| **Work with Mix Tasks** | [lib/mix/tasks/](../lib/mix/tasks/) | [mix.exs](../mix.exs) aliases |
| **Update DSL Docs** | Generated from code | [lib/event_log/event_log.ex](../lib/event_log/event_log.ex), [lib/events/events.ex](../lib/events/events.ex) |

## File Size Reference (Context Window Planning)

### Small Files (< 300 lines) - Efficient for Agents
- [quick-reference.md](quick-reference.md) (~200 lines)
- [validation-safety.md](validation-safety.md) (~250 lines)  
- [changelog.md](changelog.md) (~300 lines)
- [lib/events/action_wrapper_helpers.ex](../lib/events/action_wrapper_helpers.ex) (~150 lines)
- Individual test files in [test/ash_events/](../test/ash_events/) (~100-200 lines each)

### Medium Files (300-600 lines) - Manageable
- [AGENTS.md](../AGENTS.md) (~350 lines)
- [lib/event_log/event_log.ex](../lib/event_log/event_log.ex) (~400 lines)
- [lib/events/events.ex](../lib/events/events.ex) (~300 lines)
- [lib/event_log/replay.ex](../lib/event_log/replay.ex) (~500 lines)

### Large Files (> 600 lines) - Use Sparingly
⚠️ **Context Window Warning**: These files consume significant context space
- [usage-rules.md](../usage-rules.md) (~1000 lines) - **Consumer documentation, not internal**
- [mix.exs](../mix.exs) (~150 lines) - **Small but comprehensive**

## Internal Development Patterns

### For Extension Development (DSL modifications)
1. [lib/event_log/event_log.ex](../lib/event_log/event_log.ex) or [lib/events/events.ex](../lib/events/events.ex) - Core DSL definitions
2. [lib/event_log/transformers/](../lib/event_log/transformers/) or [lib/events/transformers/](../lib/events/transformers/) - Implementation logic
3. [test/ash_events/](../test/ash_events/) - Test patterns for new features

### For Feature Implementation
1. [AGENTS.md](../AGENTS.md) - Critical rules and development patterns
2. Relevant core files in [lib/](../lib/)
3. [validation-safety.md](validation-safety.md) - Testing procedures
4. [test/support/](../test/support/) - Test resource patterns

### For Debugging AshEvents Issues  
1. [quick-reference.md](quick-reference.md) - Emergency commands
2. [validation-safety.md](validation-safety.md) - Systematic debugging
3. Relevant test files for reproduction

### For Understanding Internal Context
1. [changelog.md](changelog.md) - Why current patterns exist
2. [AGENTS.md](../AGENTS.md) - Current development approach
3. Existing code patterns in [lib/](../lib/)

## Internal Development Workflow Examples

### Example: Adding New DSL Option to EventLog

**Required Reading Order**:
1. [AGENTS.md](../AGENTS.md) - Critical development rules
2. [lib/event_log/event_log.ex](../lib/event_log/event_log.ex) - Current DSL structure  
3. [lib/event_log/transformers/](../lib/event_log/transformers/) - Implementation patterns

**Implementation Steps**:
1. Add DSL option definition in `event_log.ex`
2. Implement logic in appropriate transformer
3. Add tests in [test/ash_events/](../test/ash_events/)
4. Update generated documentation

**Validation**:
- [validation-safety.md](validation-safety.md) - Testing procedures
- `mix test --trace` to verify new functionality
- `mix docs` to verify documentation generation

### Example: Modifying Action Wrapper Behavior

**Required Reading Order**:
1. [AGENTS.md](../AGENTS.md) - Critical rules for event creation
2. [lib/events/action_wrapper_helpers.ex](../lib/events/action_wrapper_helpers.ex) - Common patterns
3. Specific wrapper file ([lib/events/create_action_wrapper.ex](../lib/events/create_action_wrapper.ex), etc.)

**Implementation Steps**:
1. Modify wrapper logic in appropriate file
2. Update helper functions if needed
3. Add/update tests for changed behavior
4. Verify all existing tests still pass

**Validation**:
- `mix test test/ash_events/event_creation_test.exs` - Event creation
- `mix test test/ash_events/actor_attribution_test.exs` - Actor tracking
- Full test suite to ensure no regressions

### Example: Adding New Test Scenario

**Required Reading Order**:
1. [validation-safety.md](validation-safety.md) - Testing patterns
2. Similar test files in [test/ash_events/](../test/ash_events/) for patterns
3. [test/support/](../test/support/) - Test resource setup patterns

**Implementation Steps**:
1. Create test resources in [test/support/](../test/support/) if needed
2. Add test file in [test/ash_events/](../test/ash_events/)
3. Follow existing patterns for test setup and assertions

**Validation**:
- `mix test [new_test_file]` - Verify new tests pass
- `mix test --trace` - Full test suite verification

## External Resources for Internal Development

### Ash Framework Development
- [Ash Framework Source](https://github.com/ash-project/ash) - Understanding Ash internals
- [Ash Extension Development](https://hexdocs.pm/ash) - Extension patterns
- [Spark DSL Documentation](https://hexdocs.pm/spark) - DSL building patterns

### Elixir Development
- [Elixir Documentation](https://hexdocs.pm/elixir) - Language reference
- [ExUnit Testing](https://hexdocs.pm/ex_unit) - Testing framework

---

**Last Updated**: 2025-01-25  
**Focus**: Internal AshEvents development (not consumer usage)  
**Documentation Structure**: Following Scaffolding Framework v1.0