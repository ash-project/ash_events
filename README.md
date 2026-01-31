<!--
SPDX-FileCopyrightText: 2024 Torkild G. Kjevik

SPDX-License-Identifier: MIT
-->

<img src="https://github.com/ash-project/ash_events/blob/main/logos/ash-events.png?raw=true" alt="Logo" width="300"/>

![Elixir CI](https://github.com/ash-project/ash_events/workflows/CI/badge.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Hex version badge](https://img.shields.io/hexpm/v/ash_events.svg)](https://hex.pm/packages/ash_events)
[![Hexdocs badge](https://img.shields.io/badge/docs-hexdocs-purple)](https://hexdocs.pm/ash_events)
[![REUSE status](https://api.reuse.software/badge/github.com/ash-project/ash_events)](https://api.reuse.software/info/github.com/ash-project/ash_events)

# AshEvents

AshEvents is an extension for the [Ash Framework](https://ash-hq.org/) that provides event capabilities for Ash resources. It allows you to track and persist events when actions (create, update, destroy) are performed on your resources, providing a complete audit trail and enabling powerful replay functionality.

## Features

- **Automatic Event Logging**: Records create, update, and destroy actions as events
- **Event Versioning**: Support for tracking versions of events for schema evolution
- **Actor Attribution**: Store who performed each action (users, system processes, etc)
- **Event Replay**: Rebuild resource state by replaying events
- **Version-specific Replay Routing**: Route events to different actions based on their version
- **Changed Attributes Tracking**: Automatically captures and replays auto-generated attributes and business logic changes
- **Security Controls**: Configurable sensitive attribute handling with optional encryption support
- **Customizable Metadata**: Attach arbitrary metadata to events

## Installation

Add `ash_events` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_events, "~> 0.5.1"}
    # ... other deps
  ]
end
```


## Usage

### 1. Create an Event Log Resource

First, define a resource that will store your events:

```elixir
defmodule MyApp.Events.Event do
  use Ash.Resource,
    extensions: [AshEvents.EventLog]

  event_log do
    # Module that implements clear_records! callback
    clear_records_for_replay MyApp.Events.ClearAllRecords

    # Optional. Defaults to :integer, Ash.Type.UUIDv7 is the recommended option
    # if your event log is set up with multitenancy via the attribute-strategy.
    primary_key_type Ash.Type.UUIDv7

    # Optional, defaults to :uuid
    record_id_type :uuid

    # Store primary key of actors running the actions
    persist_actor_primary_key :user_id, MyApp.Accounts.User
    persist_actor_primary_key :system_actor, MyApp.SystemActor, attribute_type: :string

    # Optional: Control field visibility for public interfaces
    public_fields :all  # or [:id, :resource, :action, :occurred_at], or [] (default)
  end

  # Optional: Configure replay overrides for version handling
  replay_overrides do
    replay_override MyApp.Accounts.User, :create do
      versions [1]
      route_to MyApp.Accounts.User, :old_create_v1
    end
  end
  .....
end
```

### 2. Define a Clear Records Implementation

Implement the module that will clear records before replay:

```elixir
defmodule MyApp.Events.ClearAllRecords do
  use AshEvents.ClearRecordsForReplay

  @impl true
  def clear_records!(opts) do
    # Logic to clear all relevant records for all resources with event tracking
    # enabled through the event log resource.
    :ok
  end
end
```

### 3. Enable Event Logging on Resources

Add the `AshEvents.Events` extension to resources you want to track:

```elixir
defmodule MyApp.Accounts.User do
  use Ash.Resource,
    extensions: [AshEvents.Events]

  events do
    # Specify your event log resource
    event_log MyApp.Events.Event

    # Optionally ignore certain actions. This is mainly used for actions
    # that are kept around for supporting previous event versions, and
    # are configured as replay_overrrides in the event log (see above).
    ignore_actions [:old_create_v1]

    # Optionally specify version numbers for actions
    current_action_versions create: 2, update: 3, destroy: 2

    # Optionally allow storing specific sensitive attributes (see Advanced Configuration)
    store_sensitive_attributes [:hashed_password]
  end

  # Rest of your resource definition...
  attributes do
    # ...
  end

  actions do
    # ...
  end
end
```

### 4. Track Metadata with Actions

When performing actions, you can include any metadata by adding `ash_events_metadata` to the changeset context:

```elixir
User
|> Ash.Changeset.for_create(:create, %{
  name: "Jane Doe",
  email: "jane@example.com"
}, [
  actor: current_user,
  context: %{ash_events_metadata: %{
    source: "api",
    request_id: request_id
  }}
])
|> Ash.create(opts)
```

### 5. Replay Events

Replay events to rebuild resource state:

```elixir
# Replay all events
MyApp.Events.Event
|> Ash.ActionInput.for_action(:replay, %{})
|> Ash.run_action!()

# Replay events up to a specific event ID
MyApp.Events.Event
|> Ash.ActionInput.for_action(:replay, %{last_event_id: 1000})
|> Ash.run_action!()

# Replay events up to a specific point in time
MyApp.Events.Event
|> Ash.ActionInput.for_action(:replay, %{point_in_time: ~U[2023-05-01 00:00:00Z]})
|> Ash.run_action!()
```

## Using AshEvents for Audit Logging Only

While AshEvents provides powerful event replay capabilities, you can also use it solely as an audit logging system. If you only need to track changes to your resources without implementing event replay functionality, you can:

1. **Skip implementing clear_records_for_replay**: You can skip implementing the `clear_records_for_replay` module, which is only relevant when doing event replay.

3. **Skip defining action_versions**: When there are changes to the expected inputs for an action, you can skip defining `action_versions` for those actions, since they are also only relevant when doing event replay.

This approach allows you to benefit from the automatic event tracking of AshEvents while using it purely as an audit log system rather than a full event sourcing solution.

## Differences from `ash_paper_trail` with regards to audit logging

The value proposition offered by AshEvents compared to `ash_paper_trail` is quite similar
if you only utilize AshEvents for audit logging purposes.

The main differences are:

1. AshEvents stores events in a centralized table/resource, whereas `ash_paper_trail` adds a separate version-resource
for each resource.
2. `ash_paper_trail`'s version resources has several options for change tracking and storing action inputs, whereas AshEvents only stores the action inputs in the event log.
3. Since `ash_paper_trail` uses a unique version-table for each resource, versions can store specific attributes directly in resource, instead of only inside a map. `ash_paper_trail` also gives you the option to ignore certain attributes if needed.
4. `ash_paper_trail` has better support for exposing earlier versions of records to your app, or for example through `ash_graphql` or `ash_json_api`.

## How It Works

AshEvents works by wrapping resource actions. When you perform an action on a resource with events enabled:

1. The action wrapper intercepts the request
2. It creates an event in your event log resource
3. It then calls the original action implementation

During replay, AshEvents:

1. Clears existing records using your `clear_records_for_replay` implementation
2. Loads events in chronological order
3. Applies each event to rebuild resource state
4. Routes events to version-specific implementations if configured

## Changed Attributes Tracking

AshEvents automatically tracks attributes that are modified during action execution but were not part of the original input parameters. This is crucial for maintaining complete application state during event replay when business logic, defaults, or extensions modify data beyond what was explicitly provided.

### What Gets Tracked

**Changed attributes** include:
- Auto-generated values (UUIDs, slugs, computed fields)
- Default values applied to attributes
- Attributes modified by Ash changes or extensions

**Example scenario:**
```elixir
# Original input
User
|> Ash.Changeset.for_create(:create, %{
  name: "John Doe",
  email: "john@example.com"
})
|> Ash.create!(actor: current_user)

# If your User resource has:
# - status: defaults to "active"
# - slug: auto-generated from name ("john-doe")
# These will be captured as changed_attributes in the event
```

### How It Works

1. **During Event Creation**: AshEvents compares the final `changeset.attributes` with the original input parameters
2. **Separation**: Original input stays in `event.data`, auto-generated changes go in `event.changed_attributes`
3. **During Replay**: Both original data and changed attributes are applied to recreate the complete state

### Replay Configuration

Configure how changed attributes are applied during replay using the `replay_non_input_attribute_changes` option:

```elixir
defmodule MyApp.Accounts.User do
  use Ash.Resource,
    extensions: [AshEvents.Events]

  events do
    event_log MyApp.Events.Event

    # Configure per-action replay strategies
    replay_non_input_attribute_changes [
      create: :force_change,     # Default: use force_change_attributes
      update: :as_arguments,     # Merge into action input
      legacy_action: :force_change
    ]
  end
end
```

**Replay Strategies:**

- **`:force_change`** (default): Uses `Ash.Changeset.force_change_attributes()` to apply changed attributes directly
- **`:as_arguments`**: Merges changed attributes into the action input parameters

### Practical Example

```elixir
# User resource with auto-generated attributes
defmodule MyApp.Accounts.User do
  attributes do
    attribute :name, :string, public?: true
    attribute :email, :string, public?: true
    attribute :status, :string, default: "active", public?: true
    attribute :slug, :string, public?: true
  end

  changes do
    # Auto-generate slug from name
    change fn changeset, _context ->
      case Map.get(changeset.attributes, :name) do
        nil -> changeset
        name ->
          slug = String.downcase(name) |> String.replace(~r/[^a-z0-9]/, "-")
          Ash.Changeset.change_attribute(changeset, :slug, slug)
      end
    end, on: [:create, :update]
  end
end

# When you create a user:
user = User
|> Ash.Changeset.for_create(:create, %{
  name: "Jane Smith",
  email: "jane@example.com"
})
|> Ash.create!(actor: current_user)

# The event will contain:
# event.data = %{"name" => "Jane Smith", "email" => "jane@example.com"}
# event.changed_attributes = %{"status" => "active", "slug" => "jane-smith"}

# During replay, both are applied to recreate the complete user state
```

This ensures that during event replay, your resources are recreated with the exact same state they had originally, including all auto-generated and business logic-derived attributes.

## Lifecycle Hooks During Replay

During event replay, **all** action lifecycle hooks are automatically skipped to prevent unintended side effects. This means none of the functionality contained in these hooks will be executed during replay:

- `before_action`, `after_action` and `around_action` hooks
- `before_transaction`, `after_transaction` and `around_transaction` hooks

This is crucial because these hooks might perform operations like sending emails, notifications, or making external API calls that should only happen once when the action originally occurred, not when rebuilding your application state during replay.

For example, if a `:create` action has an `after_action` hook that sends a welcome email, you wouldn't want those emails sent again when replaying events to rebuild the system state.

## Best Practices for Side Effects

To maintain a complete and accurate event log that can be replayed reliably, we recommend encapsulating all side effects and processing of both the requests and responses from external services within other Ash actions, on resources that are also tracking events. For example for things like:

- External API calls
- Email sending
- Anything else that might have side effects outside of your own application state.

By containing these operations within Ash actions:

1. **They can be used inside lifecycle hooks**: Since all lifecycle hooks run normally during regular action execution, if side-effects are kept inside actions on resources that are also tracking events, they will create separate events when these actions are called in for example an `after_action`-hook.

2. **All inputs and responses become part of event data**: When external API calls or other side effects are wrapped in their own actions, the inputs and responses are automatically recorded in the event log.

3. **Improved system transparency**: The event log contains a complete record of all operations, including external interactions.

4. **More reliable event replay**: During replay, you have access to the exact same data that was present during the original operation.

### Example: Email Notifications with after_action Hooks

Here's a practical example of how to handle email notifications using an after_action hook that calls another Ash action for sending the email:

```elixir
# First, define your email notification resource
defmodule MyApp.Notifications.EmailNotification do
  use Ash.Resource,
    extensions: [AshEvents.Events]

  events do
    event_log MyApp.Events.Event
  end

  attributes do
    uuid_primary_key :id
    attribute :recipient_email, :string
    attribute :template, :string
    attribute :data, :map
    attribute :sent_at, :utc_datetime
    attribute :status, :string, default: "pending"
  end

  actions do
    create :send_email do
      accept [:recipient_email, :template, :data]

      change set_attribute(:sent_at, &DateTime.utc_now/0)

      # This would not be triggered again during event replay, since it is in a after_action.
      change after_action(fn cs, record, ctx ->
        result = MyApp.EmailService.send_email(record.recipient_email, record.template, record.data)

        # This will result in an event being logged for the update_status action,
        # which will ensure the correct state is kept during event replay.
        if result == :ok do
          MyApp.Notifications.EmailNotification.update_status(record.id, status: "sent")
          else
          MyApp.Notifications.EmailNotification.update_status(record.id, status: "failed")
        end
      end)
    end

    update :update_status do
      accept [:status]
    end
  end
end

# Then in your User resource
defmodule MyApp.Accounts.User do
  use Ash.Resource,
    extensions: [AshEvents.Events]

  events do
    event_log MyApp.Events.Event
  end

  attributes do
    uuid_primary_key :id
    attribute :email, :string
    attribute :name, :string
  end

  actions do
    create :create do
      accept [:email, :name]

      # After creating a user, send a welcome email
      change after_action(fn cs, record, ctx ->
        MyApp.Notifications.EmailNotification
        |> Ash.Changeset.for_create(:send_email, %{
          recipient_email: user.email,
          template: "welcome_email",
          data: %{
            user_name: user.name
          },
          # You can include metadata for the email event
          ash_events_metadata: %{
            triggered_by: "user_creation",
            user_id: user.id
          }
        })
        |> Ash.create!()

        # Return the user unmodified
        {:ok, record}
      end)
    end
  end
end
```

With this approach:

1. When a user is created, the after_action hook is triggered
2. This hook calls the `send_email` action on the `EmailNotification` resource
3. Three separate events are recorded in your event log:
   - The user creation event
   - The email sending event with its own metadata
   - The email update status event after getting the response from the email service

During event replay, the lifecycle hooks are skipped, so no duplicate emails will be sent, but all events will still be present in your log for audit purposes, giving you a complete history of what happened and a correct application state.

## Event Log Structure

When events are recorded, they are stored in your event log resource with a structure like this:

```elixir
%MyApp.Events.Event{
  id: "123e4567-e89b-12d3-a456-426614174000",
  resource: MyApp.Accounts.User,
  record_id: "8f686f8f-6c5e-4529-bc78-164979f5d686",
  action: :create,
  action_type: :create,
  user_id: "d7874250-4f50-4e72-b32c-ff779852c1bd", # if persist_actor_primary_key is configured
  data: %{
    "name" => "Jane Doe",
    "email" => "jane@example.com"
  },
  changed_attributes: %{
    "status" => "active",      # Default value applied
    "slug" => "jane-doe",      # Auto-generated from name
    "uuid" => "550e8400-e29b-41d4-a716-446655440000"  # Auto-generated UUID
  },
  metadata: %{
    "source" => "api",
    "request_id" => "req-abc123"
  },
  version: 2,
  occurred_at: ~U[2023-06-15 14:30:00Z]
}
```

This structure captures all the essential information about each event:

- **id**: Unique identifier for the event
- **resource**: The full module name of the resource that generated the event
- **action**: The name of the action that was performed
- **action_type**: The specific action that was performed (create, update, destroy)
- **actor primary key**: Primary key of actor that ran the action (multiple actor types are supported)
- **data**: Attributes and arguments that were provided to the action
- **changed_attributes**: Attributes modified during action execution (defaults, auto-generated values, business logic changes)
- **metadata**: Additional contextual information about the event
- **version**: Version number of the event
- **occurred_at**: Timestamp when the event was recorded

## Advanced Configuration

### Version Management

As your application evolves, you might need to handle different versions of events. Use replay overrides to route older event versions to specific actions:

```elixir
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
```

The replay override functionality can also be used to route events to different resources based on their version, if you end up making substantial changes to your application:

```elixir
replay_overrides do
  replay_override MyApp.Accounts.User, :update do
    versions [1, 2]
    route_to MyApp.Accounts.UserV2, :update_v2
  end
end
```

You can also route an event to multiple actions if needed:

```elixir
replay_overrides do
  replay_override MyApp.Accounts.User, :update do
    versions [1, 2]
    route_to MyApp.Accounts.UserV2, :update
    route_to MyApp.Accounts.UserV3, :update
  end
end
```

### Security and Sensitive Attributes

**By default, sensitive attributes are excluded from events** for security. However, **if you are using a cloaked event log (with encryption), all sensitive attributes are always persisted** since they will be encrypted.

#### Non-Encrypted Event Logs

For non-encrypted event logs, use `store_sensitive_attributes` to explicitly allow specific sensitive attributes:

```elixir
defmodule MyApp.Accounts.User do
  use Ash.Resource,
    extensions: [AshEvents.Events]

  events do
    event_log MyApp.Events.Event
    # Explicitly allow storing specific sensitive attributes
    store_sensitive_attributes [:hashed_password, :api_key_hash]
  end

  attributes do
    attribute :email, :string, public?: true
    attribute :hashed_password, :string, sensitive?: true, public?: true
    attribute :api_key_hash, :binary, sensitive?: true, public?: true
    attribute :secret_token, :string, sensitive?: true, public?: true  # NOT stored in events
  end
end

# Only hashed_password and api_key_hash will be included in events
# secret_token will be excluded for security
```

#### Encrypted Event Logs

When using a cloaked event log, all sensitive attributes are automatically persisted because they will be encrypted:

```elixir
defmodule MyApp.Events.Event do
  use Ash.Resource,
    extensions: [AshEvents.EventLog]

  event_log do
    cloak_vault MyApp.Vault  # Enables encryption
  end
end

# When using a cloaked event log, ALL sensitive attributes are automatically
# persisted because they will be encrypted. The store_sensitive_attributes
# configuration is ignored for cloaked event logs.
```

#### Security Considerations

- **Non-encrypted event logs:** Only store sensitive attributes that are necessary for replay or audit
- **Encrypted event logs:** All sensitive attributes are stored since they're encrypted
- Sensitive attributes like passwords, tokens, or keys should usually remain excluded from non-encrypted logs
- Use encryption (`cloak_vault`) when you need to store sensitive data in events

### Public Field Configuration

Control which event log fields are visible in public interfaces like GraphQL or JSON API:

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

### Multiple Actor Types

You can track different types of actors:

```elixir
event_log do
  persist_actor_primary_key :user_id, MyApp.Accounts.User
  persist_actor_primary_key :system_actor, MyApp.SystemActor, attribute_type: :string
end
```

Note: When using multiple actor types, all must have `allow_nil?: true`. This is the default,
but you will get a compile error if one of them is configured with `allow_nil?: false`.

### Advisory Locks

AshEvents uses Postgres transaction-based advisory locks when running actions on event-tracked resources. This ensures that there aren't any race conditions or data inconsistencies when multiple actions are executed concurrently. The default behaviour for how advisory locks are acquired is as follows:

- The default value used to call `pg_advisory_lock` is `2_147_483_647`, if the resource in question is not configured with the multitenancy attribute-strategy. This can be overridden by setting the `advisory_lock_key_default <my-preferred-integer>` option in the `event_log` section. You can either specify a single integer, or a list of two 32-bit integers.
- If the resource is configured with the multitenancy attribute-strategy, the tenant id will be used as-is if it is itself an integer. If the tenant id is of the `:uuid`-type, an integer
will be derived from the UUID. Postgres advisory lock keys only support 64-bit integers or two 32-bit integers, and since a UUID is 128 bits long, the derived integers uses the beginning & end of the UUID. This increases the risk of collisions and unnecessarily blocking writes for other tenants as well, but it is still extremely unlikely to occur in practice.
- Tenant ids that are not integers or valid UUIDs are not supported at the moment, and you will have to implement a custom `AshEvents.AdvisoryLockKeyGenerator` behaviour module to handle them.

### `AshEvents.AdvisoryLockKeyGenerator` Behaviour

If you want to use a different strategy for setting specific advisory lock keys, you can configure it by implementing a custom `AshEvents.AdvisoryLockKeyGenerator` behaviour module, and declaring it in the `event_log` section.

The `AshEvents.AdvisoryLockKeyGenerator` behaviour requires implementing the `generate_key!/2` function, which takes the action changeset as the first argument, and the `advisory_lock_key_default` integer value as the second argument.

See `AshEvents.AdvisoryLockKeyGenerator.Default` for how the default implementation works, and adapt it to your needs.

Example setup:

```elixir
event_log do
  persist_actor_primary_key :user_id, MyApp.Accounts.User
  persist_actor_primary_key :system_actor, MyApp.SystemActor, attribute_type: :string
  advisory_lock_default_value 31337 # or [1337, 31337]
  advisory_lock_key_generator MyApp.MyCustomAdvisoryLockKeyGenerator
end
```

## Reference

- [AshEvents.Events DSL](documentation/dsls/DSL-AshEvents.Events.md)
- [AshEvents.EventLog DSL](documentation/dsls/DSL-AshEvents.EventLog.md)
