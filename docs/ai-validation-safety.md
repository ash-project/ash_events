# AshEvents AI Assistant Validation & Safety

## Pre-Change Validation

### Mandatory Checks Before Any Changes

1. **Environment Validation**
   ```bash
   mix deps.get && mix deps.compile
   ```

2. **Database State Check**
   ```bash
   mix test.reset
   ```

3. **Test Status**
   ```bash
   mix test --trace
   ```

4. **Code Quality Check**
   ```bash
   mix credo --strict
   ```

## Post-Change Validation

### Required Validation Steps

1. **Event Tracking Validation**
   ```bash
   mix test test/ash_events_test.exs --trace
   ```

2. **Database Migration Validation**
   ```bash
   mix test.generate_migrations --check
   ```

3. **Type Checking**
   ```bash
   mix dialyzer
   ```

4. **Documentation Generation**
   ```bash
   mix docs
   ```

5. **Code Formatting**
   ```bash
   mix format --check-formatted
   ```

### Critical Safety Checks

- [ ] **Actor Attribution**: All actions have proper actor attribution
- [ ] **Clear Records Implementation**: `clear_records_for_replay` module exists and is comprehensive
- [ ] **Event Log Configuration**: Resources properly reference event log resource
- [ ] **Version Management**: Action versions are properly configured for schema evolution
- [ ] **Side Effects**: Side effects are implemented as separate tracked actions
- [ ] **Test Coverage**: New functionality has corresponding tests

## Testing Workflows

### Complete Testing Workflow

1. **Database Reset**: `mix test.reset`
2. **Unit Tests**: `mix test --trace`
3. **Integration Tests**: `mix test test/ash_events_test.exs`
4. **Code Quality**: `mix credo --strict`
5. **Type Checking**: `mix dialyzer`

### Event Tracking Testing

```bash
# Test event creation
mix test -t event_creation

# Test event replay
mix test -t event_replay

# Test version management
mix test -t version_management

# Test actor attribution
mix test -t actor_attribution
```

### Database Testing

```bash
# Reset database for clean state
mix test.reset

# Test migrations
mix test.generate_migrations --check

# Test tenant migrations (if applicable)
mix test.migrate_tenants

# Test rollback capability
mix test.rollback
```

## Event-Specific Validation

### Event Log Resource Validation

```elixir
# Test event log resource compilation
defmodule TestEventLogValidation do
  def validate_event_log_resource(module) do
    # Check extension is present
    assert AshEvents.EventLog in module.spark_dsl_config().extensions
    
    # Check clear_records_for_replay is configured
    event_log_config = module.spark_dsl_config().event_log
    assert event_log_config.clear_records_for_replay != nil
    
    # Check primary key type
    assert event_log_config.primary_key_type != nil
  end
end
```

### Events Extension Validation

```elixir
# Test events extension compilation  
defmodule TestEventsValidation do
  def validate_events_extension(module) do
    # Check extension is present
    assert AshEvents.Events in module.spark_dsl_config().extensions
    
    # Check event log is configured
    events_config = module.spark_dsl_config().events
    assert events_config.event_log != nil
    
    # Check action versions if specified
    if events_config.current_action_versions do
      assert is_map(events_config.current_action_versions)
    end
  end
end
```

### Actor Attribution Validation

```elixir
# Test actor attribution in actions
test "actions properly attribute actors" do
  user = User
  |> Ash.Changeset.for_create(:create, %{name: "Test"})
  |> Ash.create!(actor: %{id: 1, name: "Test Actor"})
  
  events = MyApp.Events.Event |> Ash.read!(authorize?: false)
  event = Enum.find(events, &(&1.record_id == user.id))
  
  assert event.user_id == 1
end
```

### Event Replay Validation

```elixir
# Test event replay functionality
test "can replay events to rebuild state" do
  # Create initial data
  user = create_test_user()
  update_test_user(user)
  
  # Store expected final state
  expected_state = get_user_state(user.id)
  
  # Clear state
  clear_all_records()
  
  # Replay events
  MyApp.Events.Event
  |> Ash.ActionInput.for_action(:replay, %{})
  |> Ash.run_action!(authorize?: false)
  
  # Verify state is restored
  restored_state = get_user_state(user.id)
  assert restored_state == expected_state
end
```

## Error Recovery

### Common Recovery Patterns

#### Database Corruption
1. **Reset Database**: `mix test.reset`
2. **Regenerate Migrations**: `mix test.generate_migrations`
3. **Verify Migration**: `mix test.migrate`

#### Event Replay Failures
1. **Check Clear Records**: Verify `clear_records!` implementation
2. **Check Version Management**: Verify replay overrides
3. **Check Actor Configuration**: Verify actor attribution setup

#### Compilation Errors
1. **Clean Dependencies**: `mix deps.clean --all && mix deps.get`
2. **Clean Build**: `mix clean && mix compile`
3. **Reset Database**: `mix test.reset`

## Quality Assurance

### Code Quality Checks

```bash
# Comprehensive code quality validation
mix credo --strict                       # Linting with strict rules
mix dialyzer                            # Type checking
mix format --check-formatted            # Code formatting
mix compile --warnings-as-errors       # Strict compilation
```

### Performance Validation

```bash
# Performance testing for large datasets
mix test test/performance/ --trace      # Performance-specific tests
mix test --only slow                    # Slow test suite
```

### Security Validation

```bash
# Security scanning
mix sobelow --skip -i Config.HTTPS     # Security analysis
mix audit                              # Dependency audit
```

## Event-Specific Safety Procedures

### Before Adding Event Tracking

1. **Plan Version Management**: Determine initial action versions
2. **Design Clear Records**: Plan what resources need clearing
3. **Configure Actor Types**: Plan actor attribution strategy
4. **Test Side Effects**: Identify and plan side effect handling

### Before Modifying Event Schema

1. **Plan Migration Strategy**: How to handle existing events
2. **Configure Replay Overrides**: How to route old event versions
3. **Test Backward Compatibility**: Ensure existing events still work
4. **Document Changes**: Update version numbers and documentation

### Before Event Replay

1. **Backup Current State**: Save current data before replay
2. **Verify Clear Records**: Ensure all tracked resources are cleared
3. **Test Replay Logic**: Test with subset of events first
4. **Monitor Performance**: Large replays can be time-consuming

## Testing Patterns

### Unit Testing Pattern

```elixir
defmodule MyApp.EventsTest do
  use ExUnit.Case
  
  setup do
    # Reset database for each test
    :ok = MyApp.Events.ClearAllRecords.clear_records!([])
    :ok
  end
  
  test "creates event when resource action is performed" do
    user = User
    |> Ash.Changeset.for_create(:create, %{name: "Test"})
    |> Ash.create!(authorize?: false)
    
    events = MyApp.Events.Event |> Ash.read!(authorize?: false)
    assert length(events) == 1
    
    event = hd(events)
    assert event.resource == MyApp.User
    assert event.record_id == user.id
    assert event.action == :create
  end
end
```

### Integration Testing Pattern

```elixir
defmodule MyApp.EventReplayTest do
  use ExUnit.Case
  
  test "full event replay scenario" do
    # Create test data with events
    user = create_user_with_events()
    org = create_org_with_events()
    associate_user_with_org(user, org)
    
    # Store expected final state
    expected_users = User |> Ash.read!(authorize?: false)
    expected_orgs = Org |> Ash.read!(authorize?: false)
    
    # Clear all data
    MyApp.Events.ClearAllRecords.clear_records!([])
    
    # Verify data is cleared
    assert User |> Ash.read!(authorize?: false) == []
    assert Org |> Ash.read!(authorize?: false) == []
    
    # Replay events
    MyApp.Events.Event
    |> Ash.ActionInput.for_action(:replay, %{})
    |> Ash.run_action!(authorize?: false)
    
    # Verify state is restored
    restored_users = User |> Ash.read!(authorize?: false)
    restored_orgs = Org |> Ash.read!(authorize?: false)
    
    assert length(restored_users) == length(expected_users)
    assert length(restored_orgs) == length(expected_orgs)
  end
end
```

## Debugging Procedures

### Event Tracking Debug

```elixir
# Debug event creation
def debug_event_creation(resource, action, params) do
  IO.puts("Creating #{resource} with action #{action}")
  IO.inspect(params, label: "Parameters")
  
  result = resource
  |> Ash.Changeset.for_create(action, params)
  |> Ash.create!(authorize?: false)
  
  events = MyApp.Events.Event |> Ash.read!(authorize?: false)
  IO.inspect(events, label: "Events after creation")
  
  result
end
```

### Event Replay Debug

```elixir
# Debug event replay
def debug_event_replay(opts \\ %{}) do
  events = MyApp.Events.Event 
  |> Ash.Query.sort(occurred_at: :asc)
  |> Ash.read!(authorize?: false)
  
  IO.puts("Replaying #{length(events)} events")
  
  Enum.each(events, fn event ->
    IO.puts("Replaying event #{event.id}: #{event.resource} #{event.action}")
  end)
  
  MyApp.Events.Event
  |> Ash.ActionInput.for_action(:replay, opts)
  |> Ash.run_action!(authorize?: false)
end
```

## Emergency Procedures

### Complete System Recovery

**When to Use**: Complete database corruption or major event replay failure

**Recovery Steps**:
1. **Backup Current State**: `pg_dump` if using PostgreSQL
2. **Reset Database**: `mix test.reset`
3. **Regenerate Migrations**: `mix test.generate_migrations`
4. **Restore Known Good Data**: From backup or re-create test data
5. **Verify Event Tracking**: Create test events and verify functionality

### Partial Recovery

**When to Use**: Specific event replay issues or data inconsistencies

**Recovery Steps**:
1. **Identify Issue**: Check event log for problematic events
2. **Clear Affected Resources**: Use targeted clearing
3. **Replay Subset**: Replay only affected events
4. **Verify Consistency**: Check data integrity

## Validation Checklist

Before any deployment or major change:

- [ ] All tests pass: `mix test`
- [ ] Code quality passes: `mix credo --strict`
- [ ] Type checking passes: `mix dialyzer`
- [ ] Documentation builds: `mix docs`
- [ ] Migrations are clean: `mix test.generate_migrations --check`
- [ ] Event tracking works: Create test events and verify
- [ ] Event replay works: Test replay with sample data
- [ ] Actor attribution works: Verify events have proper actors
- [ ] Side effects are properly handled: Verify no duplicate effects during replay
- [ ] Performance is acceptable: Test with realistic data volumes