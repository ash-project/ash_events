# AshEvents Internal Development Changelog

## Overview

This changelog provides context for the current state of internal AshEvents development and tracks the evolution of implementation approaches. It helps agents understand why certain patterns exist and the reasoning behind architectural decisions.

⚠️ **Note**: This tracks internal development decisions. For user-facing changes, see [CHANGELOG.md](../CHANGELOG.md).

## Entry Format

Each entry includes:
- **Date**: When the change was made
- **Change**: What was modified/added/removed internally
- **Context**: Why the change was necessary for development
- **Files**: Which files were affected
- **Impact**: How this affects future internal development
- **Key Insights**: Lessons learned or patterns discovered

---

## 2025-09-19

### Agent Documentation Structure Scaffolding
**Change**: Created comprehensive agent documentation structure following scaffolding framework
**Context**: Needed proper internal development documentation separated from consumer documentation (usage-rules.md)
**Files**: `agent-docs/index.md`, `agent-docs/changelog.md`, `agent-docs/` directory structure
**Impact**: Agents now have proper guidance for working ON AshEvents development vs using AshEvents as dependency
**Key Insights**: Clear separation between consumer docs (usage-rules.md) and developer docs (agent-docs/) significantly improves development workflow

### Documentation Focus Clarification
**Change**: Clarified that usage-rules.md is consumer documentation, not internal development guidance
**Context**: Previous AGENTS.md incorrectly referenced usage-rules.md for internal development tasks
**Files**: `agent-docs/index.md`, updated understanding of documentation structure
**Impact**: Agents now correctly understand the distinction between internal development and consumer usage
**Key Insights**: Documentation scope must be clearly defined - internal vs external usage have completely different needs

---

## 2025-09-19 (Continued)

### Changed Attributes Tracking Implementation
**Change**: Added comprehensive changed attributes tracking and replay functionality to AshEvents core
**Context**: Event replay was incomplete for resources with business logic that modified attributes beyond the original input parameters. Default values, auto-generated attributes (slugs, UUIDs, computed fields), and attributes modified by Ash changes/extensions were not being captured in events, causing incomplete state reconstruction during replay. This is a critical gap for real-world event sourcing applications where business logic transforms input data.
**Files**:
- `lib/event_log/transformers/add_attributes.ex` - Added `changed_attributes` field to event resources
- `lib/events/events.ex` - Added `replay_non_input_attribute_changes` DSL option
- `lib/events/changes/apply_changed_attributes.ex` - New change module for applying changed attributes during replay
- `lib/events/action_wrapper_helpers.ex` - Modified to capture changed attributes during event creation
- `lib/event_log/replay.ex` - Enhanced to pass changed attributes context during replay
- `test/ash_events/changed_attributes_test.exs` - Comprehensive test coverage
**Impact**: AshEvents now supports complete state reconstruction for complex business logic scenarios. This enables proper event sourcing for applications with extensive attribute transformations, default value applications, and computed field generation. The two-strategy approach (`:force_change` vs `:as_arguments`) provides flexibility for different replay requirements.
**Key Insights**:
- Event sourcing requires capturing not just input parameters but also all business logic transformations
- Separating original input (`event.data`) from business logic changes (`event.changed_attributes`) provides clear audit trails
- Context propagation in Ash action pipelines requires careful timing - changes must have context available from the start
- Both atom and string key handling is critical for form compatibility in web applications
- Testing replay functionality requires proper database cleanup patterns to avoid interference between create/destroy events

---

## 2025-08-21 (Inferred from CHANGELOG.md)

### Parameter Filtering Enhancement
**Change**: Implemented filtering to ignore non-attribute/argument params when creating events
**Context**: Event creation was failing when extra parameters were present that weren't part of action schema
**Files**: Likely `lib/events/*_action_wrapper.ex` files and related event creation logic
**Impact**: More robust event creation that handles real-world usage patterns with extra parameters
**Key Insights**: Event creation needs to be forgiving of parameter mismatches to work with complex applications

---

## 2025-07-17 (Inferred from CHANGELOG.md)

### Attribute/Argument Casting Improvements
**Change**: Enhanced casting of all attributes and arguments before event creation
**Context**: Events were being created with improperly cast values, causing issues during replay
**Files**: Event creation logic in action wrappers
**Impact**: More reliable event replay due to proper data type consistency
**Key Insights**: Proper type casting is critical for event replay functionality - data must be consistent

### Atom Conversion Safety
**Change**: Added safe atom conversion logic before dumping values
**Context**: Runtime errors when trying to convert values to atoms that didn't exist
**Files**: Event serialization/deserialization logic
**Impact**: More robust event handling with complex data types
**Key Insights**: Atom safety is crucial in event systems - need defensive programming for dynamic data

---

## 2025-07-02 (Inferred from CHANGELOG.md)

### Usage Rules Package Inclusion
**Change**: Added usage-rules.md to package files in mix.exs
**Context**: Consumer documentation wasn't being included in releases
**Files**: `mix.exs` package files configuration
**Impact**: Consumers now have proper documentation included with package installations
**Key Insights**: Consumer documentation must be explicitly included in package files for distribution

---

## 2025-06-25 (Inferred from CHANGELOG.md)

### Replay Change Module Improvements
**Change**: Enhanced handling of options templates in replay change modules
**Context**: Complex change modules with templates weren't replaying correctly
**Files**: Replay logic in `lib/event_log/replay.ex` and change wrapper functionality
**Impact**: More sophisticated change modules can now be properly replayed
**Key Insights**: Replay functionality must handle all possible change module patterns, including templated options

### Validation Module Replay Handling
**Change**: Improved validation module handling in replay change wrapper
**Context**: Validation modules during replay were causing issues with event processing
**Files**: `lib/events/replay_change_wrapper.ex` and related replay logic
**Impact**: Event replay now properly handles resources with validation modules
**Key Insights**: Replay must account for all Ash resource features, including validations

---

## Development Pattern Evolution

### Action Wrapper Architecture
**Current State**: Action wrappers (`create_action_wrapper.ex`, `update_action_wrapper.ex`, `destroy_action_wrapper.ex`) handle event creation
**Key Patterns**:
- Common functionality in `action_wrapper_helpers.ex`
- Parameter filtering and validation before event creation
- Consistent actor attribution handling
- Safe type casting and data serialization

### Replay Functionality Architecture
**Current State**: Centralized replay in `lib/event_log/replay.ex` with sophisticated change handling
**Key Patterns**:
- Replay change wrapper for handling complex change modules
- Template option handling for dynamic change configurations
- Validation module integration during replay
- Clear records implementation for clean replay state

### Testing Architecture
**Current State**: Comprehensive test coverage with realistic test resources
**Key Patterns**:
- Test resources in `test/support/` mirror real-world usage
- Specific test files for each feature area
- Mix aliases for database management (`mix test.reset`, etc.)
- Test environment configuration in `mix.exs`

### DSL Extension Architecture
**Current State**: Two main extensions (EventLog and Events) with transformers and verifiers
**Key Patterns**:
- DSL definitions in main extension files
- Implementation logic in transformers
- Validation in verifiers
- Generated documentation from DSL definitions

---

## Entry Guidelines

### What to Include
- **Architectural decisions** that affect internal development
- **Implementation pattern changes** that change how code should be written
- **Internal bug fixes** that reveal important development insights
- **Development workflow improvements** and tool changes
- **Testing pattern evolution** and quality improvements
- **Build and deployment changes** affecting development

### What to Exclude
- **User-facing feature additions** (these go in CHANGELOG.md)
- **Routine maintenance** without architectural impact
- **External dependency updates** without internal impact
- **Documentation updates** without workflow changes

### Writing Style
- **Focus on development impact** rather than user impact
- **Include technical reasoning** for architectural decisions
- **Reference specific files and patterns** for future development
- **Highlight insights** that apply to future internal work
- **Use present tense** for current state descriptions
- **Use past tense** for completed changes

### Update Frequency
- **After significant architectural decisions** affecting development workflow
- **When development patterns change** or evolve
- **After complex bug fixes** that reveal important insights
- **When build or testing processes change**
- **After major internal refactoring** efforts

---

**Last Updated**: 2025-01-25
**Focus**: Internal development context and decisions
**Next Review**: After next major internal development milestone
