# AshEvents Internal Development Quick Reference

## Emergency Commands

### 🚨 CRITICAL REMINDERS
- **ALWAYS use `mix test.reset` - NEVER use `mix ecto.reset`**
- **ALWAYS set actor attribution in tests - NEVER create events without actor**
- **ALWAYS read [AGENTS.md](../AGENTS.md) before making changes**

### Core Development Commands

```bash
# Database Management (AshEvents specific)
mix test.reset                           # Drop, create, migrate test database
mix test.create                          # Create test database
mix test.migrate                         # Run migrations
mix test.generate_migrations             # Generate migrations

# Testing AshEvents
mix test                                 # Run all AshEvents tests
mix test --trace                         # Run tests with detailed output
mix test test/ash_events/event_creation_test.exs  # Test event creation
mix test --grep "replay"                 # Test replay functionality

# Quality checks for AshEvents code
mix format                               # Format AshEvents codebase
mix credo --strict                       # Lint AshEvents code
mix dialyzer                             # Type check AshEvents code
mix docs                                 # Generate AshEvents documentation
```

## Quick Development Patterns

### Adding New DSL Option to EventLog
1. Add option in `lib/event_log/event_log.ex` DSL definition
2. Implement logic in appropriate transformer in `lib/event_log/transformers/`
3. Add tests in `test/ash_events/`
4. Regenerate docs with `mix docs`

### Adding New DSL Option to Events
1. Add option in `lib/events/events.ex` DSL definition
2. Implement logic in appropriate transformer in `lib/events/transformers/`
3. Add tests in `test/ash_events/`
4. Test with example resource in `test/support/`

### Modifying Action Wrapper Behavior
1. Edit relevant wrapper in `lib/events/*_action_wrapper.ex`
2. Update common functionality in `lib/events/action_wrapper_helpers.ex`
3. Update tests in `test/ash_events/event_creation_test.exs`
4. Verify actor attribution tests still pass

## Common Error Patterns

### Test Database Issues
**Symptoms**: Tests failing with database errors, stale migrations
**Solution**: Reset test database completely
**Commands**:
```bash
mix test.reset
mix test --trace
```

### Event Creation Failures  
**Symptoms**: Events not being created, actor attribution errors
**Solution**: Check action wrapper implementation and actor setup
**Debug Commands**:
```bash
mix test test/ash_events/event_creation_test.exs --trace
mix test test/ash_events/actor_attribution_test.exs --trace
```

### Replay Functionality Issues
**Symptoms**: Replay tests failing, clear records not working
**Solution**: Check replay logic and clear records implementation
**Debug Commands**:
```bash
mix test test/ash_events/replay_test.exs --trace
mix test --grep "replay" --trace
```

### Documentation Generation Issues
**Symptoms**: `mix docs` failing, DSL docs not updating
**Solution**: Check DSL definitions and ensure code compiles
**Debug Commands**:
```bash
mix compile --force
mix docs
```

### Validation Message Issues  
**Symptoms**: Custom validation messages not appearing, default messages shown instead
**Solution**: Check that validations are using ReplayValidationWrapper (not ReplayChangeWrapper)
**Debug Commands**:
```bash
mix test test/ash_events/validation_test.exs --trace
```

### Type Check Failures
**Symptoms**: Dialyzer errors, type specification issues
**Solution**: Check type specifications in modified files
**Debug Commands**:
```bash
mix dialyzer --format dialyxir
```

## Critical File Locations

### Core Extension Files
- **EventLog DSL**: `lib/event_log/event_log.ex`
- **Events DSL**: `lib/events/events.ex`
- **Action Helpers**: `lib/events/action_wrapper_helpers.ex`
- **Replay Logic**: `lib/event_log/replay.ex`

### Action Wrappers
- **Create Events**: `lib/events/create_action_wrapper.ex`
- **Update Events**: `lib/events/update_action_wrapper.ex`
- **Destroy Events**: `lib/events/destroy_action_wrapper.ex`
- **Change Wrapper**: `lib/events/replay_change_wrapper.ex`
- **Validation Wrapper**: `lib/events/replay_validation_wrapper.ex`

### Transformers and Verifiers
- **EventLog Transformers**: `lib/event_log/transformers/`
- **Events Transformers**: `lib/events/transformers/`
- **EventLog Verifiers**: `lib/event_log/verifiers/`

### Key Test Files
- **Event Creation**: `test/ash_events/event_creation_test.exs`
- **Actor Attribution**: `test/ash_events/actor_attribution_test.exs`
- **Replay Tests**: `test/ash_events/replay_test.exs`
- **Bulk Actions**: `test/ash_events/bulk_actions_test.exs`
- **Validation Messages**: `test/ash_events/validation_test.exs`

### Test Support Resources
- **Event Log**: `test/support/events/event_log.ex`
- **Clear Records**: `test/support/events/clear_records.ex`  
- **Test User**: `test/support/accounts/user.ex`
- **Test Org**: `test/support/accounts/org.ex`

## Development Validation Checklist

### Before Committing Changes
- [ ] `mix test` - All tests pass
- [ ] `mix format` - Code is formatted
- [ ] `mix credo --strict` - No linting issues
- [ ] `mix dialyzer` - No type errors
- [ ] `mix docs` - Documentation generates without errors

### After DSL Changes
- [ ] DSL options work in test resources
- [ ] Generated documentation reflects changes
- [ ] Tests cover new functionality
- [ ] Existing functionality still works

### After Action Wrapper Changes
- [ ] Event creation tests pass
- [ ] Actor attribution tests pass
- [ ] All action types (create/update/destroy) work
- [ ] Bulk action tests pass if applicable

### After Replay Changes
- [ ] Replay tests pass
- [ ] Clear records functionality works
- [ ] Complex replay scenarios work (state machines, etc.)
- [ ] Version management still functions

## Quick Debugging Workflows

### Debug Event Creation Issues
1. Run specific test: `mix test test/ash_events/event_creation_test.exs --trace`
2. Check actor setup in test resource
3. Verify action wrapper logic
4. Check parameter filtering and casting

### Debug Replay Issues
1. Run replay tests: `mix test test/ash_events/replay_test.exs --trace`
2. Check clear records implementation
3. Verify replay logic in `lib/event_log/replay.ex`
4. Test with simple scenario first

### Debug DSL Issues
1. Check DSL definition syntax
2. Verify transformer implementation
3. Test with minimal example resource
4. Check generated documentation for errors

### Debug Build Issues
1. `mix compile --force --warnings-as-errors`
2. `mix deps.get` to ensure dependencies are current
3. `mix dialyzer` for type issues
4. Check `mix.exs` for configuration issues

## Internal Architecture Reference

### Event Flow
1. **Action called** on resource with Events extension
2. **Action wrapper** intercepts action
3. **Event created** using EventLog resource
4. **Actor attributed** from action context
5. **Original action** proceeds normally

### Replay Flow  
1. **Clear records** called to clean state
2. **Events fetched** chronologically from EventLog
3. **Actions replayed** using stored parameters
4. **State reconstructed** from event sequence

### DSL Extension Pattern
1. **DSL defined** in main extension file
2. **Transformers** implement DSL logic
3. **Verifiers** validate DSL usage
4. **Documentation** generated from DSL definitions

---

**Emergency Contact**: Check [AGENTS.md](../AGENTS.md) for comprehensive guidance  
**Last Updated**: 2025-01-25  
**Focus**: Internal AshEvents development commands and patterns