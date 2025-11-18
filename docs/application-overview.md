# Pulse Widgets Theme Toolkit - Application Overview

**Last Updated:** 2025-02-15
**Version:** 2.0

## What is Pulse Widgets Theme Toolkit?

The Pulse Widgets Theme Toolkit is a comprehensive system for generating branded themes from websites and previewing Pulse Insights survey widgets. It automates the process of extracting brand colors, fonts, and design patterns from any website, then generates multiple theme variations that can be applied to survey widgets.

---

## Core Capabilities

### 1. Automated Theme Generation

- **Website Analysis:** Analyzes any website to extract:
  - Brand colors (backgrounds, text, accents, borders)
  - Font families, sizes, and weights
  - Logo colors
  - CSS variables
  - Design patterns

- **Theme Variations:** Generates 4 theme styles per client:
  - **Brand Faithful** - Closest match to original brand
  - **High Contrast** - Enhanced accessibility
  - **Modern** - Contemporary styling
  - **Minimalist** - Clean, simple design

- **Output:** CSS files ready to use with Pulse Insights surveys

### 2. Preview Dashboard

- **Live Survey Testing:** Preview production surveys with generated themes
- **Theme Application:** Swap themes on demand (generated or manual CSS)
- **Behavior Simulation:** Simulate triggers (exit intent, scroll depth, rage clicks, timers)
- **Device Simulation:** Test on Desktop, Tablet, or Mobile
- **Placement Options:** Test widget placement (BR/BL/TR/TL)
- **Inline Support:** Test inline survey placement

### 3. Supporting Services

- **Background Proxy:** Load external sites in iframes (strips X-Frame-Options)
- **Stripe Demo Server:** Test surveys on Stripe checkout pages
- **Health Monitoring:** Health check endpoints for all services

---

## Key Features

**Note:** The theme generator has been moved to a separate repository: https://github.com/perg593/theme-generator

### Preview Dashboard

✅ **Survey Presentation**
- Production survey integration
- Protocol v1 communication (Bridge ↔ Player)
- State machine for presentation lifecycle
- Queue management with priority
- Duplicate prevention

✅ **Theme Management**
- Load generated themes from manifest
- Apply manual CSS overrides
- Theme switching without reload
- CSS variable viewer

✅ **Behavior Simulation**
- Scroll depth tracking (10% milestones)
- Exit intent detection
- Rage click simulation
- Timer-based triggers
- Rules-based presentation

✅ **Device & Placement**
- Device simulation (Desktop/Tablet/Mobile)
- Placement options (BR/BL/TR/TL)
- Safe area handling
- Responsive testing

---

## Architecture Highlights

### Modular Design

- **Shared Infrastructure:** Centralized configuration, error handling, logging, validation
- **Service Layer:** Presentation service with state machine
- **Event-Driven:** Loose coupling via event bus
- **Protocol-Based:** Versioned communication protocol (Protocol v1)

### Recent Improvements

✅ **Centralized Configuration**
- Port management (`config/ports.js`)
- Constants (`config/constants.js`)
- Path utilities (`config/paths.js`)

✅ **Standardized Error Handling**
- Custom error classes (`lib/errors.js`)
- Error factory and handler
- Context-aware error messages

✅ **Comprehensive Validation**
- URL validation
- File path validation
- Parameter validation
- Theme validation

✅ **Presentation Service**
- State machine (idle → preparing → presenting → presented/failed)
- Queue management (priority: manual > auto)
- Deduplication (time-windowed)

✅ **Event-Driven Architecture**
- Event bus for loose coupling
- Event filtering and routing
- Event history for debugging

✅ **Performance Monitoring**
- Latency tracking
- Success/failure rates
- Error rates by type
- Queue wait times

---

## Technology Stack

### Core Technologies

- **Language:** JavaScript (ES6+), TypeScript (v2 generator)
- **Module System:** CommonJS (Node.js), ES Modules (browser)
- **Browser Automation:** Puppeteer
- **Server:** Python HTTP server, Node.js (Express for services)

### Browser APIs

- EventTarget, CustomEvent (event bus)
- postMessage (iframe communication)
- Fetch API (HTTP requests)

### Testing

- Node.js test runner (unit tests)
- Playwright (E2E tests)
- Test coverage: >80% for utilities

---

## File Structure

```
pulse_widgets/
├── config/                 # Centralized configuration
│   ├── ports.js           # Port management
│   ├── constants.js       # Behavior constants
│   ├── constants-browser.js # Browser constants
│   └── paths.js           # Path utilities
├── lib/                    # Shared utilities
│   ├── errors.js          # Custom error classes
│   ├── logger.js          # Standardized logging
│   ├── validators.js      # Input validation
│   └── paths.js           # Path utilities
├── preview/                # Preview dashboard
│   ├── app/               # ES module demo studio
│   ├── basic/             # Streamlined preview
│   ├── scripts/           # Node.js helpers
│   └── widgets/           # HTML fixtures
├── scripts/               # Build and launch scripts
├── tests/                 # Test suite
└── docs/                  # Documentation
```

---

## Common Workflows

### Launch Preview Dashboard

```bash
npm start
```

This will:
1. Start preview server (port 8000)
2. Start background proxy (port 3100)
3. Start Stripe demo server (port 4242, if configured)
4. Build preview data and demo data
5. Open `http://localhost:8000/preview/index.html`

### Test a Survey

1. Open preview dashboard
2. Select a survey from dropdown
3. Select a theme (or use manual CSS)
4. Set background URL (or use default)
5. Click "Present Survey"
6. Survey appears in iframe

### Simulate Behavior

1. Open preview dashboard
2. Enable "Behavior Lab"
3. Configure scroll depth, exit intent, or timer triggers
4. Select survey for behavior
5. Interact with background page
6. Survey presents automatically when trigger fires

---

## Service Ports

| Service | Port | Purpose |
|--------|------|---------|
| Preview Server | 8000 | Serves static files and preview dashboard |
| Background Proxy | 3100 | Proxies external sites for iframe embedding |
| Stripe Demo Server | 4242 | Creates PaymentIntents for Stripe checkout (optional) |

All ports are configurable via `config/ports.js` or environment variables.

---

## Key Concepts

### Protocol v1

Versioned message contract for Bridge ↔ Player communication:
- Envelope: `{ v: 1, id: "...", type: "...", payload: {...} }`
- Commands: `present`, `dismiss`, `applyTheme`, `trigger`, `setPlacement`, `setTokens`
- Reports: `status`, `error`, `pong`
- Handshake: `hello` → `init` → `ready`

### Presentation Lifecycle

State machine for survey presentation:
1. **idle** - No active presentation
2. **preparing** - Ensuring prerequisites (background, player, tag)
3. **presenting** - Sending present command
4. **presented** - Survey successfully presented
5. **failed** - Presentation failed

### Theme Structure

Generated themes include:
- CSS variables for colors, fonts, spacing
- Widget-specific styles
- Responsive breakpoints
- Dark mode support (some themes)

---

## Getting Started

### Quick Start

1. **Install dependencies:**
   ```bash
   npm install
   cd theme-generator/v1 && npm install
   ```

2. **Generate a theme:**
   ```bash
   cd theme-generator/v1
   node main.js https://example.com my-client
   ```

3. **Launch preview:**
   ```bash
   npm start
   ```

4. **Open preview:**
   ```
   http://localhost:8000/preview/index.html
   ```

### Next Steps

- Read [Architecture Overview](docs/architecture/overview.md) for system architecture
- Read [Getting Started Guide](docs/getting-started/quick-start.md) for detailed setup
- Read [API Reference](docs/api/) for API documentation
- Read [Guides](docs/guides/) for how-to guides

---

## Documentation

Comprehensive documentation is available in `docs/`:

- **[Architecture](docs/architecture/)** - System architecture and design
- **[API Reference](docs/api/)** - API documentation
- **[Getting Started](docs/getting-started/)** - Setup and quick start guides
- **[Guides](docs/guides/)** - How-to guides
- **[Protocols](docs/protocols/)** - Communication protocols
**Theme Generator**: Moved to https://github.com/perg593/theme-generator

---

## Support

For issues, questions, or contributions:

1. Check [Documentation](docs/README.md)
2. Review [Troubleshooting Guides](docs/deployment/troubleshooting.md)
3. Check [Recent Improvements](docs/improvements/implementation-summary.md)

---

**Maintained by:** Pulse Insights
**Status:** Active development
**Version:** 2.0
