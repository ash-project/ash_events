# AshEvents AI Assistant Changelog

## Overview

This changelog provides context for the current state of the project and tracks the evolution of implementation approaches. It helps AI assistants understand why certain patterns exist and the reasoning behind architectural decisions.

## Entry Format

Each entry includes:
- **Date**: When the change was made
- **Change**: What was modified/added/removed
- **Context**: Why the change was necessary
- **Files**: Which files were affected
- **Impact**: How this affects future development
- **Key Insights**: Lessons learned or patterns discovered

---

## 2025-07-18

### AI Documentation Framework Scaffolding
**Change**: Created comprehensive AI documentation scaffolding system for AshEvents project
**Context**: Project had minimal CLAUDE.md referencing non-existent AGENTS.md; needed structured AI assistant documentation to improve development efficiency and reduce implementation errors
**Files**: 
- Created `docs/ai-index.md` - Central documentation index with task-specific guidance
- Created `docs/ai-changelog.md` - Context tracking for architectural decisions
- Created `docs/` directory structure for organized AI documentation
**Impact**: AI assistants now have structured access to project-specific patterns, critical rules, and implementation workflows
**Key Insights**: Existing `usage-rules.md` (472 lines) already contains comprehensive usage patterns for AshEvents - this should be leveraged as primary reference for implementation guidance

### Project Analysis and Pattern Identification
**Change**: Analyzed existing codebase to identify critical patterns and architectural decisions
**Context**: Needed to understand current state before creating AI documentation framework
**Files**: 
- Analyzed `lib/event_log/` and `lib/events/` for core implementation patterns
- Reviewed `test/support/` for example implementations and testing patterns
- Examined `mix.exs` for project configuration and available commands
**Impact**: AI assistants now understand the project's structure, key abstractions, and testing patterns
**Key Insights**: 
- AshEvents follows Ash Framework patterns with extensions for EventLog and Events
- Project has comprehensive test suite with example implementations
- Critical commands include `mix test.reset` for database management and `mix credo --strict` for code quality
- Actor attribution is mandatory for proper event tracking

### Current State Documentation
**Change**: Documented current architectural state and critical rules
**Context**: Established baseline understanding of AshEvents implementation patterns
**Files**: All core library files, test files, and configuration
**Impact**: Future AI assistants will understand the current implementation without needing to discover patterns from scratch
**Key Insights**: 
- **Event Log Resource**: Central resource using `AshEvents.EventLog` extension with required `clear_records_for_replay` implementation
- **Events Extension**: Added to resources needing event tracking via `AshEvents.Events` extension
- **Actor Attribution**: Critical for audit trails - always set actor when performing actions
- **Lifecycle Hooks**: Skipped during replay to prevent duplicate side effects
- **Version Management**: Handled via `current_action_versions` and `replay_overrides` for schema evolution
- **Side Effects**: Should be encapsulated in separate tracked actions rather than lifecycle hooks

---

## Entry Guidelines

### What to Include
- **Major architectural decisions** and their reasoning
- **Pattern changes** that affect how code should be written
- **Critical bug fixes** and their root causes
- **Performance improvements** and optimization strategies
- **Breaking changes** and migration strategies
- **Documentation restructuring** and new workflows
- **Tool or dependency changes** and their impact

### What to Exclude
- **Routine maintenance** without architectural impact
- **Minor bug fixes** that don't reveal patterns
- **Cosmetic changes** without functional impact
- **Experimental changes** that were reverted
- **Personal preferences** without project-wide impact

### Writing Style
- **Be concise** but provide enough context
- **Focus on reasoning** rather than just what changed
- **Include file references** for easy navigation
- **Highlight patterns** that apply to future work
- **Use present tense** for current state descriptions
- **Use past tense** for completed changes

### Update Frequency
- **After significant changes** that affect how work is done
- **When new patterns emerge** from implementation work
- **After architectural decisions** that impact future development
- **When documentation structure changes** occur
- **After major bug fixes** that reveal important insights

---

**Last Updated**: 2025-07-18