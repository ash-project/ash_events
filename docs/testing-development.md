# Testing & Development

## Test Commands
```bash
# Database operations
mix test.create          # Create test database
mix test.migrate         # Run migrations
mix test.reset          # Drop, create, migrate
mix test.generate_migrations  # Generate new migrations

# Code quality
mix credo --strict      # Linting
mix dialyzer           # Type checking
mix sobelow            # Security analysis
mix ex_check           # Run all checks
```

## Test Structure
- `test/support/` - Test resources and helpers
- `test/support/accounts/` - User, Org resources with events
- `test/support/events/` - Event log resources
- `test/ash_events_test.exs` - Main test suite

## Key Test Resources
- `Events.EventLog` - Basic event log
- `Events.EventLogCloaked` - Encrypted events
- `Events.EventLogUuidv7` - UUIDv7 primary keys
- `Accounts.User` - Standard user with events
- `Accounts.UserEmbedded` - User with embedded attributes

## Development Workflow
1. Make changes to core library files
2. Update test resources if needed
3. Run `mix test` to verify functionality
4. Run `mix credo --strict` for code quality
5. Generate migrations with `mix test.generate_migrations` if schema changes
6. Update documentation if API changes

## Common Test Patterns
```elixir
# Test event creation
user = create_user()
events = Event |> Ash.read!()
assert length(events) == 1

# Test replay
Event |> Ash.ActionInput.for_action(:replay, %{}) |> Ash.run_action!()
replayed_users = User |> Ash.read!()
```