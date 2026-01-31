<!--
SPDX-FileCopyrightText: 2024 Torkild G. Kjevik

SPDX-License-Identifier: MIT
-->

# EventLog Extension

The `AshEvents.EventLog` extension transforms an Ash resource into an event log that stores events from tracked resources.

## Overview

The EventLog extension:
- Adds event storage attributes (resource, action, data, metadata, etc.)
- Configures actor attribution persistence
- Enables event replay functionality
- Supports encryption via Cloak vault
- Manages advisory locks for concurrent event insertion

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `primary_key_type` | `:integer` or `Ash.Type.UUIDv7` | `:integer` | Primary key type for events |
| `clear_records_for_replay` | module | required | Module implementing `AshEvents.ClearRecordsForReplay` |
| `cloak_vault` | atom | nil | Vault module for encrypting data and metadata |
| `record_id_type` | any | `:uuid` | Type of record_id field (matches tracked resource PKs) |
| `public_fields` | list or `:all` | `[]` | Fields to make public for API exposure |
| `advisory_lock_key_generator` | module | `Default` | Custom advisory lock key generation |
| `advisory_lock_key_default` | integer | `2_147_483_647` | Default advisory lock key value |

## Basic Setup

```elixir
defmodule MyApp.Events.EventLog do
  use Ash.Resource,
    domain: MyApp.Events,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.EventLog]

  postgres do
    table "events"
    repo MyApp.Repo
  end

  event_log do
    clear_records_for_replay MyApp.Events.ClearAllRecords
    primary_key_type Ash.Type.UUIDv7
    persist_actor_primary_key :user_id, MyApp.Accounts.User
  end
end
```

## Actor Attribution

### Single Actor Type

```elixir
event_log do
  persist_actor_primary_key :user_id, MyApp.Accounts.User
end
```

### Multiple Actor Types

```elixir
event_log do
  persist_actor_primary_key :user_id, MyApp.Accounts.User
  persist_actor_primary_key :system_actor_id, MyApp.SystemActor, attribute_type: :string
end
```

### SystemActor for Testing and Background Jobs

The library provides a `SystemActor` struct for system-level operations that need to bypass authorization:

```elixir
alias AshEvents.EventLogs.SystemActor

# Create a system actor
actor = %SystemActor{name: "background_worker"}

# The system_actor field is persisted in events
{:ok, record} = Ash.create(changeset, actor: actor)

# Events will have:
# - user_id: nil
# - system_actor: "background_worker"
```

The `SystemActor` has `is_system_actor: true` which can be used in policies:

```elixir
policies do
  policy action(:create) do
    authorize_if actor_attribute_equals(:is_system_actor, true)
  end
end
```

## Clear Records Implementation

Required for replay functionality:

```elixir
defmodule MyApp.Events.ClearAllRecords do
  use AshEvents.ClearRecordsForReplay

  @impl true
  def clear_records!(opts) do
    # Clear in correct order (children before parents)
    Ash.bulk_destroy!(MyApp.Comments, :destroy, %{}, opts)
    Ash.bulk_destroy!(MyApp.Posts, :destroy, %{}, opts)
    Ash.bulk_destroy!(MyApp.Users, :destroy, %{}, opts)
    :ok
  end
end
```

## Encryption

### Setup with Cloak Vault

```elixir
# Define vault
defmodule MyApp.Vault do
  use Cloak.Vault, otp_app: :my_app

  @impl GenServer
  def init(config) do
    config =
      Keyword.put(config, :ciphers,
        default: {
          Cloak.Ciphers.AES.GCM,
          tag: "AES.GCM.V1",
          key: decode_env!("CLOAK_KEY"),
          iv_length: 12
        }
      )

    {:ok, config}
  end
end

# Configure EventLog
event_log do
  cloak_vault MyApp.Vault
end
```

### Reading Encrypted Events

```elixir
# Must load encrypted fields explicitly
events = MyApp.EventLog
|> Ash.Query.load([:data, :metadata, :changed_attributes])
|> Ash.read!()
```

## Replay Overrides

Handle schema evolution by routing old event versions to legacy actions:

```elixir
replay_overrides do
  replay_override MyApp.User, :create do
    versions [1]
    route_to MyApp.User, :create_v1
  end

  replay_override MyApp.User, :update do
    versions [1, 2]
    route_to MyApp.User, :update_legacy
  end
end
```

## Public Fields Configuration

Control which fields are exposed in APIs:

```elixir
event_log do
  # Expose all fields
  public_fields :all

  # Or specific fields only
  public_fields [:id, :resource, :action, :occurred_at]
end
```

## Advisory Locks

For high-concurrency scenarios, customize lock behavior:

```elixir
event_log do
  advisory_lock_key_default 12345
  advisory_lock_key_generator MyApp.CustomLockGenerator
end
```

## Generated Attributes

The extension automatically adds these attributes:

| Attribute | Type | Description |
|-----------|------|-------------|
| `id` | integer/UUIDv7 | Primary key |
| `resource` | atom | Source resource module |
| `action` | atom | Action that created the event |
| `action_type` | atom | `:create`, `:update`, or `:destroy` |
| `version` | integer | Event version for schema evolution |
| `record_id` | configurable | ID of the affected record |
| `data` | map | Event data (action input) |
| `metadata` | map | Additional metadata |
| `changed_attributes` | map | Attributes changed by business logic |
| `occurred_at` | datetime | Timestamp when event occurred |
| Actor ID fields | configurable | Based on `persist_actor_primary_key` config |

**Note**: The version field is named `version`, not `action_version`. Access it via `event.version`:

```elixir
event = hd(Ash.read!(MyApp.EventLog))
event.version  # => 1
```

## Key Files

| File | Purpose |
|------|---------|
| `lib/event_log/event_log.ex` | DSL definition |
| `lib/event_log/transformers/add_actions.ex` | Adds replay action |
| `lib/event_log/transformers/add_attributes.ex` | Adds event attributes |
| `lib/event_log/verifiers/` | Configuration validation |
| `lib/event_log/replay.ex` | Replay implementation |

## Testing

```elixir
describe "event log" do
  test "creates events with proper attributes" do
    user = create_user()
    post = Ash.create!(Post, :create, %{title: "Test"}, actor: user)

    [event] = Ash.read!(MyApp.EventLog)
    assert event.resource == MyApp.Posts
    assert event.action == :create
    assert event.user_id == user.id
  end
end
```

## Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Events not created | Missing Events extension on resource | Add `AshEvents.Events` to resource |
| Replay fails | Missing clear_records | Implement `AshEvents.ClearRecordsForReplay` |
| Actor not persisted | Actor type mismatch | Ensure actor matches `persist_actor_primary_key` type |
| Encrypted data not readable | Fields not loaded | Use `Ash.Query.load([:data, :metadata])` |

**See also**: [events-extension.md](events-extension.md), [replay.md](replay.md)
