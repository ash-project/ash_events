# AI Usage Rules Update Guide

## Overview

This guide provides instructions for creating and updating `usage-rules.md` files that help AI assistants work effectively with packages as dependencies. Unlike internal project documentation, usage rules focus exclusively on end-user patterns and best practices for AI assistants working on projects that use the package.

**File Location**: The `usage-rules.md` file should be created in the project's root folder (same level as README.md and package configuration files).

## Purpose and Scope

### What usage-rules.md Is For

Usage rules are consumed by AI assistants working on projects where this package is a dependency. The file should provide:
- Essential knowledge for correct package usage
- Common patterns and best practices
- Critical gotchas and constraints
- Quick reference information
- Troubleshooting guidance

### What usage-rules.md Is NOT For

Usage rules should **not** include:
- Internal package architecture details
- Development workflows for the package itself
- Comprehensive API documentation (link to external docs instead)
- Package maintenance or contribution guidelines
- Implementation details of package internals

## Content Structure and Guidelines

### Standard Structure

All usage-rules.md files should follow this structure:

```markdown
# PackageName Usage Rules

## Quick Reference
- Most critical information first
- Key configuration requirements
- Most common usage pattern

## Core Patterns
- Most common usage patterns (80% of use cases)
- Code examples with explanations
- Required configuration patterns

## Common Gotchas
- Frequent mistakes and how to avoid them
- Environment-specific issues
- Configuration pitfalls

## Advanced Features
- Optional but important capabilities
- Complex usage patterns
- Integration considerations

## Troubleshooting
- Common error patterns and solutions
- Debugging approaches
- When to consult external documentation

## External Resources
- Links to official documentation
- Important external guides
- Version compatibility information
```

### Content Guidelines

**Be Compact but Comprehensive:**
- Target 300-1100 lines total, depending on package complexity
- Use bullet points and scannable formatting
- Include practical examples
- Focus on actionable information

**Focus on End-User Patterns:**
- How to configure the package in a consuming project
- Common usage patterns and workflows
- Integration with other tools/frameworks
- Configuration options that matter to end users

**Highlight Critical Information:**
- Use **bold** for critical constraints
- Use ⚠️ for important warnings
- Use ✅ for recommended patterns
- Use ❌ for anti-patterns

**Include Practical Examples:**
- Show actual code, not pseudo-code
- Include file paths and directory structure when relevant
- Demonstrate common workflows
- Show both minimal and complete examples

## Project-Specific Considerations

When creating usage rules for AshEvents, focus on:

### Quick Reference Section
- Key requirement: Always set actor attribution
- Primary command: `mix test.reset` for database management
- Generated output: Event log entries with actor attribution

### Setup Section
- Event log resource creation with AshEvents.EventLog
- Clear records implementation for replay functionality
- Basic actor attribution configuration

### Core Patterns Section
- Event log resource configuration patterns
- Events extension usage on resources
- Actor attribution in all actions
- Clear records implementation
- Event replay workflow

### Common Gotchas Section
- **Critical**: Always set actor attribution - never omit actor
- Must implement clear_records_for_replay for replay functionality
- Use mix test.reset instead of mix ecto.reset
- Side effects must be implemented as separate tracked actions
- Version management required for schema evolution

### Advanced Features Section
- Version management and replay overrides
- Multiple actor type configuration
- Metadata handling and structure
- Performance optimization with UUIDv7
- Multi-tenant event handling

### Troubleshooting Section
- "Events not created" errors (missing Events extension or actor)
- "Replay failed" errors (incomplete clear_records implementation)
- Version management configuration issues
- Database migration and performance issues

## Writing Process

### 1. Planning Phase (Use TodoWrite)

Create a comprehensive plan with these todos:
- Research AshEvents documentation and current usage-rules.md
- Analyze event tracking patterns and common usage workflows
- Identify critical constraints and gotchas specific to AshEvents
- Plan content structure and examples
- Write draft content
- Review and refine for clarity and completeness
- Validate examples and commands

### 2. Research Phase

**Read Package Documentation:**
- README.md for installation and basic usage
- Current usage-rules.md for existing patterns
- Common workflow patterns in test files

**Analyze AshEvents Patterns:**
- Check event log resource configuration
- Examine Events extension usage patterns
- Identify actor attribution requirements

**Identify Key Constraints:**
- Actor attribution mandatory for all actions
- Clear records implementation required for replay
- Version management critical for schema evolution
- Database management using mix test.reset

### 3. Content Creation

**Start with Quick Reference:**
- 3-5 bullet points covering 80% of usage
- Key configuration step (Event log resource)
- Primary usage pattern (Events extension + actor attribution)

**Expand Each Section:**
- Include practical, tested examples
- Focus on patterns that work
- Highlight what commonly goes wrong
- Provide clear, actionable guidance

**Validate Examples:**
- Ensure all code examples are current and correct
- Test commands and configuration patterns
- Verify links to external documentation
- Check that examples match current package version

### 4. Review and Refinement

**Content Review:**
- Is the information accurate for current AshEvents version?
- Are examples practical and tested?
- Is the content focused on end-user patterns?
- Are common gotchas clearly highlighted?

**Structure Review:**
- Is the file scannable and well-organized?
- Are the most important patterns covered first?
- Is the content appropriately concise?
- Are advanced features clearly separated from basics?

**AI Assistant Perspective:**
- Would this provide sufficient context for an AI assistant?
- Are common failure modes and solutions covered?
- Is the information actionable and specific?
- Are external documentation links provided where needed?

## Quality Standards

### Required Elements

**Every usage-rules.md file must include:**
- Basic configuration requirements
- At least one complete usage example
- Common gotchas section
- Links to official documentation

**Content Requirements:**
- All examples must be tested and current
- All configuration patterns must be validated
- All commands must work with current package version
- All links must be functional

### Validation Process

**Before Publishing:**
1. Test all code examples in a real project
2. Verify all commands work as documented
3. Check that all links are functional
4. Ensure examples match current package version
5. Validate that gotchas are still relevant

**Quality Checks:**
- File length appropriate (300-1100 lines)
- Content focused on end-user patterns
- Examples are practical and complete
- Gotchas are clearly highlighted
- Structure follows established pattern

## Maintenance Guidelines

### When to Update

Update usage-rules.md when:
- AshEvents version changes significantly
- Configuration patterns change
- New common gotchas are discovered
- Core usage patterns evolve
- External documentation links change

### Update Process

1. **Review Current Content**: Check accuracy against current AshEvents version
2. **Update Examples**: Ensure all code examples work with current version
3. **Validate Commands**: Test all commands and configuration patterns
4. **Check Links**: Verify external documentation links are current
5. **Update Gotchas**: Add new common issues, remove obsolete ones

### Maintenance Schedule

- **Major Version Updates**: Full review and update required
- **Minor Version Updates**: Review examples and gotchas
- **Patch Updates**: Verify that current content is still accurate
- **Quarterly**: Review external links and validate examples

## Integration with Project Documentation

### Relationship to CLAUDE.md

Usage rules complement but don't replace project-specific documentation:
- **CLAUDE.md**: Internal project patterns, workflows, and constraints
- **usage-rules.md**: Package-specific usage patterns for AI assistants
- **AI documentation**: Project-specific AI assistant guidance

### Cross-Reference Strategy

- Usage rules should link to official AshEvents documentation
- Internal documentation should reference usage rules for AshEvents patterns
- Keep usage rules focused on the package, not project-specific integration

---

**Last Updated**: 2025-07-18
**Next Review**: When AshEvents reaches next major version