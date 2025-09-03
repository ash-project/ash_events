# AshEvents Internal Development Validation & Safety

## Pre-Change Validation

### Mandatory Checks Before Any Internal Changes

1. **Environment Validation**
   ```bash
   mix test.reset
   ```

2. **Current Test State**
   ```bash
   mix test --trace
   ```

3. **Code Quality Baseline**
   ```bash
   mix format --check-formatted
   mix credo --strict
   mix dialyzer
   ```

## Post-Change Validation

### Required Validation Steps for AshEvents Development

1. **Core Functionality Validation**
   ```bash
   mix test test/ash_events/event_creation_test.exs
   mix test test/ash_events/actor_attribution_test.exs
   ```

2. **Feature-Specific Validation**
   ```bash
   mix test test/ash_events/replay_test.exs
   mix test test/ash_events/bulk_actions_test.exs
   ```

3. **Full Test Suite**
   ```bash
   mix test --trace
   ```

4. **Quality Validation**
   ```bash
   mix format
   mix credo --strict
   mix dialyzer
   ```

5. **Documentation Validation**
   ```bash
   mix docs
   ```

### Critical Safety Checks for AshEvents

- [ ] All event creation tests pass
- [ ] Actor attribution works correctly  
- [ ] Event replay functionality works
- [ ] Clear records implementation functions
- [ ] No regressions in existing functionality
- [ ] Documentation generates without errors
- [ ] No new dialyzer warnings
- [ ] All code is properly formatted

## Testing Workflows

### Complete AshEvents Testing Workflow

1. **Database Reset**: `mix test.reset`
2. **Core Event Tests**: `mix test test/ash_events/event_creation_test.exs`
3. **Actor Tests**: `mix test test/ash_events/actor_attribution_test.exs`  
4. **Replay Tests**: `mix test test/ash_events/replay_test.exs`
5. **Full Test Suite**: `mix test`

### Feature-Specific Testing

#### After DSL Changes
```bash
# Test DSL functionality
mix test test/ash_events/ --grep "dsl"
mix docs  # Verify documentation generation
```

#### After Action Wrapper Changes
```bash
# Test event creation
mix test test/ash_events/event_creation_test.exs
mix test test/ash_events/bulk_actions_test.exs
mix test test/ash_events/upsert_test.exs
```

#### After Replay Logic Changes
```bash
# Test replay functionality
mix test test/ash_events/replay_test.exs
mix test --grep "replay"
```

#### After Test Resource Changes
```bash
# Verify test resources work
mix test test/support/
mix test --trace  # Full test with all resources
```

### Regression Testing

```bash
# Complete regression test for AshEvents
mix test.reset
mix test
mix format --check-formatted
mix credo --strict
mix dialyzer
mix docs
```

## Error Recovery

### Common Recovery Patterns

#### Database State Issues
1. `mix test.reset` to completely reset test database
2. `mix test.migrate` to ensure migrations are current  
3. `mix test` to verify clean state

#### Compilation Issues
1. `mix clean`
2. `mix compile --force`
3. `mix deps.get` if dependency issues
4. `mix test` to verify compilation

#### Test Resource Issues  
1. Check test resources in `test/support/`
2. Verify event log and clear records implementations
3. Reset database: `mix test.reset`
4. Run specific test file to isolate issue

#### Documentation Generation Issues
1. `mix compile --force` to ensure code compiles
2. Check DSL definitions for syntax errors
3. `mix docs` to regenerate
4. Check for any missing documentation metadata

## Quality Assurance

### Code Quality Checks for AshEvents

```bash
mix format                               # Format AshEvents code
mix format --check-formatted             # Verify formatting without changes
mix credo --strict                       # Strict linting for AshEvents
mix dialyzer                             # Type checking
mix sobelow --config                     # Security analysis (if configured)
```

### Performance Validation for AshEvents

```bash
# Test with larger datasets
mix test test/ash_events/bulk_actions_test.exs

# Memory usage patterns (if needed)
# Custom performance tests for specific scenarios
```

### AshEvents-Specific Security Validation

```bash
# Actor attribution security
mix test test/ash_events/actor_attribution_test.exs

# Event encryption (if applicable)  
mix test test/ash_events/encryption_test.exs

# Validation bypass prevention
mix test test/ash_events/validation_test.exs
```

## Internal Development Testing Patterns

### Testing New DSL Options

1. **Create test resource** in `test/support/` with new DSL option
2. **Write test case** in appropriate `test/ash_events/` file
3. **Test both positive and negative cases**
4. **Verify documentation generation** includes new option

Example:
```elixir
# In test/support/events/event_log.ex
event_log do
  # existing options...
  new_option true  # Test new DSL option
end
```

### Testing Action Wrapper Changes

1. **Test all action types**: create, update, destroy
2. **Test bulk actions** if applicable  
3. **Test with different actor configurations**
4. **Test parameter filtering and casting**

Example Test Pattern:
```elixir
test "action wrapper handles new scenario" do
  user = create_user()
  
  org = TestOrg.create!(%{name: "test"}, actor: user)
  
  # Verify event was created
  events = TestEventLog.read!()
  assert length(events) == 1
  
  event = hd(events)
  assert event.actor_id == user.id
end
```

### Testing Replay Functionality

1. **Test simple replay scenarios** first
2. **Test complex scenarios** with state machines, embedded resources
3. **Test clear records** thoroughly
4. **Test error handling** during replay

Example Test Pattern:
```elixir
test "replay handles complex scenario" do
  # Create initial state
  user = create_user()
  org = create_org(actor: user)
  
  # Clear all records
  TestEventLog.replay!()
  
  # Verify state was restored
  restored_orgs = TestOrg.read!()
  assert length(restored_orgs) == 1
end
```

### Testing Error Conditions

1. **Test missing actor scenarios**
2. **Test invalid parameter scenarios**  
3. **Test replay failure scenarios**
4. **Test resource validation scenarios**

## Troubleshooting Validation Issues

### Test Database Problems
**Symptoms**: Tests failing with database errors, migration issues
**Solution**: 
```bash
mix test.reset
mix test.migrate  
mix test
```

### Actor Attribution Test Failures
**Symptoms**: Actor attribution tests failing, events created without actors
**Solution**:
1. Check test resource setup in `test/support/`
2. Verify actor is passed to all actions
3. Check action wrapper implementation

### Event Creation Test Failures  
**Symptoms**: Events not being created, event creation tests failing
**Solution**:
1. Check action wrapper logic in `lib/events/`
2. Verify Events extension is properly applied
3. Check parameter filtering and casting logic

### Replay Test Failures
**Symptoms**: Replay functionality not working, clear records failing
**Solution**:
1. Check clear records implementation
2. Verify replay logic in `lib/event_log/replay.ex`
3. Test with simpler scenario first

### Documentation Generation Failures
**Symptoms**: `mix docs` failing, DSL documentation missing
**Solution**:
1. Check DSL syntax in extension files
2. Verify all modules compile successfully  
3. Check for missing documentation metadata

## Comprehensive Validation Checklist

### Before Committing AshEvents Changes
- [ ] `mix test.reset` - Clean database state
- [ ] `mix test` - All tests pass
- [ ] `mix test test/ash_events/event_creation_test.exs` - Event creation works
- [ ] `mix test test/ash_events/actor_attribution_test.exs` - Actor attribution works  
- [ ] `mix test test/ash_events/replay_test.exs` - Replay functionality works
- [ ] `mix format` - Code is formatted
- [ ] `mix credo --strict` - No linting issues
- [ ] `mix dialyzer` - No type errors
- [ ] `mix docs` - Documentation generates successfully

### After Major Changes
- [ ] **Full regression test** - All functionality works
- [ ] **Performance test** - No significant performance degradation
- [ ] **Edge case testing** - Complex scenarios work
- [ ] **Error handling test** - Failures are handled gracefully
- [ ] **Documentation review** - All changes are documented

---

**Emergency Recovery**: If all else fails, run `mix test.reset && mix test --trace`  
**Last Updated**: 2025-01-25  
**Focus**: Internal AshEvents development testing and validation