# AshEvents - AI Assistant Guide

## Project Overview

**AshEvents** is an extension for the Ash Framework that provides event capabilities for Ash resources, enabling complete audit trails and powerful event replay functionality.

### Purpose
- **Event Logging**: Automatically records create, update, and destroy actions as events
- **Event Replay**: Rebuilds resource state by replaying events chronologically
- **Actor Attribution**: Stores who performed each action (users, system processes, etc)
- **Version Management**: Handles schema evolution through replay overrides
- **Audit Trails**: Provides complete audit history with metadata tracking

### Tech Stack
- **Language**: Elixir ~> 1.15
- **Framework**: Ash Framework extension
- **Database**: PostgreSQL (via AshPostgres)
- **Build Tools**: Mix, ExDoc, Credo, Dialyzer

## 🚨 CRITICAL DEVELOPMENT RULES (MANDATORY)

### **RULE 1: ALWAYS SET ACTOR ATTRIBUTION**

**CRITICAL RULE**: You MUST set actor attribution for all actions that create events. Never perform actions without proper actor attribution.

**Command Reference:**

| ❌ WRONG | ✅ CORRECT | Purpose |
|----------|------------|---------|
| `Ash.create!(changeset)` | `Ash.create!(changeset, actor: current_user)` | Proper actor attribution |
| `Ash.update!(changeset)` | `Ash.update!(changeset, actor: current_user)` | Actor tracking for updates |
| `Ash.destroy!(record)` | `Ash.destroy!(record, actor: current_user)` | Actor tracking for deletions |

**WHY THIS MATTERS:**
- Events without actors lose critical audit trail information
- Event replay may fail without proper actor context
- Compliance and security require knowing who performed actions

### **RULE 2: DOCUMENTATION-FIRST WORKFLOW**

**CRITICAL RULE**: You MUST read relevant documentation BEFORE starting any non-trivial task. Skipping documentation leads to incorrect implementations, breaking changes, and wasted time.

### Mandatory TodoWrite Documentation Steps

For ANY complex task (3+ steps or affecting core functionality), you MUST:

1. **Create a TodoWrite list** where the FIRST items are documentation reading
2. **Mark documentation todos as `in_progress`** before reading
3. **Mark documentation todos as `completed`** after reading
4. **Only then** proceed with implementation todos
5. **Update changelog** with significant changes and their context

### Task-to-Documentation Mapping (REQUIRED READING)

**PRIMARY RESOURCE**: Always start with [agent-docs/index.md](agent-docs/index.md) for comprehensive documentation guidance.

The Agent Index provides task-specific documentation mapping, context window optimization, and file size references to help you efficiently find the right documentation for your needs.

### Example Mandatory Workflow

```
User: "Add event tracking to a new User resource"

CORRECT Approach:
1. Use TodoWrite to create todos:
   - Read agent-docs/index.md to find relevant documentation (in_progress → completed)
   - Read usage-rules.md sections on Events extension (in_progress → completed)
   - Read test examples in test/support/accounts/user.ex (in_progress → completed)
   - Create User resource with AshEvents.Events extension (pending → in_progress)
   - Configure event_log reference (pending)
   - Add actor attribution to actions (pending)
   - Test event creation (pending)

INCORRECT Approach:
- Jumping straight to editing User resource
- Adding AshEvents.Events extension without understanding configuration
- Forgetting to configure event_log reference
- Missing actor attribution setup
```

### Consequences of Skipping Documentation

**What happens when you don't read docs first:**
- ❌ Implement event tracking without proper configuration (breaking event creation)
- ❌ Forget to implement clear_records_for_replay (breaking event replay)
- ❌ Miss actor attribution (losing audit trail)
- ❌ Create events without proper version management (breaking schema evolution)
- ❌ Implement side effects incorrectly (causing duplicate effects during replay)
- ❌ Use wrong primary key types (causing performance issues)

**What happens when you DO read docs first:**
- ✅ Implement event tracking with proper configuration
- ✅ Understand event replay requirements and limitations
- ✅ Set up proper actor attribution for audit trails
- ✅ Configure version management for schema evolution
- ✅ Handle side effects correctly to prevent replay issues
- ✅ Use optimal configurations for performance

**Enforcement**: You MUST use TodoWrite for documentation reading. This is not optional.

### Quick Reference: When to Read What

**For any task** → Start with [agent-docs/index.md](agent-docs/index.md) to find the most relevant documentation

The Agent Index provides task-specific guidance, context window optimization, and direct links to the appropriate documentation based on your specific needs.

## Codebase Navigation

### Critical Files

**Core Event System (`lib/`):**
- `lib/event_log/event_log.ex` - Core event log resource functionality
- `lib/events/events.ex` - Events extension for resources
- `lib/events/create_action_wrapper.ex` - Create action event wrapper
- `lib/events/update_action_wrapper.ex` - Update action event wrapper
- `lib/events/destroy_action_wrapper.ex` - Destroy action event wrapper
- `lib/event_log/replay.ex` - Event replay functionality

**Test Resources (`test/support/`):**
- `test/support/events/event_log.ex` - Example event log resource
- `test/support/events/clear_records.ex` - Clear records implementation
- `test/support/accounts/user.ex` - Example resource with events
- `test/support/accounts/org.ex` - Example organization resource
- `test/support/test_repo.ex` - Test database configuration

**Generated Documentation (`doc/`):**
- `doc/` - Generated ExDoc documentation
- `documentation/dsls/` - DSL documentation files

## Essential Workflows

### Core Development Commands

**🚨 IMPORTANT: Always use `mix test.reset` to reset database state, NOT `mix ecto.reset`**

```bash
# Database Management - AshEvents specific
mix test.reset                           # Drop, create, migrate test database
mix test.create                          # Create test database
mix test.migrate                         # Run migrations
mix test.generate_migrations             # Generate migrations

# Testing commands
mix test                                 # Run all tests
mix test --trace                         # Run tests with detailed output
mix test test/ash_events_test.exs        # Run specific test file

# Quality checks
mix format                               # Format code
mix credo --strict                       # Linting with strict rules
mix dialyzer                             # Type checking
mix docs                                 # Generate documentation
```

### Event Log Resource Setup

1. **Create Event Log Resource**:
   ```elixir
   defmodule MyApp.Events.Event do
     use Ash.Resource,
       extensions: [AshEvents.EventLog]

     event_log do
       clear_records_for_replay MyApp.Events.ClearAllRecords
       primary_key_type Ash.Type.UUIDv7
       persist_actor_primary_key :user_id, MyApp.User
     end
   end
   ```

2. **Create Clear Records Module**: 
   ```elixir
   defmodule MyApp.Events.ClearAllRecords do
     use AshEvents.ClearRecordsForReplay

     @impl true
     def clear_records!(opts) do
       # Clear all tracked resources
       :ok
     end
   end
   ```

3. **Test Event Log**: `mix test test/support/events/`

### Add Event Tracking to Resource

1. **Add Events Extension**:
   ```elixir
   defmodule MyApp.User do
     use Ash.Resource,
       extensions: [AshEvents.Events]

     events do
       event_log MyApp.Events.Event
       current_action_versions create: 1, update: 1
     end
   end
   ```

2. **Set Actor Attribution**: `Ash.create!(changeset, actor: current_user)`
3. **Test Event Creation**: Verify events are created with proper attribution

### Event Replay Workflow

1. **Implement Clear Records**: Ensure all tracked resources are cleared
2. **Configure Version Management**: Set up replay overrides if needed
3. **Test Replay**: `mix test --grep "replay"`
4. **Validate State**: Verify replayed state matches expected state

### Testing Workflow

1. **Reset Database**: `mix test.reset`
2. **Run Tests**: `mix test --trace`
3. **Check Quality**: `mix credo --strict`
4. **Type Check**: `mix dialyzer`

### Version Management Workflow (Critical for Schema Evolution)

**CRITICAL**: When changing action schemas, you MUST configure version management to handle existing events.

1. **Update Action Versions**:
   ```elixir
   events do
     event_log MyApp.Events.Event
     current_action_versions create: 2, update: 1  # Increment version
   end
   ```

2. **Configure Replay Overrides**:
   ```elixir
   # In Event Log Resource
   replay_overrides do
     replay_override MyApp.User, :create do
       versions [1]
       route_to MyApp.User, :old_create_v1
     end
   end
   ```

3. **Create Legacy Actions**: Implement old versions for replay
4. **Test Version Routing**: Verify events route to correct actions

**Key Event Files**:
- `lib/event_log/event_log.ex` - Event log resource extension
- `lib/events/events.ex` - Events extension for resources
- `lib/event_log/replay.ex` - Event replay functionality

**Common Event Issues**:
- Missing actor attribution in actions
- Incomplete clear_records implementation
- Incorrect version management configuration

**Debugging Pattern**:
```bash
# 1. Check event creation
mix test -t event_creation

# 2. Check event replay
mix test -t event_replay

# 3. Check actor attribution
mix test -t actor_attribution
```

## Documentation Reference Map

### User Documentation
- **[README.md](README.md)** - Project overview and installation
- **[CHANGELOG.md](CHANGELOG.md)** - Version history and changes
- **[usage-rules.md](usage-rules.md)** - Comprehensive usage patterns and rules

### Developer Documentation
- **[documentation/dsls/DSL-AshEvents.EventLog.md](documentation/dsls/DSL-AshEvents.EventLog.md)** - EventLog DSL reference
- **[documentation/dsls/DSL-AshEvents.Events.md](documentation/dsls/DSL-AshEvents.Events.md)** - Events DSL reference

### API Reference
- **[doc/](doc/)** - Generated ExDoc API documentation

### Agent-Specific Documentation (see agent-docs/ folder)
- **[agent-docs/index.md](agent-docs/index.md)** - **START HERE** - Comprehensive documentation index with task-specific guidance, context window optimization, and direct links to relevant files
- **[agent-docs/quick-reference.md](agent-docs/quick-reference.md)** - **EMERGENCY REFERENCE** - Quick commands, patterns, and critical reminders for immediate help
- **[agent-docs/validation-safety.md](agent-docs/validation-safety.md)** - **BEFORE ANY CHANGES** - Testing and validation procedures to ensure safe development
- **[agent-docs/changelog.md](agent-docs/changelog.md)** - **CONTEXT AND EVOLUTION** - Understanding why current patterns exist and the reasoning behind architectural decisions
- **[agent-docs/documentation-update-guide.md](agent-docs/documentation-update-guide.md)** - **MANDATORY FOR DOCS UPDATES** - Complete guide for updating agent documentation with established patterns and workflows

## Quick Reference for AI Assistants

### 🚨 CRITICAL REMINDER: ACTOR ATTRIBUTION IS MANDATORY

**ALWAYS use actor attribution - NEVER perform actions without setting actor**
**ALWAYS read usage-rules.md before implementing - NEVER skip documentation**

### Complete Command Reference

**Database Management:**
```bash
mix test.reset                           # Reset test database (preferred)
mix test.create                          # Create test database
mix test.migrate                         # Run migrations
mix test.generate_migrations             # Generate migrations
```

**Testing:**
```bash
mix test                                 # Run all tests
mix test --trace                         # Run tests with detailed output
mix test test/ash_events_test.exs        # Run specific test file
```

**🚨 IMPORTANT: Always use `mix test.reset` for database management in AshEvents**

**Quality Checks:**
```bash
mix format                               # Format code
mix credo --strict                       # Linting with strict rules
mix dialyzer                             # Type checking
mix docs                                 # Generate documentation
```

### Common Tasks

| Task | Steps |
|------|-------|
| **Add Event Tracking** | 1. Add `AshEvents.Events` extension<br>2. Configure `event_log` reference<br>3. Set actor attribution |
| **Create Event Log** | 1. Add `AshEvents.EventLog` extension<br>2. Implement `clear_records_for_replay`<br>3. Configure actor attribution |
| **Event Replay** | 1. Ensure clear records works<br>2. Call replay action<br>3. Verify state restoration |
| **Version Management** | 1. Update action versions<br>2. Configure replay overrides<br>3. Create legacy actions |

### Key Abstractions

- **Event Log Resource**: Central resource using `AshEvents.EventLog` extension
- **Events Extension**: Added to resources needing event tracking via `AshEvents.Events`
- **Actor Attribution**: Critical for audit trails - always set actor when performing actions
- **Event Replay**: Rebuilds state by replaying events chronologically  
- **Version Management**: Handles schema evolution through replay overrides
- **Clear Records**: Required implementation for event replay functionality

### Critical Safety Checks

- Actor attribution is set on all actions that create events
- Clear records implementation covers all event-tracked resources
- Version management is configured for schema evolution
- Side effects are implemented as separate tracked actions
- Event replay works correctly with test data

## Context and Evolution

For understanding the current state of the project and the reasoning behind architectural decisions, see [agent-docs/changelog.md](agent-docs/changelog.md). This changelog provides context for why certain patterns exist and tracks the evolution of implementation approaches.