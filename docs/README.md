# Pulse Widgets Documentation

Welcome to the Pulse Widgets Theme Toolkit documentation. This directory contains all documentation for the project, organized by purpose and audience.

## Quick Links

- **[Application Overview](application-overview.md)** - **Start here** - Complete application overview
- **[Getting Started](getting-started/)** - Installation, quick start, and development workflows
- **[Architecture Overview](architecture/overview.md)** - High-level system architecture
- **[API Reference](api/)** - API documentation for config, lib, and scripts
- **[Guides](guides/)** - Step-by-step how-to guides
- **[Protocols](protocols/)** - Communication protocol specifications

## Documentation Structure

### Getting Started (`getting-started/`)
Quick start guides for new developers:
- [Quick Start](getting-started/quick-start.md) - Fast setup and launch
- [Setup Guide](getting-started/setup-guide.md) - Detailed installation instructions
- [Testing and Launch Guide](getting-started/testing-and-launch-guide.md) - Testing workflows
- [Migration Guide](getting-started/migration.md) - For existing users

### Architecture (`architecture/`)
Technical deep-dives and design documentation:
- [System Overview](architecture/overview.md) - **Start here** - Complete system architecture
- [Preview System Architecture](architecture/preview-system-overview.md) - Preview dashboard details
- [Data Model](architecture/data-model.md) - Data structures and models

### API (`api/`)
API reference documentation:
- [Configuration API](api/config.md) - Port, constants, and path configuration
- [Utility Library API](api/lib.md) - Error handling, logging, validation, paths
- [Presentation Service API](api/preview/presentation-service.md) - Presentation service API

### Guides (`guides/`)
Step-by-step how-to guides:
- [Preview Presentation Scenarios](guides/preview/presentation-scenarios.md) - Presentation workflows
- [Git Workflow](guides/git-workflow-preview-improvements.md) - Git workflows
- [PR Troubleshooting](guides/pr-merge-troubleshooting.md) - PR troubleshooting

### Protocols (`protocols/`)
Communication protocol specifications:
- [Protocol v1](protocols/protocol-v1.md) - Bridge ↔ Player communication protocol

### Preview (`preview/`)
Preview-specific documentation:
- [Browser Features](preview/browser-features.md) - Browser automation features
- [Browser Quick Start](preview/browser-quick-start.md) - Browser quick start
- [Demo Walkthrough](preview/demo-walkthrough.md) - Demo walkthrough
- Version-specific documentation in subdirectories

### Theme Generator (`theme-generator/`)
Theme generator documentation:
- [Overview](theme-generator/overview.md) - Theme generator overview
- [API Reference](theme-generator/api-reference.md) - Theme generator API
- [Testing](theme-generator/testing.md) - Testing guide
- [Improvements](theme-generator/improvements.md) - Recent improvements
- [Cloudflare Deployment](theme-generator/cloudflare-deployment.md) - Deployment guide

### Deployment (`deployment/`)
Deployment documentation:
- [Overview](deployment/overview.md) - Deployment overview
- [Cloudflare Pages](deployment/cloudflare-pages.md) - Cloudflare Pages deployment
- [Cloudflare GitHub](deployment/cloudflare-github.md) - GitHub integration
- [Troubleshooting](deployment/troubleshooting.md) - Deployment troubleshooting

### Planning (`planning/`)
Historical planning documents and implementation plans:
- Feature planning documents (organized by date)
- Implementation plans
- Architecture decisions

### Improvements (`improvements/`)
Documentation of recent improvements:
- [Implementation Summary](improvements/implementation-summary.md) - Recent improvements summary

### Decisions (`decisions/`)
Architectural Decision Records (ADRs):
- [Presentation Implementation Choice](decisions/presentation-implementation-choice.md)
- [Prompt Setup](decisions/prompt-setup.md)

### Testing (`testing/`)
Testing documentation:
- [Preview Testing Strategy](testing/preview-testing-strategy.md) - Testing strategy

### Other Directories

- `ask/` - Historical Q&A documents
- `review/` - Code review documentation
- `templates/` - Documentation templates
- `mermaid/` - Architecture diagrams (Mermaid format)
- `legacy/` - Historical documentation and deprecated materials
- `for-partners/` - Partner-facing documentation

## Finding Documentation

### By Role

- **New to the project?** Start with [Getting Started](getting-started/)
- **Developer?** See [Architecture Overview](architecture/overview.md) and [API Reference](api/)
- **Looking for a how-to?** Check [Guides](guides/)
- **Need technical details?** See [Architecture](architecture/)
- **Deploying?** See [Deployment](deployment/)

### By Topic

- **Theme Generation:** [Theme Generator Overview](theme-generator/overview.md)
- **Preview Dashboard:** [Preview System Architecture](architecture/preview-system-overview.md)
- **Configuration:** [Configuration API](api/config.md)
- **Error Handling:** [Utility Library API](api/lib.md#error-handling)
- **Protocols:** [Protocol v1](protocols/protocol-v1.md)
- **Services:** See [Architecture Overview](architecture/overview.md#supporting-services)

## Documentation Status

### ✅ Complete and Up-to-Date
- Architecture overview
- API documentation (config, lib)
- Preview system architecture
- Protocol v1 specification
- Getting started guides

### 📝 Needs Updates
- Some planning documents may reference older implementations
- Legacy documentation may be outdated

### 🔄 In Progress
- Services architecture documentation
- Additional API documentation

## Contributing Documentation

When adding new documentation:

1. **Place it in the appropriate directory** based on purpose
2. **Follow existing naming conventions** (kebab-case for files)
3. **Update this README** if adding a new section
4. **Link from relevant README files** and cross-reference
5. **Use JSDoc** for code documentation
6. **Include examples** where helpful
7. **Keep it up-to-date** with code changes

## Documentation Standards

- **Markdown format** - All documentation in Markdown
- **Code examples** - Include working code examples
- **Cross-references** - Link to related documentation
- **Version information** - Include last updated date
- **Status indicators** - Use ✅, 📝, 🔄 for status

---

**Last Updated:** 2025-02-15  
**Maintained by:** Pulse Insights

