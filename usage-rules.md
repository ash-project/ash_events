# AshEvents Usage Rules and Patterns

## 🚨 CRITICAL RULES - READ FIRST

### **RULE 1: ALWAYS SET ACTOR ATTRIBUTION**

**MANDATORY**: You MUST set actor attribution for ALL actions that create events.

```elixir
# ✅ CORRECT - Always set actor
Ash.create!(changeset, actor: current_user)
Ash.update!(changeset, actor: current_user)
Ash.destroy!(record, actor: current_user)

# ❌ WRONG - Missing actor attribution
Ash.create!(changeset)  # Will lose audit trail information
```

### **RULE 2: IMPLEMENT CLEAR_RECORDS_FOR_REPLAY**

**MANDATORY**: You MUST implement the `clear_records_for_replay` module for event replay.

```elixir
defmodule MyApp.Events.ClearAllRecords do
  use AshEvents.ClearRecordsForReplay
  
  @impl true
  def clear_records!(opts) do
    # Must clear ALL resources with event tracking
    :ok
  end
end
```

---

## Table of Contents

1. [Understanding AshEvents](#understanding-ashevents)
2. [Core Concepts](#core-concepts)
3. [Quick Start Setup](#quick-start-setup)
4. [Event Tracking Patterns](#event-tracking-patterns)
5. [Event Replay](#event-replay)
6. [Version Management](#version-management)
7. [Side Effects and Lifecycle](#side-effects-and-lifecycle)
8. [Advanced Configuration](#advanced-configuration)
9. [Testing Best Practices](#testing-best-practices)
10. [Common Patterns](#common-patterns)
11. [Error Handling](#error-handling)
12. [Performance & Security](#performance--security)

---

## Understanding AshEvents

AshEvents is an extension for the Ash Framework that provides event capabilities for Ash resources. It allows you to track and persist events when actions (create, update, destroy) are performed on your resources, providing a complete audit trail and enabling powerful replay functionality. 

**🔗 For implementation guidance, see [docs/ai-index.md](docs/ai-index.md)**

## Core Concepts

- **Event Logging**: Automatically records create, update, and destroy actions as events
- **Event Replay**: Rebuilds resource state by replaying events chronologically
- **Version Management**: Supports tracking and routing different versions of events
- **Actor Attribution**: Stores who performed each action (users, system processes, etc)
- **Metadata Tracking**: Attaches arbitrary metadata to events for audit purposes

## Quick Start Setup

### Step 1: Create Event Log Resource (Required)

**Always start by creating a centralized event log resource** using the `AshEvents.EventLog` extension:

```elixir
defmodule MyApp.Events.Event do
  use Ash.Resource,
    extensions: [AshEvents.EventLog]

  event_log do
    # Required: Module that implements clear_records! callback
    clear_records_for_replay MyApp.Events.ClearAllRecords
    
    # Recommended for new projects
    primary_key_type Ash.Type.UUIDv7
    
    # Store actor information
    persist_actor_primary_key :user_id, MyApp.Accounts.User
    persist_actor_primary_key :system_actor, MyApp.SystemActor, attribute_type: :string
  end
end
```

### Step 2: Clear Records Implementation (Required for Replay)

**🚨 CRITICAL**: Always implement the clear records module for event replay functionality:

```elixir
defmodule MyApp.Events.ClearAllRecords do
  use AshEvents.ClearRecordsForReplay

  @impl true
  def clear_records!(opts) do
    # Clear all relevant records for all resources with event tracking
    # This runs before replay to ensure clean state
    :ok
  end
end
```

### Step 3: Enable Event Tracking on Resources

**Add the `AshEvents.Events` extension to resources you want to track**:

```elixir
defmodule MyApp.Accounts.User do
  use Ash.Resource,
    extensions: [AshEvents.Events]

  events do
    # Required: Reference your event log resource
    event_log MyApp.Events.Event
    
    # Optional: Specify action versions for schema evolution
    current_action_versions create: 2, update: 3, destroy: 2
    
    # Optional: Ignore specific actions (usually legacy versions)
    ignore_actions [:old_create_v1]
  end

  # Rest of your resource definition...
end
```

## Event Tracking Patterns

### Automatic Event Creation

**Events are created automatically** when you perform actions on resources with events enabled:

```elixir
# ✅ This automatically creates an event in your event log
user = User
|> Ash.Changeset.for_create(:create, %{name: "John", email: "john@example.com"})
|> Ash.create!(actor: current_user)  # 🚨 CRITICAL: Always set actor!
```

### Adding Metadata to Events

**Use `ash_events_metadata` in the changeset context** to add custom metadata:

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

### Actor Attribution

**🚨 CRITICAL**: Always set the actor when performing actions to ensure proper attribution:

```elixir
# ✅ CORRECT - Actor is properly attributed
User
|> Ash.Changeset.for_create(:create, %{name: "John"})
|> Ash.create!(actor: current_user)

User
|> Ash.Changeset.for_update(:update, %{name: "Jane"})
|> Ash.update!(actor: current_user)

Ash.destroy!(user, actor: current_user)

# ❌ WRONG - No actor attribution (loses audit trail)
User
|> Ash.Changeset.for_create(:create, %{name: "John"})
|> Ash.create!()  # Missing actor!
```

## Event Replay

### Basic Replay

**Use the generated replay action** on your event log resource:

```elixir
# Replay all events to rebuild state
MyApp.Events.Event
|> Ash.ActionInput.for_action(:replay, %{})
|> Ash.run_action!()

# Replay up to a specific event ID
MyApp.Events.Event
|> Ash.ActionInput.for_action(:replay, %{last_event_id: 1000})
|> Ash.run_action!()

# Replay up to a specific point in time
MyApp.Events.Event
|> Ash.ActionInput.for_action(:replay, %{point_in_time: ~U[2023-05-01 00:00:00Z]})
|> Ash.run_action!()
```

### Version Management and Replay Overrides

**Use replay overrides** to handle schema evolution and version changes:

```elixir
defmodule MyApp.Events.Event do
  use Ash.Resource,
    extensions: [AshEvents.EventLog]

  # Handle different event versions
  replay_overrides do
    replay_override MyApp.Accounts.User, :create do
      versions [1]
      route_to MyApp.Accounts.User, :old_create_v1
    end
    
    replay_override MyApp.Accounts.User, :update do
      versions [1, 2]
      route_to MyApp.Accounts.User, :update_legacy
    end
  end
end
```

**Create legacy action implementations** for handling old event versions:

```elixir
defmodule MyApp.Accounts.User do
  # Current actions
  actions do
    create :create do
      # Current implementation
    end
  end
  
  # Legacy actions for replay (mark as ignored)
  actions do
    create :old_create_v1 do
      # Implementation for version 1 events
    end
  end
  
  events do
    event_log MyApp.Events.Event
    ignore_actions [:old_create_v1]  # Don't create new events for legacy actions
  end
end
```

## Side Effects and Lifecycle Hooks

### 🚨 CRITICAL: Lifecycle Hooks During Replay

**Understand that ALL lifecycle hooks are skipped during replay**:
- `before_action`, `after_action`, `around_action`
- `before_transaction`, `after_transaction`, `around_transaction`

**Why this matters**: This prevents side effects like emails, notifications, or API calls from being triggered during replay.

**Key insight**: If you put side effects in lifecycle hooks, they won't execute during replay - this is intentional to prevent duplicate effects.

### ✅ Best Practice: Encapsulate Side Effects

**Create separate Ash actions for side effects** instead of putting them directly in lifecycle hooks:

```elixir
# GOOD - Side effects as separate tracked actions
defmodule MyApp.Accounts.User do
  actions do
    create :create do
      accept [:name, :email]
      
      # Use after_action to trigger other tracked actions
      change after_action(fn changeset, user, context ->
        # This creates a separate event that won't be re-executed during replay
        MyApp.Notifications.EmailNotification
        |> Ash.Changeset.for_create(:send_welcome_email, %{
          user_id: user.id,
          email: user.email
        })
        |> Ash.create!(actor: context.actor)
        
        {:ok, user}
      end)
    end
  end
end

# The email notification resource also tracks events
defmodule MyApp.Notifications.EmailNotification do
  use Ash.Resource,
    extensions: [AshEvents.Events]

  events do
    event_log MyApp.Events.Event
  end

  actions do
    create :send_welcome_email do
      # Email sending logic here
    end
  end
end
```

### External Service Integration

**✅ Best Practice**: Wrap external API calls in tracked actions:

```elixir
defmodule MyApp.External.APICall do
  use Ash.Resource,
    extensions: [AshEvents.Events]

  events do
    event_log MyApp.Events.Event
  end

  actions do
    create :make_api_call do
      accept [:endpoint, :payload, :method]
      
      change after_action(fn changeset, record, context ->
        # Make the actual API call
        response = HTTPClient.request(record.endpoint, record.payload)
        
        # Update with response (creates another event)
        record
        |> Ash.Changeset.for_update(:update_response, %{
          response: response,
          status: "completed"
        })
        |> Ash.update!(actor: context.actor)
        
        {:ok, record}
      end)
    end
    
    update :update_response do
      accept [:response, :status]
    end
  end
end
```

## Advanced Configuration

### Multiple Actor Types

**Configure multiple actor types** when you have different types of entities performing actions:

```elixir
event_log do
  persist_actor_primary_key :user_id, MyApp.Accounts.User
  persist_actor_primary_key :system_actor, MyApp.SystemActor, attribute_type: :string
  persist_actor_primary_key :api_client_id, MyApp.APIClient
end
```

**📝 Note**: All actor primary key fields must have `allow_nil?: true` (this is the default).

### Encryption Support

**🔐 Use encryption for sensitive event data**:

```elixir
event_log do
  cloak_vault MyApp.Vault  # Encrypts both data and metadata
end
```

### Advisory Locks

**⚡ Configure advisory locks** for high-concurrency scenarios:

```elixir
event_log do
  advisory_lock_key_default 31337
  advisory_lock_key_generator MyApp.CustomAdvisoryLockKeyGenerator
end
```

### Timestamp Tracking

**⏰ Configure timestamp tracking** if your resources have custom timestamp fields:

```elixir
events do
  event_log MyApp.Events.Event
  create_timestamp :inserted_at
  update_timestamp :updated_at
end
```

## Testing Best Practices

### Testing with Events

**🧪 Use `authorize?: false` in tests** where authorization is not the focus:

```elixir
test "creates user with event" do
  user = User
  |> Ash.Changeset.for_create(:create, %{name: "Test"})
  |> Ash.create!(authorize?: false)
  
  # Verify event was created
  events = MyApp.Events.Event |> Ash.read!(authorize?: false)
  assert length(events) == 1
end
```

**🧪 Test event replay functionality**:

```elixir
test "can replay events to rebuild state" do
  # Create some data
  user = create_user()
  update_user(user)
  
  # Clear state
  clear_all_records()
  
  # Replay events
  MyApp.Events.Event
  |> Ash.ActionInput.for_action(:replay, %{})
  |> Ash.run_action!(authorize?: false)
  
  # Verify state is restored
  restored_user = get_user(user.id)
  assert restored_user.name == user.name
end
```

## Error Handling and Debugging

### Event Creation Failures

**⚠️ Events are created in the same transaction** as the original action, so event creation failures will rollback the entire operation.

### Replay Failures

**🛠️ Handle replay failures gracefully**:

```elixir
case MyApp.Events.Event |> Ash.ActionInput.for_action(:replay, %{}) |> Ash.run_action() do
  {:ok, _} -> 
    Logger.info("Event replay completed successfully")
  {:error, error} -> 
    Logger.error("Event replay failed: #{inspect(error)}")
    # Handle cleanup or notification
end
```

## Audit Logging Only

**💡 You can use AshEvents solely for audit logging** without implementing replay:

1. **Skip implementing `clear_records_for_replay`** - only needed for replay
2. **Skip defining `current_action_versions`** - only needed for schema evolution during replay  
3. **Skip implementing replay overrides** - only needed for replay functionality

**Benefit**: This gives you automatic audit trails without the complexity of event sourcing.

## Common Patterns

### Event Metadata for Audit Trails

```elixir
# Always include relevant context in metadata
context: %{ash_events_metadata: %{
  source: "web_ui",           # Where the action originated
  user_agent: request.headers["user-agent"],
  ip_address: get_client_ip(request),
  request_id: get_request_id(),
  correlation_id: get_correlation_id()
}}
```

### Conditional Event Creation

```elixir
events do
  event_log MyApp.Events.Event
  # Only track specific actions
  only_actions [:create, :update, :destroy]
  # Or ignore specific actions
  ignore_actions [:internal_update, :system_sync]
end
```

### Resource-Specific Event Handling

```elixir
# Different resources can have different event configurations
defmodule MyApp.Accounts.User do
  events do
    event_log MyApp.Events.Event
    current_action_versions create: 2, update: 1
  end
end

defmodule MyApp.Blog.Post do
  events do
    event_log MyApp.Events.Event
    current_action_versions create: 1, update: 3, destroy: 1
  end
end
```

## Performance & Security

### Performance Considerations

- **⚡ Event insertion uses advisory locks** to prevent race conditions
- **⏳ Replay operations are sequential** and can be time-consuming for large datasets
- **🗄️ Consider event retention policies** for long-running applications
- **🚀 Use `primary_key_type Ash.Type.UUIDv7`** for better performance with time-ordered events
- **📊 Metadata should be kept reasonable in size** as it's stored as JSON

### Security Considerations

- **🔐 Never store sensitive data in metadata** unless using encryption
- **🛡️ Always validate actor permissions** before performing actions
- **🔒 Use encryption** when storing PII or sensitive information in events
- **🚧 Implement proper access controls** on your event log resource
- **📋 Consider data retention requirements** for compliance (GDPR, etc.)

---

## Quick Reference

### Essential Commands
```bash
# Database management
mix test.reset         # Reset test database (preferred)
mix test.create        # Create test database
mix test.migrate       # Run migrations

# Testing
mix test              # Run all tests
mix test --trace      # Run with detailed output

# Quality
mix credo --strict    # Linting
mix dialyzer         # Type checking
mix format           # Code formatting
```

### Must-Have Checklist
- [ ] Event log resource with `AshEvents.EventLog` extension
- [ ] Clear records module with `AshEvents.ClearRecordsForReplay`
- [ ] Resources with `AshEvents.Events` extension
- [ ] Actor attribution on ALL actions
- [ ] Side effects as separate tracked actions
- [ ] Event replay testing

### Emergency Debugging
1. **Events not created?** → Check actor attribution
2. **Replay fails?** → Check clear records implementation
3. **Compilation errors?** → Check clear_records_for_replay configuration
4. **Performance issues?** → Check advisory locks and metadata size

---

**🔗 For more guidance, see [docs/ai-index.md](docs/ai-index.md)**