# AshEvents AI Assistant Documentation Index

## Quick Access Guide

This index helps AI assistants quickly find the most relevant documentation for specific tasks, optimizing context window usage.

## Core Files (Always Start Here)

| File | Purpose | When to Use |
|------|---------|-------------|
| [CLAUDE.md](../CLAUDE.md) | Main AI assistant guide | Start here for project overview, critical rules, and workflows |
| [ai-quick-reference.md](ai-quick-reference.md) | Quick commands and patterns | Need immediate help with common tasks |
| [ai-validation-safety.md](ai-validation-safety.md) | Testing and safety procedures | Before making any changes or troubleshooting |
| [ai-changelog.md](ai-changelog.md) | Context and evolution | Understanding why current patterns exist and architectural decisions |

## Task-Specific Documentation

### Implementation Tasks
| Task | Primary Documentation | Supporting Files |
|------|----------------------|------------------|
| **Event Log Resource Setup** | [ai-implementation-guide.md](ai-implementation-guide.md) | [test/support/events/](../test/support/events/) |
| **Adding Event Tracking** | [ai-quick-reference.md](ai-quick-reference.md) | [usage-rules.md](../usage-rules.md), [test/support/accounts/](../test/support/accounts/) |
| **Event Replay Implementation** | [ai-implementation-guide.md](ai-implementation-guide.md) | [test/support/events/clear_records.ex](../test/support/events/clear_records.ex) |
| **Version Management** | [ai-implementation-guide.md](ai-implementation-guide.md) | [ai-quick-reference.md](ai-quick-reference.md) |
| **Actor Attribution** | [ai-implementation-guide.md](ai-implementation-guide.md) | [test/support/accounts/user.ex](../test/support/accounts/user.ex) |
| **Metadata Handling** | [ai-implementation-guide.md](ai-implementation-guide.md) | [test/support/accounts/](../test/support/accounts/) |
| **Side Effects & Lifecycle** | [ai-implementation-guide.md](ai-implementation-guide.md) | [test/support/accounts/before_action_update_org_details.ex](../test/support/accounts/before_action_update_org_details.ex) |
| **Test Organization** | [ai-quick-reference.md](ai-quick-reference.md) | [test/ash_events_test.exs](../test/ash_events_test.exs), [test/support/](../test/support/) |

### Troubleshooting
| Issue Type | Primary Documentation | Emergency Reference |
|------------|----------------------|-------------------|
| **Environment Issues** | [ai-troubleshooting.md](ai-troubleshooting.md) | [CLAUDE.md](../CLAUDE.md) (Critical Rules) |
| **Event Tracking Issues** | [ai-troubleshooting.md](ai-troubleshooting.md) | [ai-quick-reference.md](ai-quick-reference.md) |
| **Replay Issues** | [ai-troubleshooting.md](ai-troubleshooting.md) | [ai-implementation-guide.md](ai-implementation-guide.md) |
| **Database Issues** | [ai-troubleshooting.md](ai-troubleshooting.md) | [ai-validation-safety.md](ai-validation-safety.md) |

### Deep Dives and Insights
| Topic | Primary Documentation | When to Read |
|-------|----------------------|--------------|
| **Architecture Decisions** | [ai-implementation-insights.md](ai-implementation-insights.md) | Understanding design choices |
| **Context and Evolution** | [ai-changelog.md](ai-changelog.md) | Understanding why current patterns exist |
| **Performance Patterns** | [ai-implementation-insights.md](ai-implementation-insights.md) | Optimizing implementations |

## File Size Reference (Context Window Planning)

### Small Files (< 500 lines) - Efficient for AI
- [ai-quick-reference.md](ai-quick-reference.md) (~300 lines)
- [ai-changelog.md](ai-changelog.md) (~150 lines)
- [ai-validation-safety.md](ai-validation-safety.md) (~250 lines)

### Medium Files (500-800 lines) - Manageable
- [CLAUDE.md](../CLAUDE.md) (~600 lines)
- [usage-rules.md](../usage-rules.md) (~472 lines)

### Large Files (> 1000 lines) - Use Sparingly
⚠️ **Context Window Warning**: These files consume significant context space
- [ai-implementation-guide.md](ai-implementation-guide.md) (~1200 lines)
- [ai-troubleshooting.md](ai-troubleshooting.md) (~800 lines)
- [ai-implementation-insights.md](ai-implementation-insights.md) (~900 lines)

## Project-Specific File References

### Core Implementation Files
- **Event Log Extension**: `lib/event_log/event_log.ex` - Core event log functionality
- **Events Extension**: `lib/events/events.ex` - Resource event tracking
- **Action Wrappers**: `lib/events/create_action_wrapper.ex`, `lib/events/update_action_wrapper.ex`, `lib/events/destroy_action_wrapper.ex`
- **Replay Logic**: `lib/event_log/replay.ex` - Event replay implementation

### Test Support Files
- **Event Log Examples**: `test/support/events/event_log.ex` - Main event log resource
- **Clear Records**: `test/support/events/clear_records.ex` - Clear records implementation
- **User Resource**: `test/support/accounts/user.ex` - Example resource with events
- **Test Configuration**: `test/support/test_repo.ex` - Database configuration

### Configuration Files
- **Mix Project**: `mix.exs` - Project configuration and dependencies
- **Database Config**: `config/test.exs` - Test database configuration
- **Environment Config**: `config/config.exs` - Application configuration

## Legacy Documentation (Archived)

The following files have been moved to `docs/legacy/` and should not be read:
- None currently - this is a new documentation structure

## Recommended Reading Patterns

### For Quick Tasks (1-2 steps)
1. [ai-quick-reference.md](ai-quick-reference.md)
2. [CLAUDE.md](../CLAUDE.md) (if needed)

### For Implementation Tasks (3+ steps)
1. [CLAUDE.md](../CLAUDE.md) (Critical Rules)
2. [ai-implementation-guide.md](ai-implementation-guide.md) (Primary)
3. [ai-validation-safety.md](ai-validation-safety.md) (Testing)

### For Troubleshooting
1. [CLAUDE.md](../CLAUDE.md) (Environment rules)
2. [ai-troubleshooting.md](ai-troubleshooting.md) (Issue-specific)
3. [ai-validation-safety.md](ai-validation-safety.md) (Validation)

### For Understanding Context
1. [ai-changelog.md](ai-changelog.md) (Why current patterns exist)
2. [ai-implementation-insights.md](ai-implementation-insights.md) (Deep architectural insights)

### For Deep Understanding
1. [ai-implementation-guide.md](ai-implementation-guide.md)
2. [ai-implementation-insights.md](ai-implementation-insights.md)

## AshEvents-Specific Patterns

### Event Log Resource Setup
- **Must Read**: [usage-rules.md](../usage-rules.md) sections 1-2
- **Example**: [test/support/events/event_log.ex](../test/support/events/event_log.ex)
- **Key Requirement**: Always implement `clear_records_for_replay` module

### Events Extension Usage
- **Must Read**: [usage-rules.md](../usage-rules.md) section 3
- **Example**: [test/support/accounts/user.ex](../test/support/accounts/user.ex)
- **Key Requirement**: Reference event log resource in `events` block

### Event Replay Implementation
- **Must Read**: [usage-rules.md](../usage-rules.md) section 5
- **Example**: [test/support/events/clear_records.ex](../test/support/events/clear_records.ex)
- **Key Requirement**: Understand lifecycle hooks are skipped during replay

### Version Management
- **Must Read**: [usage-rules.md](../usage-rules.md) "Version Management and Replay Overrides"
- **Key Requirement**: Use `current_action_versions` and `replay_overrides` for schema evolution

### Actor Attribution
- **Must Read**: [usage-rules.md](../usage-rules.md) "Actor Attribution"
- **Key Requirement**: Always set actor when performing actions

## Future Structure (Post-Restructuring)

After Phase 2-4 implementation, this index will reference:
- `docs/implementation/` - Focused implementation guides (200-250 lines each)
- `docs/troubleshooting/` - Focused troubleshooting guides (200-250 lines each)  
- `docs/insights/` - Focused insight documents (300-400 lines each)
- `docs/quick-guides/` - Task-specific guides (100-150 lines each)
- `docs/reference/` - Quick reference cards (50-150 lines each)

---

**Last Updated**: 2025-07-18
**Documentation Restructuring**: Phase 1 Complete