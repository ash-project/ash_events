# AshEvents Emergency Debugging Reference

> **Purpose**: Rapid debugging assistance and validation checklists for active development
> **For basic commands and workflows**: See [../AGENTS.md](../AGENTS.md)

## 🚨 Common Error Patterns & Solutions

### Test Database Issues
**Symptoms**: Tests failing with database errors, stale migrations, connection refused
**Root Causes**: Stale test database state, migration conflicts, connection issues
**Solution**: Complete database reset and verification
```bash
mix test.reset          # Reset test database completely
mix test --trace        # Verify tests pass with detailed output
```
**Prevention**: Always use `mix test.reset` before debugging, never `mix ecto.reset`

### Event Creation Failures
**Symptoms**: Events not being created, `nil` event_id, actor attribution missing
**Root Causes**: Missing actor in action calls, action wrapper not applied, event log misconfiguration
**Solution**: Run full test suite and check actor attribution
```bash
mix test.reset && mix test    # Reset and run all tests
```
**Debug Pattern**:
1. Check action call has `actor: user` parameter
2. Verify resource has `AshEvents.Events` extension
3. Confirm event_log reference is correct

### Replay Functionality Issues
**Symptoms**: Replay tests failing, "clear records not implemented", state mismatch after replay
**Root Causes**: Missing clear_records implementation, replay logic errors, version mismatches
**Solution**: Reset database and run full test suite
```bash
mix test.reset && mix test    # Reset and run all tests
```
**Debug Pattern**:
1. Verify `clear_records_for_replay` module exists and works
2. Check event chronological ordering
3. Test replay manually with `iex -S mix`

### Validation Message Issues
**Symptoms**: Custom validation messages disappearing during replay, default messages shown instead
**Root Cause**: Using `ReplayChangeWrapper` instead of `ReplayValidationWrapper`
**Solution**: Run tests to identify validation issues
```bash
mix test.reset && mix test    # Reset and run all tests
```
**Fix**: Ensure validations use `ReplayValidationWrapper.wrap_validator/2`

### Changed Attributes Replay Failures
**Symptoms**: Auto-generated attributes not replaying correctly, timestamp mismatches, computed fields lost
**Root Cause**: Incorrect replay strategy configuration for non-input attributes
**Solution**: Check replay strategy configuration
**Debug Pattern**:
1. Verify `replay_non_input_attribute_changes` is set correctly
2. Test `:force_change` vs `:as_arguments` strategies
3. Check if attributes are properly marked as non-input

### Type Check Failures (Dialyzer)
**Symptoms**: Type specification errors, unknown function warnings
**Root Cause**: Missing or incorrect type specifications after changes
**Solution**: Progressive type checking
```bash
mix dialyzer --format dialyxir           # Full type check
mix dialyzer lib/path/to/changed_file.ex # Check specific file
```

## ⚡ Quick Debugging Workflows

### 🔍 Debug Event Creation Issues
```bash
# 1. Run full test suite to identify failures
mix test.reset && mix test

# 2. Inspect event log configuration manually
iex -S mix
> MyApp.Events.EventLog.__ash_extension_config__()

# 3. Test with minimal example in IEx
# Create simple action with explicit actor, verify event created
```

### 🔄 Debug Replay Issues
```bash
# 1. Run full test suite first
mix test.reset && mix test

# 2. Test clear records manually
iex -S mix
> MyApp.Events.ClearAllRecords.clear_records!([])

# 3. Check event ordering manually
iex -S mix
> MyApp.Events.EventLog |> Ash.Query.sort(:inserted_at) |> Ash.read!()

# 4. Test step-by-step replay manually in IEx
# Clear -> Create one event -> Replay -> Verify state
```

### 🔧 Debug DSL Configuration Issues
```bash
# 1. Check DSL compilation
mix compile --force --warnings-as-errors

# 2. Inspect generated configuration
iex -S mix
> MyResource.__ash_extension_config__()
> MyResource.__ash_events_config__()

# 3. Check EventLog public_fields configuration
iex -S mix
> AshEvents.EventLog.Info.event_log_public_fields!(MyApp.EventLog)
> # Returns: :all, [:id, :version], or []

# 4. Verify field visibility
iex -S mix
> attrs = Ash.Resource.Info.attributes(MyApp.EventLog)
> Enum.filter(attrs, & &1.public?)

# 5. Test DSL options manually in IEx
```

### 🏗️ Debug Build/Compilation Issues
```bash
# 1. Clean compile with error details
rm -rf _build/ && mix compile --force --warnings-as-errors

# 2. Check dependency consistency
mix deps.get && mix deps.compile --force

# 3. Run full test suite after fixing compilation
mix test
```

## ✅ Development Validation Checklist

### 🎯 Before Committing Any Changes
- [ ] **Database Reset**: `mix test.reset` - Clean test state
- [ ] **All Tests Pass**: `mix test` - Full test suite passes (41 tests, ~1 second)
- [ ] **Code Quality**: `mix format && mix credo --strict` - Format and lint
- [ ] **Type Check**: `mix dialyzer` - No type specification errors
- [ ] **Documentation**: `mix docs` - Documentation builds without warnings
- [ ] **Manual Testing**: Test your changes in `iex -S mix` if needed

## 🏗️ Internal Architecture Quick Reference

### Event Creation Flow
```
Action Called → Action Wrapper → Event Created → Actor Attributed → Original Action Proceeds
```

### Event Replay Flow
```
Clear Records → Fetch Events (chronological) → Replay Actions → Reconstruct State
```

### DSL Processing Flow
```
DSL Definition → Transformers Apply Logic → Verifiers Validate → Documentation Generated
```

### Critical Extension Points
- **Action Wrappers**: Intercept and wrap resource actions
- **Transformers**: Implement DSL logic during compilation
- **Verifiers**: Validate DSL configuration and usage
- **Replay Logic**: Reconstruct state from event history

---

**🆘 When This Reference Fails**: Check [../AGENTS.md](../AGENTS.md) for comprehensive project guidance
**⚡ For Basic Commands**: See [../AGENTS.md](../AGENTS.md) command reference section
**📚 For Understanding Context**: See [../agent-docs/index.md](index.md) for complete documentation map

**Last Updated**: 2025-01-25
**Focus**: Emergency debugging, error resolution, and validation workflows
