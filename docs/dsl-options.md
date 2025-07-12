# DSL Configuration Options

## Events Extension (`AshEvents.Events`)

### events section
```elixir
events do
  event_log MyApp.Events.Event                    # Required: Event log resource
  only_actions [:create, :update]                 # Optional: Whitelist actions
  ignore_actions [:old_v1]                        # Optional: Blacklist actions
  current_action_versions create: 2, update: 3    # Optional: Action versions
  create_timestamp :inserted_at                   # Optional: Create timestamp attr
  update_timestamp :updated_at                    # Optional: Update timestamp attr
end
```

## EventLog Extension (`AshEvents.EventLog`)

### event_log section
```elixir
event_log do
  primary_key_type Ash.Type.UUIDv7               # :integer | Ash.Type.UUIDv7
  record_id_type :uuid                           # Type for tracked resource IDs
  clear_records_for_replay MyApp.ClearRecords   # Module for clearing before replay
  cloak_vault MyApp.Vault                       # Optional: Encryption vault
  advisory_lock_key_default 2147483647          # Lock key for concurrency
  advisory_lock_key_generator MyApp.Generator   # Custom lock key generator
  
  persist_actor_primary_key :user_id, MyApp.User
  persist_actor_primary_key :system_actor, MyApp.SystemActor, attribute_type: :string
end
```

### replay_overrides section
```elixir
replay_overrides do
  replay_override MyApp.User, :create do
    versions [1]
    route_to MyApp.User, :old_create_v1
    route_to MyApp.UserV2, :create_v2    # Multiple routes allowed
  end
end
```

## Key Configuration Notes
- `only_actions` and `ignore_actions` are mutually exclusive
- Multiple actor types require `allow_nil?: true` (default)
- Version numbers start at 1, increment for breaking changes
- Advisory locks prevent race conditions in high-concurrency scenarios