<img src="https://github.com/ash-project/ash_events/blob/main/logos/ash-events.png?raw=true" alt="Logo" width="300"/>

![Elixir CI](https://github.com/ash-project/ash_events/workflows/CI/badge.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Hex version badge](https://img.shields.io/hexpm/v/ash_events.svg)](https://hex.pm/packages/ash_events)
[![Hexdocs badge](https://img.shields.io/badge/docs-hexdocs-purple)](https://hexdocs.pm/ash_events)
# AshEvents

AshEvents is an extension for the [Ash Framework](https://ash-hq.org/) that provides event capabilities for Ash resources. It allows you to track and persist events when actions (create, update, destroy) are performed on your resources, providing a complete audit trail and enabling powerful replay functionality.

## Features

- **Automatic Event Logging**: Records create, update, and destroy actions as events
- **Event Versioning**: Support for tracking versions of events for schema evolution
- **Actor Attribution**: Store who performed each action (users, system processes, etc)
- **Event Replay**: Rebuild resource state by replaying events
- **Version-specific Replay Routing**: Route events to different actions based on their version
- **Customizable Metadata**: Attach arbitrary metadata to events

## Installation

Add `ash_events` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_events, "~> 0.1.0"}
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

    # Optional, defaults to :uuid
    record_id_type :uuid

    # Store primary key of actors running the actions
    persist_actor_primary_key :user_id, MyApp.Accounts.User
    persist_actor_primary_key :system_actor, MyApp.SystemActor, attribute: :string
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
- **action**: The name of the action that was performed.
- **action type**: The specific action that was performed (create, update, destroy)
- **actor primary key**: Primary key of actor that ran the action (multiple actor types are supported)
- **data**: Any attributes and arguments that was provided to the action
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

## Reference

- [AshEvents.Events DSL](documentation/dsls/DSL-AshEvents.Events.md)
- [AshEvents.EventLog DSL](documentation/dsls/DSL-AshEvents.EventLog.md)
