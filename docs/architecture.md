# AshEvents Architecture

## Core Components

### Extensions
- **AshEvents.Events**: Extension for resources to enable event tracking
- **AshEvents.EventLog**: Extension for the event log resource that stores events

### Key Modules
- **Action Wrappers**: `lib/events/*_action_wrapper.ex` - Intercept and wrap CRUD actions
- **Event Replay**: `lib/event_log/replay.ex` - Handles event replay functionality
- **Advisory Locks**: `lib/event_log/advisory_lock_*` - Manages concurrent access

### Data Flow
1. Resource action triggered → Action wrapper intercepts
2. Event created in event log → Original action executed
3. During replay: Events loaded chronologically → Actions re-executed with hooks skipped

### DSL Configuration
- `events` section: Configure which actions to track, versions, metadata
- `event_log` section: Configure storage, actors, encryption, replay behavior
- `replay_overrides` section: Route specific event versions to different actions

### Key Features
- **Event Versioning**: Track schema changes over time
- **Actor Attribution**: Store who performed each action
- **Advisory Locking**: Prevent race conditions during concurrent operations
- **Selective Replay**: Replay to specific points in time or event IDs
- **Hook Skipping**: Lifecycle hooks bypassed during replay to prevent side effects