<!--
SPDX-FileCopyrightText: 2024 Torkild G. Kjevik

SPDX-License-Identifier: MIT
-->

# Event Replay

Event replay reconstructs resource state by replaying events chronologically, enabling complete audit trails and state recovery.

## Overview

The replay system:
- Clears all tracked resources before replay
- Fetches events in chronological order
- Replays each event as its original action
- Handles version routing for schema evolution
- Supports point-in-time replay
- Manages changed attributes during reconstruction

## Replay Flow

```
1. Clear Records      → Remove all data from tracked resources
2. Fetch Events       → Query events sorted by ID (chronological)
3. Check Overrides    → Route old versions to legacy actions if configured
4. Replay Action      → Execute action with event data
5. Apply Changes      → Handle changed_attributes based on strategy
6. Continue           → Process next event until complete
```

## Basic Usage

```elixir
# Replay all events
Ash.run_action!(MyApp.EventLog, :replay)

# Point-in-time replay
Ash.run_action!(MyApp.EventLog, :replay, %{point_in_time: ~U[2024-01-15 12:00:00Z]})

# Replay up to specific event
Ash.run_action!(MyApp.EventLog, :replay, %{last_event_id: 1234})
```

## Clear Records Requirement

You must implement `AshEvents.ClearRecordsForReplay`:

```elixir
defmodule MyApp.Events.ClearAllRecords do
  use AshEvents.ClearRecordsForReplay

  @impl true
  def clear_records!(opts) do
    # Clear in dependency order (children before parents)
    Ash.bulk_destroy!(MyApp.Comments, :destroy, %{}, opts)
    Ash.bulk_destroy!(MyApp.Posts, :destroy, %{}, opts)
    Ash.bulk_destroy!(MyApp.Users, :destroy, %{}, opts)
    :ok
  end
end
```

**Critical**: Clear resources in the correct order to avoid foreign key violations.

## Replay Strategies

### `:force_change` (Default)

Applies changed_attributes via `force_change_attributes`, preserving exact values:

```elixir
events do
  replay_non_input_attribute_changes [
    create: :force_change
  ]
end
```

**Use when**: You need exact state reconstruction (timestamps, computed fields, etc.)

### `:as_arguments`

Merges changed_attributes into action input:

```elixir
events do
  replay_non_input_attribute_changes [
    update: :as_arguments
  ]
end
```

**Use when**: Business logic should recompute values during replay

## Version Management

Handle schema evolution with replay overrides:

```elixir
# In EventLog resource
replay_overrides do
  replay_override MyApp.User, :create do
    versions [1]
    route_to MyApp.User, :create_v1
  end

  replay_override MyApp.User, :create do
    versions [2, 3]
    route_to MyApp.User, :create_v2
  end
end
```

### Creating Legacy Actions

```elixir
# Legacy action for v1 events
actions do
  create :create_v1 do
    # Accept old schema
    argument :old_field, :string
    change fn changeset, _ ->
      # Transform to new schema
      old_value = Ash.Changeset.get_argument(changeset, :old_field)
      Ash.Changeset.change_attribute(changeset, :new_field, transform(old_value))
    end
  end
end
```

## Rerouting to Different Resources

When rerouting events to a different resource (e.g., for backfilling a new resource from old events):

### Event-Driven Philosophy

**Events are data, consumers decide how to process them.**

For rerouted actions, replay merges all event data (`event.data` + `event.changed_attributes`) and passes it as input. The target action is responsible for:
1. Accepting the fields it needs via `accept` list or `arguments`
2. Ignoring fields it doesn't care about via `skip_unknown_inputs`

This matches standard event-driven system behavior where events are facts and consumers interpret them.

### Pattern for Backfill Actions

```elixir
defmodule MyApp.NewResource do
  use Ash.Resource,
    extensions: [AshEvents.Events]

  events do
    event_log MyApp.EventLog
    # Backfill action only used for replay, not normal operations
    ignore_actions [:backfill_from_old_resource]
  end

  actions do
    create :backfill_from_old_resource do
      # Accept the fields you need from the original events
      accept [:id, :email, :name]
      # Ignore fields from the original resource you don't need
      skip_unknown_inputs :*
    end
  end

  attributes do
    # writable? true required if accepting id as input
    uuid_primary_key :id do
      writable? true
    end
    # ... other attributes
  end
end
```

### Key Differences: Normal vs Rerouted Replay

| Aspect | Normal Replay | Rerouted Replay |
|--------|---------------|-----------------|
| Input | Based on `replay_non_input_attribute_changes` strategy | All data merged (`event.data` + `changed_attributes`) |
| Changed attributes | Applied via `force_change_attributes` (for `:force_change`) | Passed as input, not force-changed |
| Filtering | None needed (same resource) | Target action responsible via `skip_unknown_inputs` |
| Primary key | Applied via `force_change` | Must be in `accept` list with `writable? true` |

### Rerouted Upsert Actions

For rerouted actions that use `upsert? true`, replay handles them specially:

1. **If record exists** (by `event.record_id`): Update only the fields specified in `upsert_fields`
2. **If record doesn't exist**: Create normally with merged data

This is necessary because PostgreSQL upsert (ON CONFLICT) doesn't work reliably when:
- The id is passed as input (may conflict with primary key before ON CONFLICT triggers)
- The action is running within nested transactions (replay context)

Example pattern for rerouted upsert replay action:

```elixir
# Magic link sign-in can create new users (upsert on email)
# For replay, we mark it as upsert so replay applies correct logic
create :sign_in_with_magic_link_replay do
  upsert? true
  upsert_identity :unique_email
  upsert_fields [:email]  # Only these fields are updated if record exists
  # Accept id so new users get their original id
  accept [:id, :email]
  skip_unknown_inputs [:*]
end
```

**Key insight**: The `upsert? true` on rerouted actions serves as a flag for replay logic, not for database upsert. Replay checks if record exists and either updates the `upsert_fields` or creates.

**Upsert fields handling**:
- `upsert_fields [:field1, :field2]`: Updates only these fields
- `upsert_fields :replace_all`: Updates all fields from the event
- `upsert_fields nil` (default): Updates the fields in the `accept` list

## Handling Action Types

### Create Actions

```elixir
# Normal create
event.action_type == :create
→ Ash.Changeset.for_create(resource, action, event.data)
→ Ash.create!()

# Upsert create
event.action_type == :create && action.upsert?
→ Check if record exists
→ If exists: replay as update
→ If not: replay as create
```

### Update Actions

```elixir
event.action_type == :update
→ Ash.get!(resource, event.record_id)
→ Ash.Changeset.for_update(record, action, event.data)
→ Ash.update!()
```

### Destroy Actions

```elixir
event.action_type == :destroy
→ Ash.get!(resource, event.record_id)
→ Ash.Changeset.for_destroy(record, action)
→ Ash.destroy!()
```

## Context During Replay

The replay sets context flags:

```elixir
# In changes/validations, check if replaying
context = changeset.context
if context[:ash_events_replay?] do
  # Skip side effects during replay
end

# Access changed_attributes from original event
changed_attrs = context[:changed_attributes]
```

## Encryption Handling

For encrypted events, fields are loaded and decrypted:

```elixir
# In replay.ex
if cloak_vault do
  Ash.Query.load(query, [:data, :metadata, :changed_attributes])
end
```

## Replay Edge Cases

### Empty Event Log

Replay succeeds with an empty event log:

```elixir
# Clear all events
AshEvents.EventLogs.ClearRecords.clear_records!([])

# Replay with no events still succeeds
:ok = Ash.run_action!(MyApp.EventLog, :replay)
```

### Replay Idempotency

Replay is idempotent - running multiple times produces consistent results:

```elixir
# Multiple replays produce same state
AshEvents.ClearRecords.clear_records!([])
:ok = Ash.run_action!(MyApp.EventLog, :replay)
state1 = Ash.read!(MyApp.User)

AshEvents.ClearRecords.clear_records!([])
:ok = Ash.run_action!(MyApp.EventLog, :replay)
state2 = Ash.read!(MyApp.User)

# state1 == state2
```

### Point-in-Time Edge Cases

**Before any events**: Replay to a time before any events results in empty state:

```elixir
# Get earliest event
events = Ash.read!(MyApp.EventLog, query: [sort: [occurred_at: :asc]])
earliest = hd(events)

# Replay to 1 second before
point_before = DateTime.add(earliest.occurred_at, -1, :second)
:ok = Ash.run_action!(MyApp.EventLog, :replay, %{point_in_time: point_before})

# No records exist
[] = Ash.read!(MyApp.User)
```

**Exact timestamp**: Replaying to the exact event timestamp includes that event.

### Parameter Precedence

When both `last_event_id` and `point_in_time` are provided, `last_event_id` takes precedence:

```elixir
# last_event_id wins over point_in_time
:ok = Ash.run_action!(MyApp.EventLog, :replay, %{
  last_event_id: create_event.id,           # This is used
  point_in_time: later_timestamp            # This is ignored
})
```

### Destroyed Records

Records that were destroyed remain destroyed after replay:

```elixir
# Create and destroy
user = create_user()
Ash.destroy!(user)

# After replay, user does not exist
AshEvents.ClearRecords.clear_records!([])
:ok = Ash.run_action!(MyApp.EventLog, :replay)

{:error, %Ash.Error.Query.NotFound{}} = Ash.get(MyApp.User, user.id)
```

## Performance Considerations

### Large Event Sets

- Events are streamed, not loaded all at once
- Consider batching clear_records for large datasets
- Use point-in-time replay for testing specific periods

### Optimization Tips

1. **Index event ID** for efficient chronological ordering
2. **Batch clears** in clear_records implementation
3. **Minimize loads** by selecting only needed fields
4. **Use transactions** appropriately for consistency

## Testing Replay

```elixir
describe "event replay" do
  test "reconstructs state from events", %{user: user} do
    # Create initial state
    post = Ash.create!(Post, :create, %{title: "Original"}, actor: user)
    Ash.update!(post, :update, %{title: "Updated"}, actor: user)

    # Get current state for comparison
    original_posts = Ash.read!(Post)

    # Replay
    Ash.run_action!(MyApp.EventLog, :replay)

    # Verify reconstruction
    replayed_posts = Ash.read!(Post)
    assert length(replayed_posts) == length(original_posts)
    assert hd(replayed_posts).title == "Updated"
  end

  test "handles point-in-time replay" do
    # Create events at different times
    post = Ash.create!(Post, :create, %{title: "V1"}, actor: user)
    :timer.sleep(100)
    checkpoint = DateTime.utc_now()
    :timer.sleep(100)
    Ash.update!(post, :update, %{title: "V2"}, actor: user)

    # Replay to checkpoint
    Ash.run_action!(MyApp.EventLog, :replay, %{point_in_time: checkpoint})

    # Should have V1, not V2
    [replayed] = Ash.read!(Post)
    assert replayed.title == "V1"
  end
end
```

## Key Files

| File | Purpose |
|------|---------|
| `lib/event_log/replay.ex` | Core replay logic |
| `lib/event_log/transformers/add_actions.ex` | Adds replay action |
| `lib/events/replay_change_wrapper.ex` | Change module handling |
| `lib/events/replay_validation_wrapper.ex` | Validation handling |

## Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "clear_records_for_replay must be specified" | Missing implementation | Implement `ClearRecordsForReplay` |
| Foreign key violation during clear | Wrong clear order | Clear children before parents |
| State mismatch after replay | Wrong strategy | Check `replay_non_input_attribute_changes` |
| Event not replaying | Version not routed | Add `replay_override` for old versions |
| Missing record for update | Record not created in order | Check event ordering |

**See also**: [event-log.md](event-log.md), [changed-attributes.md](changed-attributes.md)
