<!--
SPDX-FileCopyrightText: 2024 Torkild G. Kjevik

SPDX-License-Identifier: MIT
-->

# Events Extension

The `AshEvents.Events` extension enables event tracking on Ash resources, automatically creating events for create, update, and destroy actions.

## Overview

The Events extension:
- Wraps tracked actions to create events before execution
- Captures action input as event data
- Tracks changed attributes from business logic
- Supports version management for schema evolution
- Handles sensitive attribute filtering

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `event_log` | module | required | The EventLog resource to store events |
| `only_actions` | list | nil | Only track these actions (exclusive with ignore_actions) |
| `ignore_actions` | list | `[]` | Don't track these actions |
| `current_action_versions` | keyword list | `[]` | Version numbers for actions |
| `allowed_change_modules` | keyword list | `[]` | Change modules to preserve during replay |
| `create_timestamp` | atom | nil | Attribute name for create timestamp |
| `update_timestamp` | atom | nil | Attribute name for update timestamp |
| `replay_non_input_attribute_changes` | keyword list | `[]` | Replay strategy per action |
| `store_sensitive_attributes` | list | `[]` | Sensitive attributes to store despite marking |

## Basic Setup

```elixir
defmodule MyApp.Accounts.User do
  use Ash.Resource,
    domain: MyApp.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events]

  events do
    event_log MyApp.Events.EventLog
  end

  # ... attributes and actions
end
```

## Action Tracking

### Track All Actions (Default)

```elixir
events do
  event_log MyApp.Events.EventLog
  # All create, update, destroy actions are tracked
end
```

### Track Specific Actions Only

```elixir
events do
  event_log MyApp.Events.EventLog
  only_actions [:create, :update]  # Only these actions create events
end
```

### Ignore Specific Actions

```elixir
events do
  event_log MyApp.Events.EventLog
  ignore_actions [:soft_delete, :admin_update]  # These won't create events
end
```

## Version Management

Track action versions for schema evolution:

```elixir
events do
  event_log MyApp.Events.EventLog
  current_action_versions create: 2, update: 1, destroy: 1
end
```

When replaying, use replay_overrides in EventLog to route old versions:

```elixir
# In EventLog resource
replay_overrides do
  replay_override MyApp.User, :create do
    versions [1]
    route_to MyApp.User, :create_v1
  end
end
```

## Changed Attributes Handling

Configure how auto-generated attributes are handled during replay:

```elixir
events do
  event_log MyApp.Events.EventLog

  replay_non_input_attribute_changes [
    create: :force_change,    # Apply exact values (default)
    update: :as_arguments     # Merge into action input
  ]
end
```

### Strategy Comparison

| Strategy | Behavior | Use Case |
|----------|----------|----------|
| `:force_change` | Applies exact values via `force_change_attributes` | Preserve computed fields exactly |
| `:as_arguments` | Merges into action input | Let business logic recompute |

## Sensitive Attributes

By default, sensitive attributes are set to nil in events. Override this:

```elixir
events do
  event_log MyApp.Events.EventLog
  store_sensitive_attributes [:hashed_password]  # Store despite sensitive marking
end
```

For encrypted storage, use `cloak_vault` on EventLog instead.

## Timestamp Configuration

Tell AshEvents which attributes are timestamps for proper replay:

```elixir
events do
  event_log MyApp.Events.EventLog
  create_timestamp :inserted_at
  update_timestamp :updated_at
end
```

## Allowed Change Modules

Preserve specific change modules during replay:

```elixir
events do
  event_log MyApp.Events.EventLog
  allowed_change_modules [
    create: [MyApp.Changes.SetDefaults],
    update: [MyApp.Changes.AuditLog]
  ]
end
```

## Action Wrapper Behavior

The extension wraps actions with event creation:

```
1. Action called with input
2. Event created with:
   - resource: Module name
   - action: Action name
   - action_type: :create/:update/:destroy
   - version: From current_action_versions
   - data: Action input (cast to proper types)
   - actor: From opts[:actor]
3. Original action executed
4. Changed attributes captured (if configured)
5. Event finalized
```

## Integration with Forms

Works seamlessly with AshPhoenix.Form:

```elixir
# Form submission
form
|> AshPhoenix.Form.submit(actor: current_user)
# Event automatically created with form data
```

## Key Files

| File | Purpose |
|------|---------|
| `lib/events/events.ex` | DSL definition |
| `lib/events/transformers/wrap_actions.ex` | Wraps actions with event creation |
| `lib/events/create_action_wrapper.ex` | Create action wrapper |
| `lib/events/update_action_wrapper.ex` | Update action wrapper |
| `lib/events/destroy_action_wrapper.ex` | Destroy action wrapper |
| `lib/events/action_wrapper_helpers.ex` | Common wrapper logic |
| `lib/events/verifiers/` | Configuration validation |

## Testing

```elixir
describe "events extension" do
  test "creates event for tracked action", %{user: user} do
    post = Ash.create!(Post, :create, %{title: "Test"}, actor: user)

    [event] = Ash.read!(MyApp.EventLog)
    assert event.resource == MyApp.Post
    assert event.action == :create
    assert event.data["title"] == "Test"
  end

  test "ignores actions in ignore_actions list", %{user: user} do
    Ash.update!(post, :admin_update, %{}, actor: user)

    events = Ash.read!(MyApp.EventLog)
    refute Enum.any?(events, &(&1.action == :admin_update))
  end
end
```

## Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Events not created | Action in `ignore_actions` | Remove from ignore list |
| Missing actor | Actor not passed to action | Add `actor: user` to opts |
| Wrong version in event | Version not configured | Add to `current_action_versions` |
| Sensitive data in events | Attribute not marked sensitive | Mark as sensitive or use encryption |

**See also**: [event-log.md](event-log.md), [changed-attributes.md](changed-attributes.md), [replay.md](replay.md)
