# Core Concepts

## Event Sourcing vs Audit Logging
AshEvents supports both patterns:

**Event Sourcing**: Complete application state rebuilt from events via replay
**Audit Logging**: Events used for tracking/compliance, state maintained separately

## Event Structure
Events capture:
- **Resource & Action**: What was done (`MyApp.User`, `:create`)
- **Record ID**: Which record was affected 
- **Data**: Action inputs (attributes, arguments)
- **Actor**: Who performed the action (user, system, etc.)
- **Metadata**: Custom contextual information
- **Version**: Schema version for handling evolution
- **Timestamp**: When the event occurred

## Action Wrapping
AshEvents intercepts resource actions using transformation:
1. Original action → Wrapped action
2. Wrapped action creates event → Calls original action
3. Both event creation and original action succeed or fail together

## Lifecycle Hook Behavior
**Normal Execution**: All hooks run (before_action, after_action, etc.)
**During Replay**: All hooks skipped to prevent side effects

## Version Management
- Actions have versions (default: 1)
- Events store the version when created
- `replay_overrides` route old versions to compatible actions
- Enables schema evolution without breaking replay

## Actor Attribution
Multiple actor types supported:
```elixir
persist_actor_primary_key :user_id, MyApp.User
persist_actor_primary_key :system_actor, MyApp.SystemActor
```
Actor's primary key stored in event when action has matching actor type.

## Advisory Locking
PostgreSQL advisory locks prevent race conditions:
- Acquired during event creation
- Released at transaction end
- Key generation strategies handle multitenancy
- Only affects PostgreSQL databases

## Replay Process
1. Clear existing records (`clear_records_for_replay`)
2. Load events chronologically 
3. Apply each event, routing via `replay_overrides` if configured
4. Skip all lifecycle hooks
5. Rebuild complete application state