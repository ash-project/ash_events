# AshEvents Quick Reference

## Essential Setup

### Event Log Resource
```elixir
defmodule MyApp.Events.Event do
  use Ash.Resource, extensions: [AshEvents.EventLog]
  
  event_log do
    clear_records_for_replay MyApp.Events.ClearAllRecords
    persist_actor_primary_key :user_id, MyApp.Accounts.User
    primary_key_type Ash.Type.UUIDv7  # or :integer
    record_id_type :uuid
  end
end
```

### Resource with Events
```elixir
defmodule MyApp.Accounts.User do
  use Ash.Resource, extensions: [AshEvents.Events]
  
  events do
    event_log MyApp.Events.Event
    current_action_versions create: 2, update: 3
    ignore_actions [:old_create_v1]
  end
end
```

## Common Operations

### Create with Metadata
```elixir
User
|> Ash.Changeset.for_create(:create, params, [
  actor: current_user,
  context: %{ash_events_metadata: %{source: "api"}}
])
|> Ash.create()
```

### Replay Events
```elixir
# All events
MyApp.Events.Event |> Ash.ActionInput.for_action(:replay, %{}) |> Ash.run_action!()

# Up to event ID
MyApp.Events.Event |> Ash.ActionInput.for_action(:replay, %{last_event_id: 1000}) |> Ash.run_action!()

# Up to timestamp
MyApp.Events.Event |> Ash.ActionInput.for_action(:replay, %{point_in_time: ~U[2023-05-01 00:00:00Z]}) |> Ash.run_action!()
```

## Event Structure
```elixir
%Event{
  resource: MyApp.Accounts.User,
  record_id: "uuid",
  action: :create,
  action_type: :create,
  user_id: "actor_id",
  data: %{...},      # Action inputs
  metadata: %{...},   # Custom metadata
  version: 2,
  occurred_at: ~U[...]
}
```