# AshEvents AI Assistant Quick Reference

## Emergency Commands

### 🚨 CRITICAL REMINDERS
- **ALWAYS set actor when performing actions** - Never omit actor attribution
- **ALWAYS read [usage-rules.md](../usage-rules.md) before implementing** - Contains comprehensive patterns
- **ALWAYS implement `clear_records_for_replay` module** - Required for event replay functionality

### Core Commands

```bash
# Database Management
mix test.reset                           # Drop, create, and migrate test database
mix test.create                          # Create test database
mix test.migrate                         # Run migrations
mix test.generate_migrations             # Generate new migrations

# Testing
mix test                                 # Run all tests
mix test --trace                         # Run tests with detailed output
mix test test/specific_test.exs          # Run specific test file

# Code Quality
mix credo --strict                       # Run linting with strict rules
mix dialyzer                             # Run type checking
mix format                               # Format code

# Documentation
mix docs                                 # Generate documentation
mix ash.codegen                          # Run Ash codegen tasks
```

## Quick Task Patterns

### Add Event Tracking to Resource
1. Add extension: `extensions: [AshEvents.Events]`
2. Configure event log: `event_log MyApp.Events.Event`
3. Set actor when performing actions: `actor: current_user`

### Create Event Log Resource
1. Create resource with `AshEvents.EventLog` extension
2. Configure `clear_records_for_replay` module
3. Set `primary_key_type Ash.Type.UUIDv7` for performance
4. Add actor attribution: `persist_actor_primary_key :user_id, MyApp.User`

### Event Replay Implementation
1. Implement `clear_records_for_replay` module
2. Use `AshEvents.ClearRecordsForReplay` behaviour
3. Call replay action: `Ash.ActionInput.for_action(:replay, %{})`

## Common Error Patterns

### Missing Actor Attribution
**Symptoms**: Events created without actor information
**Solution**: Always set actor when performing actions
**Command**: `Ash.create!(changeset, actor: current_user)`

### Clear Records Not Implemented
**Symptoms**: Compilation error about missing clear_records_for_replay
**Solution**: Implement the clear records module
**Command**: `use AshEvents.ClearRecordsForReplay`

### Event Replay Failures
**Symptoms**: Replay action fails with missing records
**Solution**: Ensure clear_records! implementation clears all tracked resources
**Command**: Check `clear_records!` implementation covers all event-tracked resources

## Critical File Locations

### Core Implementation Files
- **Event Log Extension**: `lib/event_log/event_log.ex`
- **Events Extension**: `lib/events/events.ex`
- **Action Wrappers**: `lib/events/*_action_wrapper.ex`
- **Replay Logic**: `lib/event_log/replay.ex`

### Test Support Files
- **Event Log Example**: `test/support/events/event_log.ex`
- **Clear Records Example**: `test/support/events/clear_records.ex`
- **User Resource Example**: `test/support/accounts/user.ex`
- **Test Configuration**: `test/support/test_repo.ex`

### Configuration Files
- **Project Config**: `mix.exs`
- **Test Config**: `config/test.exs`
- **App Config**: `config/config.exs`

## Event Log Resource Pattern

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

## Events Extension Pattern

```elixir
defmodule MyApp.Accounts.User do
  use Ash.Resource,
    extensions: [AshEvents.Events]

  events do
    event_log MyApp.Events.Event
    current_action_versions create: 1, update: 1
  end
end
```

## Clear Records Pattern

```elixir
defmodule MyApp.Events.ClearAllRecords do
  use AshEvents.ClearRecordsForReplay

  @impl true
  def clear_records!(opts) do
    # Clear all resources with event tracking
    MyApp.User |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)
    :ok
  end
end
```

## Actor Attribution Pattern

```elixir
# CORRECT - Always set actor
user = User
|> Ash.Changeset.for_create(:create, %{name: "John"})
|> Ash.create!(actor: current_user)

# INCORRECT - No actor attribution
user = User
|> Ash.Changeset.for_create(:create, %{name: "John"})
|> Ash.create!()
```

## Metadata Pattern

```elixir
User
|> Ash.Changeset.for_create(:create, %{name: "Jane"}, [
  actor: current_user,
  context: %{ash_events_metadata: %{
    source: "api",
    request_id: request_id,
    ip_address: client_ip
  }}
])
|> Ash.create!()
```

## Event Replay Pattern

```elixir
# Replay all events
MyApp.Events.Event
|> Ash.ActionInput.for_action(:replay, %{})
|> Ash.run_action!()

# Replay up to specific event
MyApp.Events.Event
|> Ash.ActionInput.for_action(:replay, %{last_event_id: 1000})
|> Ash.run_action!()
```

## Version Management Pattern

```elixir
# In Event Log Resource
replay_overrides do
  replay_override MyApp.User, :create do
    versions [1]
    route_to MyApp.User, :old_create_v1
  end
end

# In Resource
events do
  event_log MyApp.Events.Event
  current_action_versions create: 2, update: 1
  ignore_actions [:old_create_v1]
end
```

## Side Effects Pattern

```elixir
# CORRECT - Side effects as separate actions
actions do
  create :create do
    change after_action(fn changeset, user, context ->
      MyApp.Notifications.Email
      |> Ash.Changeset.for_create(:send_welcome, %{user_id: user.id})
      |> Ash.create!(actor: context.actor)
      
      {:ok, user}
    end)
  end
end

# Email resource also tracks events
defmodule MyApp.Notifications.Email do
  use Ash.Resource, extensions: [AshEvents.Events]
  
  events do
    event_log MyApp.Events.Event
  end
end
```

## Testing Pattern

```elixir
test "creates user with event tracking" do
  user = User
  |> Ash.Changeset.for_create(:create, %{name: "Test"})
  |> Ash.create!(authorize?: false)
  
  events = MyApp.Events.Event |> Ash.read!(authorize?: false)
  assert length(events) == 1
  assert hd(events).resource == MyApp.User
end
```

## Validation Checklist

- [ ] Event log resource created with `AshEvents.EventLog` extension
- [ ] Clear records module implemented with `AshEvents.ClearRecordsForReplay`
- [ ] Resources have `AshEvents.Events` extension with event_log configured
- [ ] Actor attribution set on all actions
- [ ] Metadata includes relevant context information
- [ ] Side effects implemented as separate tracked actions
- [ ] Version management configured for schema evolution
- [ ] Tests verify event creation and replay functionality

## Common Gotchas

- **Lifecycle hooks skipped during replay** - Side effects won't re-execute
- **Actor attribution required** - Events without actors lose audit trail
- **Clear records must be comprehensive** - Must clear all event-tracked resources
- **Metadata size limits** - Keep metadata reasonable for JSON storage
- **Version management complexity** - Plan schema evolution carefully
- **Advisory locks** - Used automatically for concurrency control