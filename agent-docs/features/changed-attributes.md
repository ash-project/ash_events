<!--
SPDX-FileCopyrightText: 2024 Torkild G. Kjevik

SPDX-License-Identifier: MIT
-->

# Changed Attributes

Changed attributes tracking captures attributes modified by business logic beyond the original action input, enabling complete state reconstruction during replay.

## Overview

Changed attributes:
- Captures attributes set by changes, defaults, and computed logic
- Stores them separately from original input (`event.data`)
- Applies them during replay according to configured strategy
- Handles both atom and string keys for form compatibility
- Supports binary attribute encoding/decoding

## Why Changed Attributes Matter

Without changed attributes tracking:

```elixir
# Create action sets a computed slug
defmodule MyApp.Post do
  actions do
    create :create do
      accept [:title]
      change fn changeset, _ ->
        title = Ash.Changeset.get_attribute(changeset, :title)
        Ash.Changeset.change_attribute(changeset, :slug, slugify(title))
      end
    end
  end
end

# User creates post
Ash.create!(Post, :create, %{title: "Hello World"}, actor: user)
# slug is set to "hello-world"

# Event stores: data = %{title: "Hello World"}
# slug is NOT in data because it wasn't in input

# During replay: slug might be different if slugify() logic changed!
```

With changed attributes tracking:

```elixir
# Event stores:
#   data = %{title: "Hello World"}
#   changed_attributes = %{slug: "hello-world"}

# During replay: exact slug value is preserved
```

## Configuration

```elixir
events do
  event_log MyApp.Events.EventLog

  replay_non_input_attribute_changes [
    create: :force_change,    # Default - apply exact values
    update: :as_arguments     # Alternative - merge into input
  ]
end
```

## Replay Strategies

### `:force_change` (Default)

Applies changed_attributes via `force_change_attributes`:

```elixir
# During replay
changeset
|> Ash.Changeset.for_create(resource, action, event.data)
|> Ash.Changeset.force_change_attributes(event.changed_attributes)
```

**Behavior**:
- Values applied after all changes run
- Overrides any computed values
- Preserves exact original state

**Use for**:
- Timestamps (`inserted_at`, `updated_at`)
- Computed fields (slugs, hashes)
- Auto-generated values (UUIDs, sequences)

### `:as_arguments`

Merges changed_attributes into action input:

```elixir
# During replay
input = Map.merge(event.data, event.changed_attributes)
Ash.Changeset.for_create(resource, action, input)
```

**Behavior**:
- Values passed as input arguments
- Business logic can still transform them
- May produce different results if logic changed

**Use for**:
- When business logic should recompute
- When input validation is needed
- When changes should run on the data

## What Gets Captured

Changed attributes include:
- Attributes set by `change` modules
- Default values applied during action
- Attributes set by `force_change_attribute`
- Auto-generated values (unless in input)
- Timestamps configured with `create_timestamp`/`update_timestamp`

**Excluded**:
- Attributes in original input
- Primary keys (captured as `record_id`)

## Context During Replay

The changed_attributes are available in changeset context:

```elixir
defmodule MyApp.Changes.ConditionalLogic do
  use Ash.Resource.Change

  def change(changeset, _opts, context) do
    if context[:ash_events_replay?] do
      # Access original changed_attributes
      original_slug = context[:changed_attributes]["slug"]
      Ash.Changeset.force_change_attribute(changeset, :slug, original_slug)
    else
      # Normal logic
      compute_slug(changeset)
    end
  end
end
```

## Common Patterns

### Computed Slugs

```elixir
events do
  event_log MyApp.EventLog
  replay_non_input_attribute_changes [create: :force_change]
end

actions do
  create :create do
    accept [:title]
    change fn changeset, _ ->
      title = Ash.Changeset.get_attribute(changeset, :title)
      Ash.Changeset.change_attribute(changeset, :slug, slugify(title))
    end
  end
end
```

### Timestamps

```elixir
events do
  event_log MyApp.EventLog
  create_timestamp :inserted_at
  update_timestamp :updated_at
  replay_non_input_attribute_changes [
    create: :force_change,
    update: :force_change
  ]
end
```

### Conditional Defaults

```elixir
# Use :as_arguments if you want defaults to recompute
events do
  replay_non_input_attribute_changes [create: :as_arguments]
end

# Use :force_change if you want exact original values
events do
  replay_non_input_attribute_changes [create: :force_change]
end
```

## Testing

```elixir
describe "changed attributes" do
  test "captures attributes set by changes", %{user: user} do
    post = Ash.create!(Post, :create, %{title: "Hello World"}, actor: user)

    [event] = Ash.read!(MyApp.EventLog)
    assert event.data == %{"title" => "Hello World"}
    assert event.changed_attributes["slug"] == "hello-world"
  end

  test "replay preserves changed attributes with :force_change", %{user: user} do
    post = Ash.create!(Post, :create, %{title: "Hello World"}, actor: user)
    original_slug = post.slug

    Ash.run_action!(MyApp.EventLog, :replay)

    [replayed] = Ash.read!(Post)
    assert replayed.slug == original_slug
  end

  test "replay recomputes with :as_arguments", %{user: user} do
    # Configure update to use :as_arguments
    post = Ash.create!(Post, :create, %{title: "Test"}, actor: user)
    Ash.update!(post, :update, %{title: "New Title"}, actor: user)

    # If slugify logic changed, slug would be different after replay
    Ash.run_action!(MyApp.EventLog, :replay)

    [replayed] = Ash.read!(Post)
    # Slug depends on current slugify implementation
  end
end
```

## Key Files

| File | Purpose |
|------|---------|
| `lib/events/events.ex` | DSL for `replay_non_input_attribute_changes` |
| `lib/events/action_wrapper_helpers.ex` | Captures changed_attributes |
| `lib/events/changes/apply_changed_attributes.ex` | Applies during replay |
| `lib/event_log/replay.ex` | Handles strategy during replay |
| `lib/event_log/transformers/add_attributes.ex` | Adds changed_attributes field |

## Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Changed attributes empty | No changes modify attributes | Verify change modules set attributes |
| State mismatch after replay | Wrong strategy | Use `:force_change` for exact replay |
| Timestamps different | Strategy set to `:as_arguments` | Use `:force_change` for timestamps |

**See also**: [replay.md](replay.md), [events-extension.md](events-extension.md)
