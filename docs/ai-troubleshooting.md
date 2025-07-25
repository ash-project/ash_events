# AshEvents AI Assistant Troubleshooting Guide

## Overview

This guide provides systematic troubleshooting approaches for common AshEvents issues, optimized for AI assistant diagnosis and resolution.

## Environment Issues

### Mix Dependencies Resolution

**Symptoms**:
- Compilation errors about missing AshEvents modules
- Version conflicts between Ash and AshEvents
- Missing dependencies during compilation

**Diagnosis**:
```bash
mix deps.get
mix deps.compile
mix compile
```

**Resolution**:
1. Clean and reinstall dependencies:
   ```bash
   mix deps.clean --all
   mix deps.get
   mix deps.compile
   ```

2. Check mix.exs for correct versions:
   ```elixir
   {:ash, "~> 3.5"},
   {:ash_events, "~> 0.4.2"}
   ```

3. Verify compatibility matrix in README.md

**Validation**:
```bash
mix compile --warnings-as-errors
```

### Database Connection Issues

**Symptoms**:
- Database connection errors during tests
- Migration failures
- Repository not found errors

**Diagnosis**:
```bash
mix test.create
mix test.migrate
```

**Resolution**:
1. Reset database completely:
   ```bash
   mix test.reset
   ```

2. Check database configuration in `config/test.exs`:
   ```elixir
   config :ash_events, AshEvents.TestRepo,
     username: "postgres",
     password: "postgres",
     hostname: "localhost",
     database: "ash_events_test"
   ```

3. Verify PostgreSQL is running and accessible

**Validation**:
```bash
mix test.create && mix test.migrate
```

### Compilation Issues

**Symptoms**:
- DSL compilation errors
- Extension not found errors
- Behaviour implementation errors

**Diagnosis**:
```bash
mix compile --force
```

**Resolution**:
1. Check extension configuration:
   ```elixir
   use Ash.Resource,
     extensions: [AshEvents.EventLog]  # or [AshEvents.Events]
   ```

2. Verify behaviour implementation:
   ```elixir
   defmodule MyApp.Events.ClearAllRecords do
     use AshEvents.ClearRecordsForReplay
     
     @impl true
     def clear_records!(opts) do
       :ok
     end
   end
   ```

3. Clean and recompile:
   ```bash
   mix clean
   mix compile
   ```

**Validation**:
```bash
mix compile --warnings-as-errors
```

## Event Tracking Issues

### Events Not Being Created

**Error Pattern**:
```
No events found after performing action
```

**Common Causes**:
- Missing Events extension on resource
- Event log not configured
- Actor not set during action

**Resolution Steps**:
1. Check resource has Events extension:
   ```elixir
   defmodule MyApp.User do
     use Ash.Resource,
       extensions: [AshEvents.Events]  # Must be present
   end
   ```

2. Verify event log configuration:
   ```elixir
   events do
     event_log MyApp.Events.Event  # Must reference event log resource
   end
   ```

3. Ensure actor is set:
   ```elixir
   User
   |> Ash.Changeset.for_create(:create, %{name: "Test"})
   |> Ash.create!(actor: current_user)  # Actor must be set
   ```

**Prevention**:
- Always use Events extension for tracked resources
- Always configure event_log reference
- Always set actor in actions

### Event Log Configuration Errors

**Error Pattern**:
```
Event log resource not found or misconfigured
```

**Common Causes**:
- Event log resource missing EventLog extension
- Clear records module not implemented
- Actor configuration incorrect

**Resolution Steps**:
1. Check event log resource configuration:
   ```elixir
   defmodule MyApp.Events.Event do
     use Ash.Resource,
       extensions: [AshEvents.EventLog]  # Must be present
   
     event_log do
       clear_records_for_replay MyApp.Events.ClearAllRecords
       persist_actor_primary_key :user_id, MyApp.User
     end
   end
   ```

2. Implement clear records module:
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

3. Test event log functionality:
   ```bash
   mix test test/support/events/
   ```

**Prevention**:
- Always implement clear_records_for_replay
- Always configure actor attribution
- Test event log resource independently

### Actor Attribution Problems

**Error Pattern**:
```
Events created without actor information
```

**Common Causes**:
- Actor not set during actions
- Actor configuration missing in event log
- Wrong actor type used

**Resolution Steps**:
1. Configure actor types in event log:
   ```elixir
   event_log do
     persist_actor_primary_key :user_id, MyApp.User
     persist_actor_primary_key :system_actor, MyApp.SystemActor, attribute_type: :string
   end
   ```

2. Always set actor in actions:
   ```elixir
   User
   |> Ash.Changeset.for_create(:create, %{name: "Test"})
   |> Ash.create!(actor: current_user)
   ```

3. Test actor attribution:
   ```elixir
   test "events contain actor attribution" do
     actor = %{id: 1, name: "Test"}
     
     user = User
     |> Ash.Changeset.for_create(:create, %{name: "Test"})
     |> Ash.create!(actor: actor)
     
     events = MyApp.Events.Event |> Ash.read!()
     event = hd(events)
     assert event.user_id == actor.id
   end
   ```

**Prevention**:
- Configure all actor types in event log
- Always set actor in actions
- Test actor attribution in all scenarios

## Event Replay Issues

### Replay Failures

**Error Pattern**:
```
Event replay failed with errors
```

**Common Causes**:
- Incomplete clear_records implementation
- Missing resources during replay
- Version management issues

**Resolution Steps**:
1. Check clear_records implementation:
   ```elixir
   defmodule MyApp.Events.ClearAllRecords do
     use AshEvents.ClearRecordsForReplay
     
     @impl true
     def clear_records!(opts) do
       # Must clear ALL resources with event tracking
       MyApp.UserRole |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)
       MyApp.User |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)
       MyApp.Org |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)
       :ok
     end
   end
   ```

2. Test clear_records functionality:
   ```elixir
   test "clear_records clears all tracked resources" do
     # Create test data
     user = create_user()
     org = create_org()
     
     # Clear records
     MyApp.Events.ClearAllRecords.clear_records!([])
     
     # Verify everything is cleared
     assert User |> Ash.read!() == []
     assert Org |> Ash.read!() == []
   end
   ```

3. Test replay functionality:
   ```bash
   mix test --grep "replay"
   ```

**Prevention**:
- Include all event-tracked resources in clear_records
- Clear resources in correct dependency order
- Test replay functionality regularly

### Version Management Issues

**Error Pattern**:
```
Events not routing to correct actions during replay
```

**Common Causes**:
- Action versions not configured
- Replay overrides missing
- Legacy actions not implemented

**Resolution Steps**:
1. Configure action versions:
   ```elixir
   events do
     event_log MyApp.Events.Event
     current_action_versions create: 2, update: 1
   end
   ```

2. Set up replay overrides:
   ```elixir
   replay_overrides do
     replay_override MyApp.User, :create do
       versions [1]
       route_to MyApp.User, :old_create_v1
     end
   end
   ```

3. Implement legacy actions:
   ```elixir
   actions do
     create :old_create_v1 do
       # Handle version 1 events
     end
   end
   
   events do
     ignore_actions [:old_create_v1]
   end
   ```

**Prevention**:
- Plan version management from the start
- Always implement legacy actions for old versions
- Test version routing during replay

### Data Consistency Issues

**Error Pattern**:
```
Replayed state doesn't match expected state
```

**Common Causes**:
- Side effects duplicated during replay
- Incomplete event data
- Missing events in replay

**Resolution Steps**:
1. Check side effect implementation:
   ```elixir
   # CORRECT - Side effects as separate actions
   change after_action(fn changeset, record, context ->
     MyApp.Notifications.Email
     |> Ash.Changeset.for_create(:send_email, %{user_id: record.id})
     |> Ash.create!(actor: context.actor)
     
     {:ok, record}
   end)
   ```

2. Verify event completeness:
   ```elixir
   test "all events are captured" do
     # Create, update, destroy operations
     user = create_user()
     user = update_user(user)
     destroy_user(user)
     
     # Verify all events exist
     events = MyApp.Events.Event |> Ash.read!()
     assert length(events) == 3
   end
   ```

3. Test state consistency:
   ```elixir
   test "replayed state matches original" do
     # Create complex state
     original_state = create_complex_state()
     
     # Clear and replay
     clear_state()
     replay_events()
     
     # Verify consistency
     replayed_state = get_current_state()
     assert replayed_state == original_state
   end
   ```

**Prevention**:
- Implement side effects as separate tracked actions
- Test event completeness for all operations
- Verify state consistency after replay

## Database Issues

### Migration Problems

**Error Pattern**:
```
Migration generation or execution failures
```

**Common Causes**:
- Database schema conflicts
- Migration dependency issues
- Resource configuration changes

**Resolution Steps**:
1. Generate clean migrations:
   ```bash
   mix test.reset
   mix test.generate_migrations
   ```

2. Check for schema conflicts:
   ```bash
   mix test.generate_migrations --check
   ```

3. Resolve migration issues:
   ```bash
   mix test.migrate
   ```

**Validation**:
```bash
mix test.reset && mix test.migrate
```

### Database Performance Issues

**Error Pattern**:
```
Slow event queries or replay operations
```

**Common Causes**:
- Missing database indexes
- Inefficient primary key types
- Large event volumes

**Resolution Steps**:
1. Use optimal primary key type:
   ```elixir
   event_log do
     primary_key_type Ash.Type.UUIDv7  # Better for time-ordered events
   end
   ```

2. Add database indexes:
   ```elixir
   # In migration
   create index(:events, [:resource])
   create index(:events, [:occurred_at])
   create index(:events, [:user_id])
   ```

3. Monitor query performance:
   ```bash
   mix test --trace
   ```

**Prevention**:
- Use UUIDv7 for event primary keys
- Index frequently queried fields
- Monitor performance with realistic data volumes

### Database Connection Pool Issues

**Error Pattern**:
```
Database connection timeout or pool exhaustion
```

**Common Causes**:
- Connection pool too small
- Long-running transactions
- Connection leaks

**Resolution Steps**:
1. Increase connection pool size:
   ```elixir
   config :ash_events, AshEvents.TestRepo,
     pool_size: 10
   ```

2. Check for connection leaks:
   ```bash
   mix test --trace
   ```

3. Monitor connection usage:
   ```elixir
   # In test setup
   :ok = Ecto.Adapters.SQL.Sandbox.checkout(AshEvents.TestRepo)
   ```

**Prevention**:
- Configure adequate connection pool size
- Use database sandbox in tests
- Monitor connection pool usage

## Performance Issues

### Event Creation Performance

**Error Pattern**:
```
Slow event creation during actions
```

**Common Causes**:
- Inefficient event storage
- Large metadata payloads
- Database contention

**Resolution Steps**:
1. Optimize event storage:
   ```elixir
   event_log do
     primary_key_type Ash.Type.UUIDv7
   end
   ```

2. Reduce metadata size:
   ```elixir
   context: %{ash_events_metadata: %{
     source: "api",
     request_id: request_id  # Keep minimal
   }}
   ```

3. Use advisory locks efficiently:
   ```elixir
   event_log do
     advisory_lock_key_default 31337
   end
   ```

**Prevention**:
- Use optimal primary key types
- Keep metadata concise
- Monitor event creation performance

### Replay Performance

**Error Pattern**:
```
Slow event replay operations
```

**Common Causes**:
- Large event volumes
- Inefficient clear_records implementation
- Database performance issues

**Resolution Steps**:
1. Optimize clear_records:
   ```elixir
   def clear_records!(opts) do
     # Use bulk operations
     MyApp.User |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)
     :ok
   end
   ```

2. Batch event processing:
   ```elixir
   # Process events in batches during replay
   events = MyApp.Events.Event
   |> Ash.Query.sort(occurred_at: :asc)
   |> Ash.Query.limit(1000)
   |> Ash.read!()
   ```

3. Monitor replay performance:
   ```bash
   time mix test --grep "replay"
   ```

**Prevention**:
- Use bulk operations for clearing
- Consider event archiving strategies
- Monitor replay performance

## Emergency Recovery

### Complete System Recovery

**When to Use**: Complete database corruption or major replay failure

**Recovery Steps**:
1. **Backup Current State**:
   ```bash
   pg_dump ash_events_test > backup.sql
   ```

2. **Reset Database**:
   ```bash
   mix test.reset
   ```

3. **Verify Migration**:
   ```bash
   mix test.generate_migrations --check
   ```

4. **Restore Known Good State**:
   ```bash
   # Restore from backup or recreate test data
   mix test.reset
   ```

5. **Validate Functionality**:
   ```bash
   mix test
   ```

### Partial Recovery

**When to Use**: Specific event or resource issues

**Recovery Steps**:
1. **Identify Problem**:
   ```bash
   mix test --grep "specific_issue"
   ```

2. **Clear Affected Resources**:
   ```elixir
   MyApp.ProblemResource |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)
   ```

3. **Replay Subset of Events**:
   ```elixir
   MyApp.Events.Event
   |> Ash.ActionInput.for_action(:replay, %{last_event_id: specific_id})
   |> Ash.run_action!()
   ```

4. **Verify State**:
   ```bash
   mix test --grep "state_verification"
   ```

## Troubleshooting Workflows

### Systematic Diagnosis

1. **Environment Check**:
   ```bash
   mix deps.get && mix deps.compile
   ```

2. **Database Validation**:
   ```bash
   mix test.reset
   ```

3. **Compilation Check**:
   ```bash
   mix compile --warnings-as-errors
   ```

4. **Test Execution**:
   ```bash
   mix test --trace
   ```

5. **Quality Validation**:
   ```bash
   mix credo --strict
   ```

### Quick Diagnostic

For immediate issue resolution:

```bash
# 1. Check basic functionality
mix test test/ash_events_test.exs

# 2. Check event creation
mix test -t event_creation

# 3. Check event replay
mix test -t event_replay

# 4. Check database state
mix test.reset && mix test
```

## Prevention Strategies

### Event Tracking Prevention
- Always use Events extension for tracked resources
- Always configure event_log reference
- Always set actor attribution
- Test event creation for all actions

### Replay Prevention
- Implement comprehensive clear_records
- Test replay functionality regularly
- Configure version management proactively
- Handle side effects as separate actions

### Performance Prevention
- Use optimal primary key types
- Keep metadata concise
- Monitor performance with realistic data
- Use bulk operations for efficiency

## Logging and Monitoring

### Event Creation Monitoring
```elixir
# Add logging to debug event creation
require Logger

defmodule MyApp.Events.DebugWrapper do
  def create_event(resource, action, data) do
    Logger.info("Creating event for #{resource}.#{action}")
    Logger.debug("Event data: #{inspect(data)}")
    # Create event
  end
end
```

### Replay Monitoring
```elixir
# Monitor replay progress
def debug_replay(opts \\ %{}) do
  events = MyApp.Events.Event
  |> Ash.Query.sort(occurred_at: :asc)
  |> Ash.read!()
  
  Logger.info("Replaying #{length(events)} events")
  
  # Replay events
  MyApp.Events.Event
  |> Ash.ActionInput.for_action(:replay, opts)
  |> Ash.run_action!()
end
```

## External Resources

- [Ash Framework Documentation](https://hexdocs.pm/ash)
- [AshEvents Documentation](https://hexdocs.pm/ash_events)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Elixir Documentation](https://hexdocs.pm/elixir)