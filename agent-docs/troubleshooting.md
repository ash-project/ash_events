<!--
SPDX-FileCopyrightText: 2024 Torkild G. Kjevik

SPDX-License-Identifier: MIT
-->

# AshEvents Troubleshooting

Quick diagnosis and solutions for common development issues.

## Quick Diagnosis

| Symptoms | Cause | Solution |
|----------|-------|----------|
| Tests failing with database errors | Stale test database | `mix test.reset` |
| Events not being created | Missing actor attribution | Add `actor: user` to action calls |
| `nil` event_id after action | Action wrapper not applied | Verify `AshEvents.Events` extension added |
| Replay fails with "clear records not implemented" | Missing clear_records module | Implement `AshEvents.ClearRecordsForReplay` |
| State mismatch after replay | Incorrect replay strategy | Check `replay_non_input_attribute_changes` config |
| Validation messages lost during replay | Wrong wrapper used | Use `ReplayValidationWrapper.wrap_validator/2` |
| Type specification errors (Dialyzer) | Missing type specs | Add specs to new public functions |
| "Module not compiled" errors | Wrong environment | Ensure using test environment |
| Encrypted fields show `%Ash.NotLoaded{}` | Fields not loaded | Use `Ash.load!(record, [:data])` |
| `Ash.Error.Forbidden` on read | Missing read policy | Add read policy or use `authorize?: false` |
| FK constraint on destroy | Related records exist | Use action without side effects or clear related records |
| `version` field confusion | Using wrong field name | Use `event.version` not `event.action_version` |

## Event Creation Issues

### Events Not Being Created

**Symptoms**: Actions complete but no events appear in event log

**Causes**:
1. Missing actor attribution
2. Action not tracked (in `ignore_actions` list)
3. Extension not added to resource

**Solutions**:

```elixir
# ❌ WRONG - No actor
Ash.create!(changeset)

# ✅ CORRECT - With actor
Ash.create!(changeset, actor: current_user)
```

```elixir
# Check resource has extension
defmodule MyApp.User do
  use Ash.Resource,
    extensions: [AshEvents.Events]  # ✅ Required

  events do
    event_log MyApp.EventLog  # ✅ Required
  end
end
```

**Debug Pattern**:
```bash
# 1. Run full test suite
mix test.reset && mix test

# 2. Check configuration in IEx
iex -S mix
> MyApp.User.__ash_extension_config__()
```

### Actor Attribution Missing

**Symptoms**: Events created but `user_id` or actor field is nil

**Causes**:
1. Actor not passed to action
2. Actor type doesn't match `persist_actor_primary_key` config

**Solutions**:
```elixir
# In EventLog resource
event_log do
  persist_actor_primary_key :user_id, MyApp.User
end

# When calling action
Ash.create!(changeset, actor: user)  # user must be MyApp.User
```

## Replay Issues

### "clear_records_for_replay Must Be Specified"

**Symptoms**: Replay action fails with error about missing clear_records

**Solution**: Implement clear records module

```elixir
defmodule MyApp.ClearAllRecords do
  use AshEvents.ClearRecordsForReplay

  @impl true
  def clear_records!(opts) do
    # Clear all tracked resources in correct order
    # (destroy children before parents)
    Ash.bulk_destroy!(MyApp.Post, :destroy, %{}, opts)
    Ash.bulk_destroy!(MyApp.User, :destroy, %{}, opts)
    :ok
  end
end
```

```elixir
# In EventLog resource
event_log do
  clear_records_for_replay MyApp.ClearAllRecords
end
```

### State Mismatch After Replay

**Symptoms**: Replayed state doesn't match expected state, especially for auto-generated attributes

**Causes**:
1. Changed attributes not captured
2. Wrong replay strategy
3. Timestamps not configured

**Solutions**:

```elixir
# Configure replay strategy
events do
  event_log MyApp.EventLog
  replay_non_input_attribute_changes [
    create: :force_change,    # Default - preserves exact values
    update: :as_arguments     # Alternative - merges into input
  ]

  # Configure timestamps if using them
  create_timestamp :inserted_at
  update_timestamp :updated_at
end
```

### Replay Fails for Specific Events

**Symptoms**: Some events replay correctly, others fail

**Debug Pattern**:
```elixir
# In IEx, check events
events = Ash.read!(MyApp.EventLog, query: [sort: [id: :asc]])

# Examine problematic event
event = Enum.find(events, &(&1.id == problematic_id))
IO.inspect(event.data)
IO.inspect(event.changed_attributes)
IO.inspect(event.version)
```

## Validation Issues

### Validation Messages Disappearing During Replay

**Symptoms**: Custom validation messages show during normal operation but not during replay

**Cause**: Using `ReplayChangeWrapper` instead of `ReplayValidationWrapper`

**Solution**:
```elixir
# For validations, use ReplayValidationWrapper
validations do
  validate {ReplayValidationWrapper, validator: MyValidator, message: "Custom message"}
end
```

## Authorization Issues

### Forbidden Errors When Reading

**Symptoms**: `Ash.Error.Forbidden` when trying to read resources

**Causes**:
1. Resource has authorization policies but no read policy
2. Actor doesn't satisfy policy conditions

**Solutions**:

```elixir
# Option 1: Use SystemActor which bypasses policies
alias AshEvents.EventLogs.SystemActor
actor = %SystemActor{name: "test_runner"}
{:ok, record} = Ash.get(MyResource, id, actor: actor)

# Option 2: Bypass authorization (use carefully)
records = Ash.read!(MyResource, authorize?: false)

# Option 3: Add appropriate policy to resource
policies do
  policy action(:read) do
    authorize_if always()
  end
end
```

### Users Can Only Modify Themselves

**Symptoms**: Update/destroy fails with authorization error for other users

**Cause**: Policy restricts users to modifying only their own records

**Solution**: Design tests where users modify their own records, or use SystemActor:

```elixir
# User destroys themselves (allowed by policy)
{:ok, _} = Ash.destroy(user, actor: user)

# Or use SystemActor to bypass
actor = %SystemActor{name: "admin"}
{:ok, _} = Ash.destroy(other_user, actor: actor)
```

## Encryption Issues

### Encrypted Fields Not Decrypting

**Symptoms**: Event data shows as encrypted binary or `%Ash.NotLoaded{}`

**Causes**:
1. Cloak vault not configured
2. Encrypted fields are calculations that must be explicitly loaded

**Solutions**:
```elixir
# Ensure vault is configured in EventLog
event_log do
  cloak_vault MyApp.Vault
end

# IMPORTANT: Encrypted data/metadata are calculations - must load them
events = Ash.read!(MyApp.EventLog)
event = hd(events)

# This will show %Ash.NotLoaded{}
event.data  # => %Ash.NotLoaded{}

# Must load the calculation
event = Ash.load!(event, [:data, :metadata])
event.data  # => %{"name" => "decrypted value"}
```

## Test Resource Issues

### FK Constraint Errors on Destroy

**Symptoms**: Destroy action fails with foreign key constraint violation

**Cause**: Related records (like UserRole) created as side effects block destroy

**Solutions**:

```elixir
# Option 1: Use an action that doesn't create side effects
# The User resource has :create_with_form which doesn't create UserRole
{:ok, user} =
  User
  |> Ash.Changeset.for_create(:create_with_form, %{...})
  |> Ash.create(actor: actor)

# This user can be destroyed without FK issues
{:ok, _} = Ash.destroy(user, actor: user)

# Option 2: Clear related records first
Ash.bulk_destroy!(UserRole, :destroy, %{}, authorize?: false)
```

### Resource Missing Expected Action

**Symptoms**: `No such action` error

**Cause**: Not all test resources have all CRUD actions

**Known limitations**:
- `OrgCloaked` has no `:destroy` action
- `OrgStateMachine` only has `:create` and `:set_inactive` policies

**Solution**: Check resource definition or use a different resource for testing:

```elixir
# Check available actions
Ash.Resource.Info.actions(MyResource)
```

## Database Issues

### Test Database State Issues

**Symptoms**: Tests pass individually but fail when run together, or random test failures

**Solution**: Always reset before running tests
```bash
mix test.reset && mix test
```

### Migration Errors

**Symptoms**: Errors about missing columns or tables

**Solution**:
```bash
# Regenerate and run migrations
mix test.reset
mix test.generate_migrations
mix test.migrate
```

## Debugging Workflows

### Debug Event Creation
```bash
# 1. Reset and run tests
mix test.reset && mix test

# 2. Interactive debugging
iex -S mix
> user = Ash.create!(Ash.Changeset.for_create(MyApp.User, :create, %{email: "test@test.com"}))
> post = Ash.create!(Ash.Changeset.for_create(MyApp.Post, :create, %{title: "Test"}), actor: user)
> Ash.read!(MyApp.EventLog)
```

### Debug Replay Issues
```bash
# 1. Run tests first
mix test.reset && mix test

# 2. Interactive replay testing
iex -S mix
> MyApp.ClearAllRecords.clear_records!([])
> events = Ash.read!(MyApp.EventLog, query: [sort: [id: :asc]])
> Ash.run_action!(MyApp.EventLog, :replay)
> Ash.read!(MyApp.User)  # Check reconstructed state
```

### Debug DSL Configuration
```elixir
# In IEx
iex -S mix

# Check EventLog configuration
> AshEvents.EventLog.Info.event_log_public_fields!(MyApp.EventLog)
# Returns: :all, [:id, :version], or []

# Check Events configuration
> AshEvents.Events.Info.events_event_log!(MyApp.User)
# Returns: MyApp.EventLog

# Verify field visibility
> attrs = Ash.Resource.Info.attributes(MyApp.EventLog)
> Enum.filter(attrs, & &1.public?)
```

## Critical Environment Rules

**Always use test environment:**
```bash
# ✅ CORRECT
mix test.reset
mix test
mix test --trace

# ❌ WRONG
mix ecto.reset          # Use mix test.reset instead
MIX_ENV=dev mix test    # Tests require test environment
```

## Validation Workflow

After fixing issues, always validate:

```bash
# 1. Reset database
mix test.reset

# 2. Run all tests
mix test

# 3. Check formatting and linting
mix format && mix credo --strict

# 4. Type check (for significant changes)
mix dialyzer
```

## Internal Architecture Quick Reference

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

**See also**: [development-workflows.md](development-workflows.md), [testing-and-validation.md](testing-and-validation.md)
