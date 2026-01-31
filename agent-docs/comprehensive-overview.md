# AshEvents Comprehensive Overview

This document provides a complete overview of AshEvents functionality, explaining how different features work together to support various practical scenarios.

## Table of Contents

1. [Core Philosophy](#core-philosophy)
2. [Two Extensions: EventLog & Events](#two-extensions-eventlog--events)
3. [Event Creation Flow](#event-creation-flow)
4. [Event Replay System](#event-replay-system)
5. [Changed Attributes Tracking](#changed-attributes-tracking)
6. [Replay Strategies](#replay-strategies)
7. [Replay Overrides & Rerouting](#replay-overrides--rerouting)
8. [Record ID Handling Modes](#record-id-handling-modes)
9. [Actor Attribution](#actor-attribution)
10. [Encryption Support](#encryption-support)
11. [Version Management](#version-management)
12. [Upsert Action Support](#upsert-action-support)
13. [Advisory Locks](#advisory-locks)
14. [Practical Scenarios](#practical-scenarios)

---

## Core Philosophy

AshEvents implements **event sourcing** for Ash resources with these guiding principles:

1. **Events are facts**: Each event captures what happened (the action input) at a specific moment
2. **Input over outcome**: Events primarily store the original input data, not the computed end state
3. **Deterministic replay**: Given the same events and action logic, replay produces the same state
4. **Changed attributes as reconciliation**: Non-deterministic or computed values are captured separately for replay

### What Gets Stored

| Field | Content | Purpose |
|-------|---------|---------|
| `data` | Original action input (params + arguments) | The "intent" - what was requested |
| `changed_attributes` | Values set by business logic beyond input | Reconciliation for computed values |
| `metadata` | Custom context (via `ash_events_metadata`) | Audit trail context |
| `record_id` | Primary key of affected resource | Identity tracking |
| `occurred_at` | When the event happened | Temporal ordering |
| `version` | Action schema version | Schema evolution support |

---

## Two Extensions: EventLog & Events

### EventLog Extension

Applied to the **event storage resource**. Configures:

```elixir
defmodule MyApp.Events.EventLog do
  use Ash.Resource,
    extensions: [AshEvents.EventLog]

  event_log do
    # Required: How to clear records before replay
    clear_records_for_replay MyApp.Events.ClearAllRecords

    # Primary key type for events (default: :integer)
    primary_key_type Ash.Type.UUIDv7

    # Type of IDs your resources use (default: :uuid)
    record_id_type :uuid

    # Actor tracking
    persist_actor_primary_key :user_id, MyApp.Accounts.User
    persist_actor_primary_key :system_actor, MyApp.SystemActor, attribute_type: :string

    # Encryption (optional)
    cloak_vault MyApp.Vault

    # API exposure
    public_fields [:id, :resource, :action, :occurred_at]
  end

  # Schema evolution support
  replay_overrides do
    replay_override MyApp.User, :create do
      versions [1]
      route_to MyApp.User, :create_v1
    end
  end
end
```

### Events Extension

Applied to **each resource you want to track**. Configures:

```elixir
defmodule MyApp.User do
  use Ash.Resource,
    extensions: [AshEvents.Events]

  events do
    # Required: Where to store events
    event_log MyApp.Events.EventLog

    # Action filtering (mutually exclusive)
    only_actions [:create, :update, :destroy]
    # OR
    ignore_actions [:soft_delete]

    # Version management
    current_action_versions create: 2, update: 1

    # Timestamp tracking
    create_timestamp :inserted_at
    update_timestamp :updated_at

    # Replay behavior
    replay_non_input_attribute_changes [
      create: :force_change,
      update: :as_arguments
    ]

    # Sensitive data handling
    store_sensitive_attributes [:hashed_password]

    # Change module control during replay
    allowed_change_modules [
      create: [MyApp.Changes.SetDefaults]
    ]
  end
end
```

---

## Event Creation Flow

When an action executes on a tracked resource:

```
User calls action (e.g., Ash.create!(User, input, actor: user))
                    │
                    ▼
┌─────────────────────────────────────────────┐
│  StoreChangesetParams                        │
│  • Captures original params to context       │
│  • Runs FIRST before any changes             │
└─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────┐
│  User-defined Changes (wrapped)              │
│  • Each wrapped with ReplayChangeWrapper     │
│  • During replay: skipped unless allowed     │
└─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────┐
│  ApplyChangedAttributes                      │
│  • During normal: no-op                      │
│  • During replay: applies changed_attributes │
└─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────┐
│  Action Wrapper (CreateActionWrapper, etc.)  │
│  1. Acquire advisory lock                    │
│  2. Execute data layer action                │
│  3. Build event:                             │
│     • data = original params                 │
│     • changed_attributes = computed values   │
│     • Extract actor primary key              │
│     • Filter sensitive attributes            │
│  4. Create event record                      │
│  5. Release lock on transaction end          │
└─────────────────────────────────────────────┘
                    │
                    ▼
           Return result to user
```

---

## Event Replay System

Replay reconstructs resource state from events:

```
Ash.run_action!(EventLog, :replay)
              │
              ▼
┌─────────────────────────────────────────────┐
│  Clear all records                           │
│  • Calls clear_records_for_replay module     │
│  • Must clear in dependency order            │
└─────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────┐
│  Query events (chronologically by ID)        │
│  • Optionally up to point_in_time           │
│  • Optionally up to last_event_id           │
│  • Decrypt if cloaked                        │
└─────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────┐
│  For each event:                             │
│  1. Check for replay_override                │
│  2. If override matches → rerouted replay    │
│  3. If no override → normal replay           │
│  4. Set context: ash_events_replay?: true    │
└─────────────────────────────────────────────┘
```

### Replay API

```elixir
# Replay all events
Ash.run_action!(EventLog, :replay)

# Point-in-time replay
Ash.run_action!(EventLog, :replay, %{
  point_in_time: ~U[2024-01-15 12:00:00Z]
})

# Replay up to specific event
Ash.run_action!(EventLog, :replay, %{
  last_event_id: 1234
})
```

---

## Changed Attributes Tracking

### Why It Matters

Without changed attributes, computed values are lost:

```elixir
# Action computes email from username
create :create do
  accept [:username]
  change fn cs, _ ->
    username = Ash.Changeset.get_attribute(cs, :username)
    Ash.Changeset.change_attribute(cs, :email, "#{username}@example.com")
  end
end

# Event stores: data = %{username: "john"}
# During replay, if logic changes to @newdomain.com, wrong email!
```

With changed attributes:
```
Event stores:
  data = %{username: "john"}
  changed_attributes = %{email: "john@example.com"}

During replay with :force_change, email preserved correctly
```

### What Gets Captured

Changed attributes include any attribute that:
1. Was modified by a change during action execution
2. Was NOT in the original input params
3. Is not sensitive (unless `store_sensitive_attributes` or `cloak_vault`)

---

## Replay Strategies

Configure how changed_attributes are handled during replay:

```elixir
events do
  replay_non_input_attribute_changes [
    create: :force_change,
    update: :as_arguments
  ]
end
```

### `:force_change` (Default)

**Behavior**: Changed attributes are force-changed after all business logic runs.

**Flow**:
1. Create changeset with `event.data` (original input)
2. All user changes run normally
3. `ApplyChangedAttributes` runs last
4. Force-changes all values from `event.changed_attributes`
5. Business logic computations are overwritten

**Use when**: You need exact state reconstruction (timestamps, generated values, computed fields that must match exactly).

### `:as_arguments`

**Behavior**: Changed attributes are merged into input, letting business logic process them.

**Flow**:
1. Merge `event.data` + `event.changed_attributes` into input
2. Create changeset with merged input
3. All user changes run normally
4. Values may be overwritten by business logic

**Use when**: Business logic should recompute values, or when you want changes to validate/transform the values.

---

## Replay Overrides & Rerouting

### Purpose

Handle schema evolution by routing old event versions to different actions.

### Configuration

```elixir
replay_overrides do
  replay_override MyApp.User, :create do
    versions [1]
    route_to MyApp.User, :create_v1
    route_to MyApp.Analytics.UserStats, :track_signup, record_id: :ignore
  end

  replay_override MyApp.User, :create do
    versions [2, 3]
    route_to MyApp.User, :create_v2
  end
end
```

### Input-Only Philosophy for Rerouted Events

When an event is rerouted, we follow a strict principle:

**Only pass what the target action explicitly accepts.**

```elixir
# Event has: data = %{email: "test@example.com", given_name: "Test"}
#            changed_attributes = %{hashed_password: "abc123", confirmed_at: ~U[...]}

# Target action:
create :create_v1 do
  accept [:email, :given_name, :hashed_password]  # explicitly accepts hashed_password
end

# Input passed to action:
%{
  email: "test@example.com",
  given_name: "Test",
  hashed_password: "abc123"  # included because action accepts it
}
# confirmed_at NOT passed - action doesn't accept it
```

**Why**:
- Target action is responsible for computing derived values
- Non-recomputable values (like hashed_password from expired token) must be explicitly accepted
- This is the developer's signal that they need that value

### Multiple Route Targets

A single override can route to multiple targets:

```elixir
replay_override MyApp.User, :create do
  versions [1]
  route_to MyApp.User, :create_v1                           # Main resource
  route_to MyApp.RoutedUser, :routed_create                 # Shadow copy
  route_to MyApp.Analytics.SignupCounter, :increment, record_id: :ignore  # Analytics
end
```

---

## Record ID Handling Modes

When routing events to different resources, configure how `event.record_id` is handled:

```elixir
route_to MyApp.Target, :action, record_id: :force_change_attribute
```

### `:force_change_attribute` (Default)

**Behavior**: Force-change the target resource's primary key to `event.record_id`.

**Use when**: Routing to the same resource or when target should have same ID.

```elixir
# Event: record_id = "abc-123"
# Target record created with id = "abc-123"
```

### `:as_argument`

**Behavior**: Pass record_id as an argument named `:record_id` to the action.

**Use when**: Target resource needs to reference the original record but has its own primary key.

```elixir
# Target action must declare the argument:
create :track_user_event do
  argument :record_id, :uuid, allow_nil?: true
  # ... use record_id to reference original user
end
```

### `:ignore`

**Behavior**: Don't pass record_id at all.

**Use when**: Projection resources that aggregate events without tracking individual records.

```elixir
# Counter resource - doesn't care about individual user IDs
create :increment do
  accept [:event_type]
  # Gets its own generated primary key
end
```

---

## Actor Attribution

Track which actors (users, systems) performed actions:

```elixir
event_log do
  persist_actor_primary_key :user_id, MyApp.Accounts.User
  persist_actor_primary_key :system_actor, MyApp.SystemActor, attribute_type: :string
end
```

### How It Works

1. Check the `:actor` option passed to the action
2. If actor struct matches a configured destination, store its primary key
3. Multiple actor types supported (user actors, system actors, etc.)

### Usage

```elixir
# User action
Ash.create!(Post, %{title: "Hello"}, actor: current_user)
# Event: user_id = current_user.id

# System action
Ash.create!(Post, %{title: "Auto"}, actor: %SystemActor{name: "cron_job"})
# Event: system_actor = "cron_job"
```

---

## Encryption Support

Encrypt sensitive event data at rest using Cloak:

```elixir
event_log do
  cloak_vault MyApp.Vault
end
```

### How It Works

**Storage**:
- `data`, `metadata`, `changed_attributes` become **calculated fields** (decrypt on-demand)
- `encrypted_data`, `encrypted_metadata`, `encrypted_changed_attributes` store encrypted binary

**Encryption flow**:
1. JSON encode map
2. Encrypt with vault
3. Base64 encode
4. Store in `encrypted_*` field

**Reading encrypted events**:
```elixir
# Must explicitly load calculated fields
EventLog
|> Ash.Query.load([:data, :metadata, :changed_attributes])
|> Ash.read!()
```

---

## Version Management

Track schema evolution with action versions:

```elixir
events do
  current_action_versions create: 2, update: 1
end
```

### Evolution Workflow

1. **Initial**: Version 1 (default) for all actions
2. **Schema change**: Increment version
3. **Create replay override**: Route old versions to legacy action

```elixir
# When user schema changes significantly:

# 1. Increment version
events do
  current_action_versions create: 2  # was 1
end

# 2. Create legacy action that handles v1 events
create :create_v1 do
  accept [:email, :name]  # old schema
  # ... handle old format
end

# 3. Add replay override
replay_override MyApp.User, :create do
  versions [1]
  route_to MyApp.User, :create_v1
end
```

---

## Upsert Action Support

AshEvents handles upsert actions with special care during replay.

### Normal Upsert Events

Upsert actions create events normally. The event captures:
- All input data
- Changed attributes (including whether record was created or updated)

### Replay Handling

**Problem**: PostgreSQL ON CONFLICT doesn't work reliably during replay when:
- ID is passed as input
- Running within nested transaction

**Solution for rerouted upserts**:

```elixir
# During rerouted replay of upsert action:
case get_record_if_exists(resource, event.record_id) do
  {:ok, existing_record} ->
    # Record exists: update using upsert_fields
    replay_rerouted_upsert_as_update(event, existing_record)

  {:error, :not_found} ->
    # Record doesn't exist: create normally
    replay_as_create(event)
end
```

### Configuring Upsert Replay Actions

For rerouted upserts, the target action's `upsert? true` flag signals replay logic to use this special handling:

```elixir
create :create_or_update_replay do
  accept [...]
  upsert? true  # Signals special replay handling
  upsert_identity :unique_constraint
  upsert_fields [:field1, :field2]  # Only these updated if record exists
end
```

---

## Advisory Locks

Prevent race conditions during concurrent event creation:

```elixir
event_log do
  advisory_lock_key_default 2_147_483_647
  advisory_lock_key_generator MyApp.CustomLockGenerator
end
```

### How It Works

1. Before event creation, acquire PostgreSQL advisory lock
2. Lock is transaction-scoped (`pg_advisory_xact_lock`)
3. Lock released when transaction ends
4. Prevents concurrent events from causing ordering issues

### Custom Lock Generators

For non-integer tenant IDs:

```elixir
defmodule MyApp.CustomLockGenerator do
  use AshEvents.AdvisoryLockKeyGenerator

  def generate_key!(changeset, default) do
    # Convert tenant to integer pair
    # Return integer or [int, int]
  end
end
```

---

## Practical Scenarios

### Scenario 1: Complete Audit Trail

**Goal**: Track all changes with actor attribution.

```elixir
# EventLog
event_log do
  persist_actor_primary_key :user_id, MyApp.User
  persist_actor_primary_key :system_id, MyApp.SystemActor, attribute_type: :string
end

# Resources
events do
  event_log MyApp.EventLog
  create_timestamp :inserted_at
  update_timestamp :updated_at
end

# Usage
Ash.update!(record, changes, actor: current_user, context: %{
  ash_events_metadata: %{reason: "Customer request", ticket: "JIRA-123"}
})
```

### Scenario 2: Point-in-Time Recovery

**Goal**: Reconstruct state at any moment.

```elixir
# Replay to specific time
Ash.run_action!(EventLog, :replay, %{
  point_in_time: ~U[2024-01-15 12:00:00Z]
})

# Check state
users = Ash.read!(User)
# State as it was on Jan 15, 2024 at noon
```

### Scenario 3: Schema Evolution

**Goal**: Handle breaking changes gracefully.

```elixir
# Old: User has :name field
# New: User has :first_name and :last_name

# 1. Update resource
attributes do
  attribute :first_name, :string
  attribute :last_name, :string
  # Remove :name
end

# 2. Increment version
events do
  current_action_versions create: 2
end

# 3. Create v1 handler
create :create_v1 do
  accept [:name, ...]
  change fn cs, _ ->
    name = Ash.Changeset.get_argument(cs, :name)
    [first, last] = String.split(name, " ", parts: 2)
    cs
    |> Ash.Changeset.change_attribute(:first_name, first)
    |> Ash.Changeset.change_attribute(:last_name, last || "")
  end
end

# 4. Add override
replay_override MyApp.User, :create do
  versions [1]
  route_to MyApp.User, :create_v1
end
```

### Scenario 4: Analytics Projections

**Goal**: Build read-optimized projections from events.

```elixir
# Projection resource
defmodule MyApp.Analytics.SignupStats do
  use Ash.Resource, ...

  attributes do
    uuid_primary_key :id
    attribute :date, :date
    attribute :signup_count, :integer, default: 0
  end

  actions do
    create :track_signup do
      accept [:date]
      # Gets its own ID, ignores user's record_id
    end
  end
end

# Route user creates to projection
replay_override MyApp.User, :create do
  versions [1, 2, 3]
  route_to MyApp.User, :create_current
  route_to MyApp.Analytics.SignupStats, :track_signup, record_id: :ignore
end
```

### Scenario 5: Sensitive Data with Encryption

**Goal**: Encrypt all event data at rest.

```elixir
# Configure vault
defmodule MyApp.Vault do
  use Cloak.Vault, otp_app: :my_app
end

# EventLog with encryption
event_log do
  cloak_vault MyApp.Vault
  # No need for store_sensitive_attributes - everything encrypted
end

# Query (must load decrypted fields)
EventLog
|> Ash.Query.load([:data, :metadata, :changed_attributes])
|> Ash.read!()
```

### Scenario 6: Controlling Side Effects During Replay

**Goal**: Skip external API calls during replay.

```elixir
events do
  # Only these changes run during replay
  allowed_change_modules [
    create: [MyApp.Changes.SetDefaults, MyApp.Changes.ComputeSlug],
    # MyApp.Changes.SendWelcomeEmail NOT listed - skipped during replay
  ]
end

# Or check in the change itself
def change(changeset, _opts, context) do
  if context[:ash_events_replay?] do
    changeset  # Skip during replay
  else
    send_welcome_email(changeset)
  end
end
```

---

## Summary: Feature Interactions

| Feature | Works With | Purpose |
|---------|------------|---------|
| Event Creation | Actor Attribution | Track who did what |
| Event Creation | Encryption | Secure storage |
| Event Creation | Advisory Locks | Prevent race conditions |
| Changed Attributes | Replay Strategies | Deterministic reconstruction |
| Replay Overrides | Version Management | Schema evolution |
| Replay Overrides | Record ID Modes | Cross-resource routing |
| Upsert Support | Rerouted Replay | Handle create-or-update during replay |
| Clear Records | Replay | Clean slate for reconstruction |

The system is designed so that:
1. **Normal operation** creates comprehensive event records
2. **Replay** can reconstruct exact state using those records
3. **Schema evolution** is handled gracefully through overrides
4. **Security** is maintained through encryption and sensitive attribute handling
5. **Auditability** is complete through actor attribution and metadata
