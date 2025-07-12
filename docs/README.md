# AshEvents Documentation for AI Assistants

This documentation is optimized for AI assistants working on the AshEvents project. Files are designed to be concise and focused on specific topics to minimize context window usage.

## Documentation Structure

### Quick Start
- **[quick-reference.md](quick-reference.md)** - Essential setup patterns and common operations
- **[core-concepts.md](core-concepts.md)** - Key concepts and terminology

### Technical Reference  
- **[architecture.md](architecture.md)** - System architecture and data flow
- **[dsl-options.md](dsl-options.md)** - Complete DSL configuration reference
- **[file-locations.md](file-locations.md)** - Where to find specific functionality

### Development
- **[testing-development.md](testing-development.md)** - Test commands and development workflow
- **[troubleshooting.md](troubleshooting.md)** - Common issues and debugging

## Usage Guidelines for AI Assistants

1. **Start with quick-reference.md** for basic setup and operations
2. **Consult dsl-options.md** for configuration details
3. **Use file-locations.md** to locate specific implementation files
4. **Reference architecture.md** for understanding system design
5. **Check troubleshooting.md** for common issues

## Project Overview
AshEvents is an Elixir library that adds event sourcing and audit logging capabilities to Ash Framework resources. It provides:

- Automatic event logging for resource actions
- Event replay functionality for rebuilding state
- Version management for schema evolution
- Actor attribution for tracking who performed actions
- Advisory locking for concurrency control

The library consists of two main extensions:
- `AshEvents.Events` - Added to resources that should generate events
- `AshEvents.EventLog` - Added to the resource that stores events

Events are created automatically when actions are performed, and can be replayed to rebuild application state or used purely for audit logging purposes.