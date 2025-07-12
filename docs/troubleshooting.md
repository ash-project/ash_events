# Troubleshooting Guide

## Common Issues

### Events Not Being Created
**Symptoms**: Actions execute but no events appear in event log
**Causes**:
- Action listed in `ignore_actions`
- Missing `events` extension on resource
- Event log resource not properly configured
- Action wrapper not applied

**Solutions**:
- Check `ignore_actions` vs `only_actions` configuration
- Verify `use Ash.Resource, extensions: [AshEvents.Events]`
- Ensure event log has `AshEvents.EventLog` extension

### Replay Failures
**Symptoms**: Replay action crashes or produces incorrect state
**Causes**:
- Missing `clear_records_for_replay` implementation
- Version mismatches between events and current actions
- Side effects in lifecycle hooks during replay

**Solutions**:
- Implement proper `clear_records!` function
- Use `replay_overrides` for version routing
- Move side effects to separate event-tracked actions

### Advisory Lock Issues
**Symptoms**: Deadlocks or performance problems
**Causes**:
- Default lock key causing conflicts
- Custom lock generator returning invalid keys
- Non-PostgreSQL database

**Solutions**:
- Configure unique `advisory_lock_key_default`
- Implement custom `AshEvents.AdvisoryLockKeyGenerator`
- Advisory locks only work with PostgreSQL

### Actor Attribution Problems
**Symptoms**: Actor IDs not being stored in events
**Causes**:
- Actor type mismatch with configured types
- Missing `actor` in action options
- Incorrect `persist_actor_primary_key` configuration

**Solutions**:
- Verify actor matches configured resource types
- Pass `actor: current_user` in action options
- Check attribute types match actor primary key types

### Encryption/Decryption Errors
**Symptoms**: Cannot read encrypted event data
**Causes**:
- Vault configuration changed
- Missing cloak dependency
- Key rotation without migration

**Solutions**:
- Verify vault configuration consistency
- Add `{:cloak, "~> 1.1"}` dependency
- Implement proper key rotation strategy

## Debugging Tips

### Enable Query Logging
```elixir
# config/dev.exs
config :logger, level: :debug
config :my_app, MyApp.Repo, log: :debug
```

### Inspect Event Data
```elixir
# Check event structure
events = MyApp.Events.Event |> Ash.read!()
IO.inspect(events, limit: :infinity)

# Verify action versions
event = List.first(events)
IO.puts("Version: #{event.version}")
```

### Test Replay Manually
```elixir
# Clear and replay step by step
MyApp.Events.ClearAllRecords.clear_records!([])
MyApp.Events.Event |> Ash.ActionInput.for_action(:replay, %{}) |> Ash.run_action!()
```

## Performance Considerations
- Event log can grow large over time - consider archival strategies
- Advisory locks serialize writes - may impact high-concurrency scenarios  
- Replay time increases with event count - consider incremental replay
- Encrypted events have performance overhead for large datasets