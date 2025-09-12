# Rules for working with AshEvents

## Understanding AshEvents

AshEvents is an extension for the Ash Framework that provides event capabilities for Ash resources. It allows you to track and persist events when actions (create, update, destroy) are performed on your resources, providing a complete audit trail and enabling powerful replay functionality. **Read the documentation thoroughly before implementing** - AshEvents has specific patterns and conventions that must be followed correctly.

## Core Concepts

- **Event Logging**: Automatically records create, update, and destroy actions as events
- **Event Replay**: Rebuilds resource state by replaying events chronologically
- **Version Management**: Supports tracking and routing different versions of events
- **Actor Attribution**: Stores who performed each action (users, system processes, etc)
- **Changed Attributes Tracking**: Automatically captures attributes modified by business logic that weren't in the original input
- **Metadata Tracking**: Attaches arbitrary metadata to events for audit purposes

## Project Structure & Setup

### 1. Event Log Resource (Required)

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

### 2. Clear Records Implementation (Required for Replay)

**Always implement the clear records module** if you plan to use event replay:

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

### 3. Enable Event Tracking on Resources

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

    # Optional: Configure replay strategies for changed attributes
    replay_non_input_attribute_changes [
      create: :force_change,    # Default strategy
      update: :as_arguments,    # Alternative strategy
      legacy_action: :force_change
    ]

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
# This automatically creates an event in your event log
user = User
|> Ash.Changeset.for_create(:create, %{name: "John", email: "john@example.com"})
|> Ash.create!(actor: current_user)
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

**Always set the actor** when performing actions to ensure proper attribution:

```elixir
# GOOD - Actor is properly attributed
User
|> Ash.Query.for_read(:read, %{}, actor: current_user)
|> Ash.read!()

# BAD - No actor attribution
User
|> Ash.Query.for_read(:read, %{})
|> Ash.read!()
```

### Changed Attributes Tracking

**AshEvents automatically captures attributes that are modified during action execution** but weren't part of the original input. This is essential for complete state reconstruction during replay when business logic, defaults, or extensions modify data beyond the explicit input parameters.

#### Understanding Changed Attributes

**What gets captured:**
- Default values applied to attributes
- Auto-generated values (UUIDs, slugs, computed fields)
- Attributes modified by Ash changes or extensions
- Business rule transformations of input data
- Calculated or derived attributes

**What doesn't get captured:**
- Attributes that were explicitly provided in the original input
- Attributes that remain unchanged from their current value

#### Event Data Structure

When an event is created, data is separated into two categories:

```elixir
# Example event structure
%Event{
  # Original input parameters only
  data: %{
    "name" => "John Doe",
    "email" => "john@example.com"
  },

  # Auto-generated or modified attributes
  changed_attributes: %{
    "id" => "550e8400-e29b-41d4-a716-446655440000",
    "status" => "active",           # default value
    "slug" => "john-doe",           # auto-generated from name
    "created_at" => "2023-05-01T12:00:00Z"
  }
}
```

#### Replay Strategies

Configure how changed attributes are applied during replay using `replay_non_input_attribute_changes`:

```elixir
events do
  event_log MyApp.Events.Event

  replay_non_input_attribute_changes [
    create: :force_change,      # Uses Ash.Changeset.force_change_attributes
    update: :force_change,
    legacy_create_v1: :as_arguments # Merges into action input
  ]
end
```

**`:force_change` Strategy (Default):**
- Uses `Ash.Changeset.force_change_attributes()` to apply changed attributes directly
- Bypasses validations and business logic for the changed attributes
- Best for attributes that shouldn't be recomputed during replay (IDs, timestamps)
- Ensures exact state reproduction

**`:as_arguments` Strategy:**
- Merges changed attributes into the action input parameters
- Allows business logic and validations to run normally
- Best for legacy events or when you want recomputation during replay
- May produce slightly different results if business logic has changed

#### Practical Example

```elixir
defmodule MyApp.Accounts.User do
  use Ash.Resource,
    extensions: [AshEvents.Events]

  events do
    event_log MyApp.Events.Event
    replay_non_input_attribute_changes [
      create: :force_change,
      update: :force_change
    ]
  end

  attributes do
    uuid_primary_key :id, writable?: true
    attribute :name, :string, public?: true, allow_nil?: false
    attribute :email, :string, public?: true, allow_nil?: false
    attribute :status, :string, default: "active", public?: true
    attribute :slug, :string, public?: true
    create_timestamp :created_at
  end

  changes do
    # Auto-generate slug from name
    change fn changeset, _context ->
      case Map.get(changeset.attributes, :name) do
        nil -> changeset
        name ->
          slug = String.downcase(name)
                |> String.replace(~r/[^a-z0-9]/, "-")
          Ash.Changeset.change_attribute(changeset, :slug, slug)
      end
    end, on: [:create, :update]
  end
end

# Creating a user
user = User
|> Ash.Changeset.for_create(:create, %{
  name: "Jane Smith",
  email: "jane@example.com"
})
|> Ash.create!(actor: current_user)

# The resulting event will have:
# data: %{"name" => "Jane Smith", "email" => "jane@example.com"}
# changed_attributes: %{
#   "id" => "generated-uuid",
#   "status" => "active",
#   "slug" => "jane-smith",
#   "created_at" => timestamp
# }
```

#### Best Practices

**Use `:force_change` strategy when:**
- Attributes should maintain their exact original values (IDs, timestamps)
- You want guaranteed state reproduction during replay
- Business logic for generating attributes shouldn't be re-executed

**Use `:as_arguments` strategy when:**
- You have legacy events that need recomputation
- Business logic has evolved and you want updated calculations
- You prefer letting validations run during replay

**Common Patterns:**
```elixir
# Mixed strategies for different actions
replay_non_input_attribute_changes [
  create: :force_change,          # Preserve exact creation state
  update: :as_arguments,          # Allow recomputation on updates
  legacy_import: :as_arguments    # Recompute legacy data
]
```

#### Working with Forms

**AshPhoenix.Form automatically works** with changed attributes tracking:

```elixir
# Form with string keys
form_params = %{
  "name" => "John Doe",
  "email" => "john@example.com"
  # status and slug will be auto-generated
}

form = User
|> AshPhoenix.Form.for_create(:create, actor: current_user)
|> AshPhoenix.Form.validate(form_params)

{:ok, user} = AshPhoenix.Form.submit(form, params: form_params)

# Event will properly separate form input from generated attributes
# regardless of whether form used string or atom keys
```

#### Troubleshooting

**Common Issues:**

1. **Missing attributes after replay:**
   - Ensure `clear_records_for_replay` includes all relevant tables
   - Check that replay strategy is appropriate for your use case

2. **Different values after replay:**
   - Using `:as_arguments` may cause recomputation with updated logic
   - Switch to `:force_change` for exact reproduction

3. **Attributes appearing in both data and changed_attributes:**
   - This shouldn't happen - file a bug if you see this
   - Attributes are only in `changed_attributes` if not in original input

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

### Important: Lifecycle Hooks During Replay

**Understand that ALL lifecycle hooks are skipped during replay**:
- `before_action`, `after_action`, `around_action`
- `before_transaction`, `after_transaction`, `around_transaction`

This prevents side effects like emails, notifications, or API calls from being triggered during replay.

### Best Practice: Encapsulate Side Effects

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

**Wrap external API calls in tracked actions**:

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

**Note**: All actor primary key fields must have `allow_nil?: true` (this is the default).

### Encryption Support

**Use encryption for sensitive event data**:

```elixir
event_log do
  cloak_vault MyApp.Vault  # Encrypts both data and metadata
end
```

### Advisory Locks

**Configure advisory locks** for high-concurrency scenarios:

```elixir
event_log do
  advisory_lock_key_default 31337
  advisory_lock_key_generator MyApp.CustomAdvisoryLockKeyGenerator
end
```

### Public Field Configuration

**Control visibility of event log fields** for GraphQL, JSON API, or other public interfaces:

```elixir
event_log do
  # Make all AshEvents fields public
  public_fields :all
  
  # Or specify only certain fields
  public_fields [:id, :resource, :action, :occurred_at]
  
  # Default: all fields are private
  public_fields []
end
```

**Valid field names** include all canonical AshEvents fields:
- `:id`, `:record_id`, `:version`, `:occurred_at`
- `:resource`, `:action`, `:action_type`
- `:metadata`, `:data`, `:changed_attributes`
- `:encrypted_metadata`, `:encrypted_data`, `:encrypted_changed_attributes` (when using encryption)
- Actor attribution fields from `persist_actor_primary_key` (e.g., `:user_id`, `:system_actor`)

**Important**: Only AshEvents-managed fields can be made public. User-added custom fields are not affected by this configuration.

### Timestamp Tracking

**Configure timestamp tracking** if your resources have custom timestamp fields:

```elixir
events do
  event_log MyApp.Events.Event
  create_timestamp :inserted_at
  update_timestamp :updated_at
end
```

## Testing Best Practices

### Testing with Events

**Use `authorize?: false` in tests** where authorization is not the focus:

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

**Test event replay functionality**:

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

**Events are created in the same transaction** as the original action, so event creation failures will rollback the entire operation.

### Replay Failures

**Handle replay failures gracefully**:

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

**You can use AshEvents solely for audit logging** without implementing replay:

1. **Skip implementing `clear_records_for_replay`** - only needed for replay
2. **Skip defining `current_action_versions`** - only needed for schema evolution during replay
3. **Skip implementing replay overrides** - only needed for replay functionality

This gives you automatic audit trails without the complexity of event sourcing.

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

### Changed Attributes Configuration Patterns

```elixir
# Pattern 1: Default configuration (recommended for most cases)
defmodule MyApp.Accounts.User do
  events do
    event_log MyApp.Events.Event
    # Uses :force_change for all actions by default
    # No explicit configuration needed
  end
end

# Pattern 2: Mixed strategies based on action type
defmodule MyApp.Blog.Post do
  events do
    event_log MyApp.Events.Event
    replay_non_input_attribute_changes [
      create: :force_change,      # Preserve exact creation state
      update: :as_arguments,      # Allow recomputation on updates
      publish: :force_change,     # Preserve published state exactly
      archive: :force_change      # Preserve archive timestamps
    ]
  end
end

# Pattern 3: Legacy compatibility with gradual migration
defmodule MyApp.Legacy.Document do
  events do
    event_log MyApp.Events.Event
    replay_non_input_attribute_changes [
      create: :force_change,        # New events use force_change
      legacy_create_v1: :as_arguments,  # Legacy events recompute
      legacy_create_v2: :as_arguments   # Multiple legacy versions
    ]
  end
end
```

### Common Auto-Generated Attribute Patterns

```elixir
# Pattern 1: Status + Slug generation
defmodule MyApp.Content.Article do
  attributes do
    attribute :title, :string, public?: true
    attribute :content, :string, public?: true
    attribute :status, :string, default: "draft", public?: true
    attribute :slug, :string, public?: true
    attribute :word_count, :integer, public?: true
  end

  changes do
    # Auto-generate slug and word count
    change fn changeset, _context ->
      changeset
      |> auto_generate_slug()
      |> calculate_word_count()
    end, on: [:create, :update]
  end

  events do
    event_log MyApp.Events.Event
    # status, slug, word_count will be tracked as changed_attributes
  end
end
```

## Performance Considerations

- **Event insertion uses advisory locks** to prevent race conditions
- **Replay operations are sequential** and can be time-consuming for large datasets
- **Use `primary_key_type Ash.Type.UUIDv7`** for better performance with time-ordered events
- **Metadata should be kept reasonable in size** as it's stored as JSON
