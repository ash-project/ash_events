# AshEvents AI Assistant Implementation Guide

## Overview

This guide provides comprehensive implementation workflows for AshEvents development tasks, designed specifically for AI assistant efficiency and accuracy.

## Core Implementation Patterns

### Event Log Resource Implementation

#### Prerequisites
- [ ] Read [usage-rules.md](../usage-rules.md) sections 1-2
- [ ] Understand AshEvents.EventLog extension
- [ ] Review [test/support/events/event_log.ex](../test/support/events/event_log.ex)

#### Implementation Steps
1. **Create Event Log Resource**: 
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

2. **Create Clear Records Module**: 
   ```elixir
   defmodule MyApp.Events.ClearAllRecords do
     use AshEvents.ClearRecordsForReplay

     @impl true
     def clear_records!(opts) do
       # Clear all resources with event tracking
       MyApp.User |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)
       MyApp.Org |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)
       :ok
     end
   end
   ```

3. **Test Implementation**: `mix test test/support/events/`

#### Validation
- [ ] Event log resource compiles without errors
- [ ] Clear records module implements required callback
- [ ] Actor attribution is properly configured
- [ ] Primary key type is set to UUIDv7 for performance

#### Common Pitfalls
- ❌ **Missing Clear Records**: Not implementing clear_records_for_replay breaks replay
- ❌ **Wrong Primary Key Type**: Using default :id instead of Ash.Type.UUIDv7
- ✅ **Correct Pattern**: Always implement clear_records_for_replay with comprehensive resource clearing

### Events Extension Implementation

#### Prerequisites
- [ ] Read [usage-rules.md](../usage-rules.md) section 3
- [ ] Understand Events extension configuration
- [ ] Review [test/support/accounts/user.ex](../test/support/accounts/user.ex)

#### Implementation Steps
1. **Add Events Extension**:
   ```elixir
   defmodule MyApp.User do
     use Ash.Resource,
       extensions: [AshEvents.Events]

     events do
       event_log MyApp.Events.Event
       current_action_versions create: 1, update: 1
     end
   end
   ```

2. **Configure Actor Attribution**: Always set actor when performing actions
   ```elixir
   user = User
   |> Ash.Changeset.for_create(:create, %{name: "John"})
   |> Ash.create!(actor: current_user)
   ```

3. **Test Event Creation**: Verify events are created with proper attribution

#### Validation
- [ ] Resource compiles with Events extension
- [ ] Event log is properly referenced
- [ ] Actor attribution works correctly
- [ ] Events are created when actions are performed

#### Common Pitfalls
- ❌ **Missing Event Log Reference**: Not configuring event_log in events block
- ❌ **No Actor Attribution**: Forgetting to set actor when performing actions
- ✅ **Correct Pattern**: Always reference event log and set actor attribution

### Event Replay Implementation

#### Prerequisites
- [ ] Read [usage-rules.md](../usage-rules.md) section 5
- [ ] Understand replay mechanics and limitations
- [ ] Review [test/support/events/clear_records.ex](../test/support/events/clear_records.ex)

#### Implementation Steps
1. **Implement Comprehensive Clear Records**:
   ```elixir
   defmodule MyApp.Events.ClearAllRecords do
     use AshEvents.ClearRecordsForReplay

     @impl true
     def clear_records!(opts) do
       # Clear all resources with event tracking in dependency order
       MyApp.UserRole |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)
       MyApp.User |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)
       MyApp.Org |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)
       :ok
     end
   end
   ```

2. **Configure Replay Action**: Use built-in replay action
   ```elixir
   MyApp.Events.Event
   |> Ash.ActionInput.for_action(:replay, %{})
   |> Ash.run_action!()
   ```

3. **Test Replay Functionality**: Verify state restoration works correctly

#### Validation
- [ ] Clear records implementation is comprehensive
- [ ] Replay action executes without errors
- [ ] State is properly restored after replay
- [ ] No duplicate data or side effects

#### Common Pitfalls
- ❌ **Incomplete Clear Records**: Missing resources causes replay failures
- ❌ **Dependency Order**: Not clearing resources in correct dependency order
- ✅ **Correct Pattern**: Clear all tracked resources in proper dependency order

### Version Management Implementation

#### Prerequisites
- [ ] Read [usage-rules.md](../usage-rules.md) "Version Management and Replay Overrides"
- [ ] Understand schema evolution requirements
- [ ] Review version management examples

#### Implementation Steps
1. **Update Action Versions**:
   ```elixir
   events do
     event_log MyApp.Events.Event
     current_action_versions create: 2, update: 1  # Increment version
   end
   ```

2. **Configure Replay Overrides**:
   ```elixir
   # In Event Log Resource
   replay_overrides do
     replay_override MyApp.User, :create do
       versions [1]
       route_to MyApp.User, :old_create_v1
     end
   end
   ```

3. **Create Legacy Actions**:
   ```elixir
   actions do
     create :old_create_v1 do
       # Implementation for version 1 events
       accept [:name]  # Old schema
     end
   end
   
   events do
     event_log MyApp.Events.Event
     ignore_actions [:old_create_v1]  # Don't create new events
   end
   ```

4. **Test Version Routing**: Verify events route to correct actions

#### Validation
- [ ] Action versions are properly incremented
- [ ] Replay overrides are configured correctly
- [ ] Legacy actions handle old event schemas
- [ ] Version routing works during replay

#### Common Pitfalls
- ❌ **Missing Legacy Actions**: Not implementing old action versions
- ❌ **Incorrect Version Routing**: Events not routing to correct actions
- ✅ **Correct Pattern**: Implement legacy actions and configure proper routing

### Actor Attribution Implementation

#### Prerequisites
- [ ] Read [usage-rules.md](../usage-rules.md) "Actor Attribution"
- [ ] Understand actor configuration requirements
- [ ] Review actor attribution examples

#### Implementation Steps
1. **Configure Actor Types in Event Log**:
   ```elixir
   event_log do
     clear_records_for_replay MyApp.Events.ClearAllRecords
     persist_actor_primary_key :user_id, MyApp.User
     persist_actor_primary_key :system_actor, MyApp.SystemActor, attribute_type: :string
   end
   ```

2. **Set Actor in All Actions**:
   ```elixir
   # User actions
   user = User
   |> Ash.Changeset.for_create(:create, %{name: "John"})
   |> Ash.create!(actor: current_user)
   
   # System actions
   user = User
   |> Ash.Changeset.for_update(:system_update, %{status: "active"})
   |> Ash.update!(actor: %{id: "system", type: "automated"})
   ```

3. **Test Actor Attribution**: Verify events contain proper actor information

#### Validation
- [ ] Actor types are configured in event log
- [ ] All actions set appropriate actor
- [ ] Events contain actor attribution
- [ ] Actor information is preserved during replay

#### Common Pitfalls
- ❌ **Missing Actor Attribution**: Not setting actor on actions
- ❌ **Incorrect Actor Types**: Using wrong actor type for action
- ✅ **Correct Pattern**: Always set appropriate actor for all actions

### Metadata Handling Implementation

#### Prerequisites
- [ ] Read [usage-rules.md](../usage-rules.md) metadata examples
- [ ] Understand metadata structure and limitations
- [ ] Review metadata handling patterns

#### Implementation Steps
1. **Add Metadata to Actions**:
   ```elixir
   User
   |> Ash.Changeset.for_create(:create, %{name: "Jane"}, [
     actor: current_user,
     context: %{ash_events_metadata: %{
       source: "api",
       request_id: request_id,
       ip_address: client_ip,
       user_agent: user_agent
     }}
   ])
   |> Ash.create!()
   ```

2. **Structure Metadata Consistently**:
   ```elixir
   # Standard metadata structure
   metadata = %{
     source: "web_ui",           # Where action originated
     request_id: get_request_id(),
     correlation_id: get_correlation_id(),
     additional_context: %{
       feature_flag: "new_feature_enabled",
       experiment_id: "exp_123"
     }
   }
   ```

3. **Test Metadata Storage**: Verify metadata is properly stored and retrieved

#### Validation
- [ ] Metadata is included in action context
- [ ] Metadata structure is consistent
- [ ] Metadata is stored in events
- [ ] Metadata is accessible during replay

#### Common Pitfalls
- ❌ **Large Metadata**: Storing too much data in metadata
- ❌ **Inconsistent Structure**: Different metadata formats across actions
- ✅ **Correct Pattern**: Keep metadata concise and use consistent structure

### Side Effects Implementation

#### Prerequisites
- [ ] Read [usage-rules.md](../usage-rules.md) "Side Effects and Lifecycle Hooks"
- [ ] Understand lifecycle hook behavior during replay
- [ ] Review side effect handling examples

#### Implementation Steps
1. **Create Side Effect Resources**:
   ```elixir
   defmodule MyApp.Notifications.Email do
     use Ash.Resource,
       extensions: [AshEvents.Events]

     events do
       event_log MyApp.Events.Event
     end

     actions do
       create :send_welcome_email do
         accept [:user_id, :email, :template]
         
         change after_action(fn changeset, record, context ->
           # Actual email sending logic
           result = MyApp.EmailService.send_email(record.email, record.template)
           
           # Update status (creates another event)
           if result == :ok do
             record
             |> Ash.Changeset.for_update(:update_status, %{status: "sent"})
             |> Ash.update!(actor: context.actor)
           end
           
           {:ok, record}
         end)
       end
     end
   end
   ```

2. **Trigger Side Effects in Lifecycle Hooks**:
   ```elixir
   defmodule MyApp.User do
     actions do
       create :create do
         accept [:name, :email]
         
         change after_action(fn changeset, user, context ->
           # Trigger side effect as separate action
           MyApp.Notifications.Email
           |> Ash.Changeset.for_create(:send_welcome_email, %{
             user_id: user.id,
             email: user.email,
             template: "welcome"
           })
           |> Ash.create!(actor: context.actor)
           
           {:ok, user}
         end)
       end
     end
   end
   ```

3. **Test Side Effect Handling**: Verify side effects work correctly and don't duplicate during replay

#### Validation
- [ ] Side effects are implemented as separate actions
- [ ] Side effect resources track events
- [ ] Side effects are triggered by lifecycle hooks
- [ ] Side effects don't duplicate during replay

#### Common Pitfalls
- ❌ **Direct Side Effects**: Performing side effects directly in lifecycle hooks
- ❌ **Untracked Side Effects**: Side effects not implemented as tracked actions
- ✅ **Correct Pattern**: Implement side effects as separate tracked actions

## Architecture Patterns

### Event Log Resource Pattern

**When to Use**: Always required for any AshEvents implementation
**Structure**: Central resource using AshEvents.EventLog extension
**Implementation**: 

```elixir
defmodule MyApp.Events.Event do
  use Ash.Resource,
    extensions: [AshEvents.EventLog]

  event_log do
    clear_records_for_replay MyApp.Events.ClearAllRecords
    primary_key_type Ash.Type.UUIDv7
    persist_actor_primary_key :user_id, MyApp.User
    persist_actor_primary_key :system_actor, MyApp.SystemActor, attribute_type: :string
  end
end
```

### Events Extension Pattern

**When to Use**: For any resource that needs event tracking
**Structure**: Extension added to existing resources
**Implementation**:

```elixir
defmodule MyApp.User do
  use Ash.Resource,
    extensions: [AshEvents.Events]

  events do
    event_log MyApp.Events.Event
    current_action_versions create: 1, update: 1
  end
end
```

### Clear Records Pattern

**When to Use**: Required for event replay functionality
**Structure**: Module implementing AshEvents.ClearRecordsForReplay
**Implementation**:

```elixir
defmodule MyApp.Events.ClearAllRecords do
  use AshEvents.ClearRecordsForReplay

  @impl true
  def clear_records!(opts) do
    # Clear in dependency order
    MyApp.UserRole |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)
    MyApp.User |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)
    MyApp.Org |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)
    :ok
  end
end
```

## Testing Patterns

### Event Creation Testing

**Purpose**: Verify events are created when actions are performed
**Structure**: Test that creates resource and checks event creation
**Example**: 

```elixir
test "creates event when user is created" do
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
```

### Event Replay Testing

**Purpose**: Verify event replay restores state correctly
**Structure**: Create data, clear state, replay events, verify restoration
**Example**: 

```elixir
test "can replay events to rebuild state" do
  # Create initial data
  user = User
  |> Ash.Changeset.for_create(:create, %{name: "Test"})
  |> Ash.create!(authorize?: false)
  
  # Store expected state
  expected_name = user.name
  
  # Clear state
  MyApp.Events.ClearAllRecords.clear_records!([])
  
  # Replay events
  MyApp.Events.Event
  |> Ash.ActionInput.for_action(:replay, %{})
  |> Ash.run_action!(authorize?: false)
  
  # Verify state is restored
  restored_user = User |> Ash.get!(user.id, authorize?: false)
  assert restored_user.name == expected_name
end
```

### Actor Attribution Testing

**Purpose**: Verify events contain proper actor information
**Structure**: Test that creates events with actor and checks attribution
**Example**: 

```elixir
test "events contain proper actor attribution" do
  actor = %{id: 1, name: "Test Actor"}
  
  user = User
  |> Ash.Changeset.for_create(:create, %{name: "Test"})
  |> Ash.create!(actor: actor, authorize?: false)
  
  events = MyApp.Events.Event |> Ash.read!(authorize?: false)
  event = hd(events)
  
  assert event.user_id == actor.id
end
```

## Advanced Workflows

### Schema Evolution Workflow

1. **Plan Schema Changes**: Identify what needs to change in action schemas
2. **Increment Version Numbers**: Update current_action_versions
3. **Create Legacy Actions**: Implement old action versions for replay
4. **Configure Replay Overrides**: Route old events to legacy actions
5. **Test Version Routing**: Verify events route correctly during replay

### Multi-Tenant Event Handling

1. **Configure Tenant-Aware Resources**: Set up multitenancy on event-tracked resources
2. **Tenant-Specific Event Logs**: Consider separate event logs per tenant
3. **Tenant-Aware Clear Records**: Implement tenant-specific clearing
4. **Test Tenant Isolation**: Verify events don't leak between tenants

### High-Volume Event Handling

1. **Optimize Event Storage**: Use UUIDv7 primary keys for time-ordered events
2. **Implement Event Partitioning**: Consider database partitioning for large volumes
3. **Batch Event Processing**: Use bulk operations for efficiency
4. **Monitor Performance**: Track event creation and replay performance

## File Location Reference

### Core Implementation Files
- **Event Log Extension**: `lib/event_log/event_log.ex` - Core event log functionality
- **Events Extension**: `lib/events/events.ex` - Resource event tracking
- **Action Wrappers**: `lib/events/*_action_wrapper.ex` - Action interception
- **Replay Logic**: `lib/event_log/replay.ex` - Event replay implementation

### Test Files
- **Event Log Test**: `test/support/events/event_log.ex` - Example event log resource
- **Clear Records Test**: `test/support/events/clear_records.ex` - Clear records implementation
- **User Resource Test**: `test/support/accounts/user.ex` - Example resource with events
- **Main Test**: `test/ash_events_test.exs` - Core functionality tests

### Configuration Files
- **Mix Project**: `mix.exs` - Project configuration and dependencies
- **Test Config**: `config/test.exs` - Test environment configuration
- **App Config**: `config/config.exs` - Application configuration

## Performance Considerations

### Event Storage Optimization
- **Primary Key Type**: Use `Ash.Type.UUIDv7` for time-ordered events
- **Database Indexing**: Index frequently queried event fields
- **Event Retention**: Consider archiving old events to manage storage

### Replay Performance
- **Batch Processing**: Process events in batches during replay
- **Dependency Ordering**: Clear resources in correct dependency order
- **Parallel Processing**: Consider parallel replay for independent resources

### Metadata Management
- **Size Limits**: Keep metadata reasonably sized for JSON storage
- **Structured Data**: Use consistent metadata structure across events
- **Indexing**: Index metadata fields that are frequently queried

## Security Considerations

### Data Protection
- **Sensitive Data**: Never store sensitive data in metadata without encryption
- **Actor Validation**: Always validate actor permissions before creating events
- **Access Control**: Implement proper access controls on event log resources

### Audit Trail Integrity
- **Event Immutability**: Ensure events cannot be modified after creation
- **Actor Attribution**: Always set actor attribution for accountability
- **Metadata Validation**: Validate metadata content for security

### Compliance Requirements
- **Data Retention**: Implement data retention policies for compliance
- **Data Deletion**: Consider GDPR right-to-be-forgotten requirements
- **Audit Logging**: Ensure complete audit trail for compliance needs