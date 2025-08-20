# AI README Update Guide

## Overview

This guide provides comprehensive instructions for creating and maintaining an excellent README.md file for your project. The README serves as the primary entry point for end-users and is crucial for project adoption and success.

## 🚨 CRITICAL: END-USER FOCUS ONLY

**MANDATORY RULE**: The README must ONLY contain information relevant to end-users who want to USE the project, not develop it.

### ❌ AVOID These Internal Details:
- Development setup for contributing to the project
- Internal testing procedures for the project itself
- Migration guides (unless the project is specifically a replacement tool)
- Internal implementation details
- Contributor development workflows
- Project maintenance procedures

### ✅ INCLUDE End-User Content:
- How to install and use the project
- How to test applications that use the project
- How to configure the project for different use cases
- Performance considerations for production use
- Troubleshooting user issues
- Contributing guidelines (brief, with links to detailed guides)

## Purpose and Scope

### What a Great README Should Achieve

A top-notch README should:
- **Immediately communicate value**: Users should understand what the project does and why they need it within seconds
- **Provide quick wins**: Users should be able to get started successfully within minutes
- **Build confidence**: Clear examples and comprehensive documentation reduce friction
- **Support different user types**: From beginners to advanced users seeking specific features
- **Drive adoption**: Compelling presentation encourages usage and contribution

### Target Audience

The README targets several distinct user groups:
- **Elixir developers** looking for event sourcing solutions in the Ash ecosystem
- **Full-stack developers** building applications that need audit trails and event replay
- **Teams** evaluating event sourcing solutions for their specific needs
- **DevOps engineers** implementing event-driven architectures

**NOT the target audience**:
- Contributors who want to work on the project itself (they should read CLAUDE.md and other dev docs)
- Maintainers looking for internal procedures (they should read internal documentation)

## Content Structure and Guidelines

### Essential README Structure

All README files should follow this proven structure:

```markdown
# Project Title

Brief, compelling description (1-2 sentences)

## Why [Project Name]?

Value proposition and key benefits

## Features

Core capabilities and benefits

## Quick Start

Minimal working example (copy-paste ready)

## Installation

Quick installation instructions

## Usage

Comprehensive examples and patterns

## Configuration

Configuration options and customization

## Advanced Features

Complex usage patterns and edge cases

## Event Log Structure (project-specific)

What events look like

## How It Works

High-level explanation of the approach

## Best Practices

End-user best practices for production use

## Troubleshooting

Common user issues and solutions

## Documentation

Links to comprehensive documentation

## Community

Contributing guidelines and support channels

## Reference

API documentation links
```

### 🚨 SECTIONS TO AVOID

**Never include these sections in end-user README:**
- **Migration Guide** (unless project is specifically designed as a replacement)
- **Development Setup** (for working on the project itself)
- **Internal Testing** (testing the project, not applications using it)
- **Maintenance Procedures** (internal project maintenance)
- **Architecture Decisions** (internal design choices)
- **Performance Internals** (internal implementation details)

### Content Quality Standards

**1. Clarity and Accessibility**
- Use clear, jargon-free language
- Provide context for technical terms
- Include visual examples where helpful
- Structure content for easy scanning

**2. Practical Examples**
- Show real, working code examples
- Include complete, copy-paste ready snippets
- Demonstrate common use cases first
- Progress from simple to complex scenarios

**3. Comprehensive Coverage**
- Cover all major features and capabilities
- Include edge cases and gotchas
- Provide troubleshooting guidance
- Link to additional resources

**4. Professional Presentation**
- Use consistent formatting and style
- Include proper headings and organization
- Add visual elements (badges, diagrams) when helpful
- Maintain up-to-date information

## Project-Specific Guidelines

### Project Title and Description

**Title**: Should be clear and memorable
```markdown
# AshEvents

An extension for the Ash Framework that provides event capabilities for Ash resources, enabling complete audit trails and powerful event replay functionality.
```

**Description**: Expand on the value proposition
```markdown
AshEvents provides automatic event logging for Ash resources, ensuring complete audit trails and enabling powerful replay functionality. Track all changes, rebuild state from events, and handle schema evolution with version management.
```

### Installation Section

**Must Include**:
- Hex package configuration
- Required Elixir and Ash versions
- Database setup requirements

**Template**:
```markdown
## Installation

Add `ash_events` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_events, "~> 0.4.2"}
  ]
end
```

**Requirements:**
- Elixir ~> 1.15
- Ash ~> 3.5
- PostgreSQL database
```

### Quick Start Section

**Critical Requirements**:
- Complete, working example
- Copy-paste ready code
- Shows immediate value
- Takes under 5 minutes to implement

**Template**:
```markdown
## Quick Start

1. **Create an Event Log Resource:**

```elixir
defmodule MyApp.Events.Event do
  use Ash.Resource,
    extensions: [AshEvents.EventLog]

  event_log do
    clear_records_for_replay MyApp.Events.ClearAllRecords
    primary_key_type Ash.Type.UUIDv7
    persist_actor_primary_key :user_id, MyApp.User
  end
end
```

2. **Add Event Tracking to Resources:**

```elixir
defmodule MyApp.User do
  use Ash.Resource,
    extensions: [AshEvents.Events]

  events do
    event_log MyApp.Events.Event
  end
end
```

3. **Use with Actor Attribution:**

```elixir
user = User
|> Ash.Changeset.for_create(:create, %{name: "John"})
|> Ash.create!(actor: current_user)
```
```

### Features Section

**Structure**:
- Lead with most compelling features
- Use bullet points for scannability
- Include brief explanations
- Highlight unique capabilities

**Template**:
```markdown
## Features

- **🔥 Automatic Event Logging** - Records all resource changes automatically
- **🛡️ Complete Audit Trails** - Track who did what and when
- **🚀 Event Replay** - Rebuild state by replaying events chronologically
- **📦 Version Management** - Handle schema evolution with replay overrides
- **🏢 Actor Attribution** - Support multiple actor types (users, systems, etc.)
- **⚡ High Performance** - Optimized for high-volume event logging
- **🔧 Flexible Configuration** - Customize event handling for your needs
```

### Usage Section

**Must Include**:
- Event log resource setup
- Events extension configuration
- Actor attribution patterns
- Event replay examples
- Version management examples

**Progressive Examples**:
```markdown
## Usage

### Basic Event Tracking

[Simple setup examples]

### Event Replay

[Replay functionality examples]

### Advanced Configuration

[Complex scenarios and patterns]

### Error Handling

[How to handle errors and edge cases]
```

### Configuration Section

**Should Cover**:
- Event log resource configuration options
- Events extension configuration
- Actor attribution setup
- Performance optimization settings

### Advanced Features Section

**Include**:
- Version management and replay overrides
- Multiple actor type configuration
- Metadata handling and structure
- Performance optimization techniques
- Multi-tenant event handling

### API Reference Section

**Structure**:
- Link to generated HexDocs
- Key DSL configurations
- Important function signatures
- Configuration options

### Examples Section

**Include**:
- Real-world scenarios
- Complete project examples
- Integration patterns
- Common use cases

### Testing Section (End-User Focus)

**✅ INCLUDE - Testing Applications That Use the Project**:
- How to test resources with event tracking
- Testing event creation and replay in user applications
- Test setup patterns for applications using the project
- Testing best practices for end-users

**❌ AVOID - Testing the Project Itself**:
- Running the project's test suite
- Contributing testing procedures
- Internal testing workflows
- Quality assurance procedures for the project

### Performance Section (End-User Focus)

**✅ INCLUDE - Production Usage Considerations**:
- Performance implications for end-users
- Configuration for high-volume scenarios
- Database optimization for event logs
- Monitoring and alerting recommendations

**❌ AVOID - Internal Implementation Details**:
- Internal algorithm performance
- Development benchmarking procedures
- Internal optimization strategies
- Code profiling techniques

### Migration Guide Rules

**✅ INCLUDE Migration Guides When**:
- Project is specifically designed as a replacement for another tool
- Project provides migration utilities or scripts
- Common migration pattern exists that users request

**❌ AVOID Migration Guides When**:
- Project is an addition to existing ecosystems (like AshEvents to Ash)
- No direct replacement relationship exists
- Migration would be project-specific and not generalizable

**AshEvents Specific**: AshEvents is an addition to Ash projects, not a replacement for other tools. Users ADD AshEvents to their existing Ash resources, they don't migrate FROM other tools TO AshEvents.

## Writing Process

### 1. Planning Phase (Use TodoWrite)

Create a comprehensive plan with these todos:
- Read current README.md structure and content
- Analyze user feedback and common questions
- Research competitor README files
- Identify missing content and improvement opportunities
- Plan new structure and content sections
- Draft core sections with examples
- Review and refine for clarity and completeness
- Validate all code examples and commands
- Test installation and quick start instructions

### 2. Content Development

**Start with Core Value Proposition**:
- What problem does AshEvents solve?
- Why should users choose it over alternatives?
- What makes it unique and valuable?

**Build Progressive Examples**:
- Start with simplest possible example
- Add complexity gradually
- Show complete, working code
- Include expected outputs

**Address Common Questions**:
- How does it work with existing Ash projects?
- What are the limitations?
- How does it compare to alternatives?
- What about performance and resource usage?

### 3. Example Validation

**Critical Requirements**:
- All code examples must work with current version
- All commands must execute successfully
- All configuration patterns must be tested
- All links must be functional

**Testing Process**:
1. Create fresh project environment
2. Follow installation instructions exactly
3. Execute all code examples
4. Verify all generated outputs work correctly
5. Test all commands and options
6. Validate all configuration patterns

### 4. Visual Enhancement

**Include**:
- Badges for version, build status, documentation
- Code syntax highlighting
- Consistent formatting
- Clear section headings
- Visual separators where helpful

## Quality Standards

### Required Elements

**Every README must include**:
- Clear value proposition
- Complete installation instructions
- Working quick start example
- Comprehensive usage examples
- Configuration documentation
- Link to full documentation
- Contributing guidelines
- License information

### Content Requirements

**Code Examples**:
- All examples must be tested and current
- Include complete imports and setup
- Show expected outputs where relevant
- Use realistic data and scenarios

**Documentation Links**:
- Link to HexDocs
- Reference specific guides and tutorials
- Include troubleshooting resources
- Point to community resources

### Technical Accuracy

**Validation Checklist**:
- [ ] All dependencies are correct
- [ ] All version requirements are accurate
- [ ] All code examples execute successfully
- [ ] All configuration options are documented
- [ ] All links are functional
- [ ] All commands work as documented

## Project-Specific Considerations

### Unique Selling Points

**Emphasize**:
- Automatic event logging vs manual alternatives
- End-to-end audit trails across workflows
- Integration with Ash Framework ecosystem
- Performance and optimization benefits
- Built-in version management capabilities

### Common User Journeys

**Address These Scenarios**:
- New Ash project adding event tracking
- Existing project migrating from other audit solutions
- Team adopting event sourcing approach
- Large application with complex requirements
- Special environment requirements

### Integration Context

**Show Integration With**:
- Ash Framework resources and actions
- AshPostgres for database operations
- Phoenix applications for web interfaces
- LiveView for real-time event monitoring
- CI/CD pipelines for testing

## Maintenance Guidelines

### When to Update

Update README when:
- New major features are added
- Installation process changes
- API interface changes
- New configuration options are added
- User feedback indicates confusion
- Dependencies or requirements change

### Update Process

**Standard Workflow**:
1. **Identify Changes**: Review what has changed since last update
2. **Update Examples**: Ensure all code examples work with current version
3. **Validate Commands**: Test all commands and configuration options
4. **Check Links**: Verify all external links are functional
5. **Test Journey**: Follow installation and quick start as new user
6. **Review Feedback**: Address any outstanding user questions or confusion

### Quality Checks

**Before Publishing**:
- [ ] All code examples tested in clean environment
- [ ] All commands execute successfully
- [ ] All links are functional
- [ ] Installation instructions are complete
- [ ] Quick start example works end-to-end
- [ ] Configuration options are documented
- [ ] Advanced features are covered
- [ ] Troubleshooting guidance is current
- [ ] **END-USER FOCUS VERIFIED**: No internal project details included
- [ ] **TESTING CONTENT VERIFIED**: Only includes testing applications, not testing the project
- [ ] **PERFORMANCE CONTENT VERIFIED**: Only includes end-user considerations, not internals
- [ ] **NO MIGRATION GUIDES**: Unless project is specifically a replacement tool
- [ ] **COMMUNITY SECTION VERIFIED**: Contributing guidelines only, no development setup

## Integration with Project Documentation

### Relationship to Other Docs

**README.md serves as**:
- Primary entry point for new users
- Quick reference for existing users
- Marketing material for project adoption
- Bridge to comprehensive documentation

**Relationship to Other Files**:
- **CLAUDE.md**: Internal development guidance (NOT referenced in README)
- **CHANGELOG.md**: Version history and changes
- **docs/**: AI-specific guides and tutorials (NOT referenced in README)
- **HexDocs**: API documentation (LINK from README)
- **usage-rules.md**: Comprehensive usage patterns (LINK from README)

### Cross-Reference Strategy

**README should**:
- Link to comprehensive documentation
- Reference specific guides for advanced topics
- Point to examples and tutorials
- Include troubleshooting resources

**Avoid**:
- Duplicating comprehensive documentation
- Including internal development details
- Overwhelming users with too much information
- Outdated or incorrect cross-references
- **Linking to internal development documentation (CLAUDE.md, docs/ai-*.md)**
- **Referencing contributor-specific resources in main content**

### Community Section Guidelines

**✅ INCLUDE in Community Section**:
- Contributing guidelines (brief overview)
- Links to detailed contributing docs
- Code of conduct reference
- Support channels and community resources
- How to get help

**❌ AVOID in Community Section**:
- Development setup instructions for working on the project
- Internal development workflows
- Maintainer procedures
- Project architecture decisions
- Internal testing procedures

**Template for Community Section**:
```markdown
## Community

### Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Getting Help

- 📚 **Documentation**: Check the [documentation](#documentation) first
- 💬 **Discord**: Join the [Ash Discord](https://discord.gg/ash-hq) for real-time help
- 🐛 **Issues**: Report bugs on [GitHub Issues](https://github.com/ash-project/ash_events/issues)
- 💡 **Discussions**: Share ideas on [GitHub Discussions](https://github.com/ash-project/ash_events/discussions)

### Code of Conduct

This project follows the [Ash Framework Code of Conduct](https://github.com/ash-project/ash/blob/main/CODE_OF_CONDUCT.md).
```

## Success Metrics

### User Experience Goals

**Users should be able to**:
- Understand value proposition in 30 seconds
- Complete installation in 5 minutes
- Generate their first event in 10 minutes
- Find answers to common questions quickly
- Discover advanced features when needed

### Quality Indicators

**Signs of Success**:
- Reduced support questions about basic setup
- Increased adoption and usage
- Positive community feedback
- Successful integration by new users
- Clear understanding of capabilities

**Signs of Issues**:
- Frequent questions about installation
- Confusion about basic usage
- Abandonment during setup
- Misunderstanding of capabilities
- Negative feedback about documentation

---

## Key Reminders for AshEvents

### Project-Specific Rules

1. **No Migration Guides**: AshEvents is an addition to Ash projects, not a replacement for other tools
2. **Testing Focus**: How to test applications that use AshEvents, not how to test AshEvents itself
3. **Performance Focus**: End-user production considerations, not internal implementation details
4. **Community Focus**: Contributing guidelines with links to detailed guides, not development setup

### Content Validation Questions

Before adding any section, ask:
- "Does this help end-users USE AshEvents in their applications?"
- "Is this about working ON the AshEvents project itself?"
- "Would a developer adding AshEvents to their Ash project need this information?"

If the answer to the first question is "no" or the second question is "yes", don't include it.

---

**Last Updated**: 2025-07-18
**Next Review**: When AshEvents reaches next major version