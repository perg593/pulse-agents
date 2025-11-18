# Pulse Agents Demo - Architecture Overview

**Last Updated:** 2025-02-15
**Version:** 2.0

## Purpose

The Pulse Agents Demo is a preview dashboard for testing Pulse Insights survey widgets with themes and simulating behavioral triggers.

**Note:** The theme generator has been moved to a separate repository: https://github.com/perg593/theme-generator

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Pulse Agents Preview Dashboard                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────┐     │
│  │              Preview Dashboard                        │     │
│  │                                                       │     │
│  │  • Preview App        │  • Survey Bridge            │     │
│  │  • Player Iframe      │  • Presentation Service     │     │
│  │  • Theme Manager      │  • Browser Theme Generator  │     │
│  └──────────────────────────────────────────────────────┘     │
│                                                                 │
│  ┌──────────────────────────────────────────────────────┐   │
│  │           Shared Infrastructure                        │   │
│  │  • Configuration (ports, constants, paths)           │   │
│  │  • Error Handling (custom error classes)              │   │
│  │  • Logging (standardized logger)                      │   │
│  │  • Validation (URLs, files, themes)                  │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌──────────────────────────────────────────────────────┐   │
│  │           Supporting Services                         │   │
│  │  • Preview Server (port 8000)                         │   │
│  │  • Background Proxy (port 3100)                       │   │
│  │  • Stripe Demo Server (port 4242, optional)           │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Component Overview

### Preview Dashboard System

**Location:** `preview/`

#### Preview Application (`preview/basic/` & `preview/app/`)
- **Two Implementations:**
  - `preview/basic/` - Streamlined experience with behavior simulation
  - `preview/app/` - ES module-based demo studio
- **Features:**
  - Survey selection and presentation
  - Theme application (generated or manual CSS)
  - Behavior simulation (exit intent, scroll depth, rage clicks)
  - Device simulation (Desktop/Tablet/Mobile)
  - Placement options (BR/BL/TR/TL)

#### Survey Bridge (`preview/app/survey/bridge.js`)
- **Purpose:** Communication layer between preview app and player iframe
- **Protocol:** Protocol v1 (versioned message contract)
- **Features:**
  - Message routing and validation
  - Player iframe lifecycle management
  - Error handling and retry logic

#### Player Iframe (`preview/app/survey/player.js`)
- **Purpose:** Isolated survey execution environment
- **Features:**
  - Loads Pulse Insights tag script
  - Handles survey presentation
  - Widget rendering
  - Theme application

#### Presentation Service (`preview/basic/services/presentationService.js`)
- **Purpose:** Orchestrates survey presentations
- **Components:**
  - State machine (idle → preparing → presenting → presented/failed)
  - Queue management (priority: manual > auto)
  - Deduplication (time-windowed duplicate prevention)
  - Event bus integration

**Presentation Flow:**
```
User Action → Presentation Service → Queue → Deduplicator → Bridge → Player → Tag → Widget
```

---

### 3. Shared Infrastructure

**Location:** `config/` and `lib/`

#### Configuration (`config/`)
- **`ports.js`** - Centralized port management
- **`constants.js`** - Behavior and UI constants
- **`paths.js`** - Path utilities
- **`constants-browser.js`** - Browser-specific constants

#### Error Handling (`lib/errors.js`)
- Custom error classes:
  - `ThemeGenerationError`
  - `ValidationError`
  - `ConfigError`
  - `FileOperationError`
  - `NetworkError`
  - `ProcessError`
  - `PresentationError` (and subclasses)

#### Logging (`lib/logger.js`)
- Standardized logging with levels (debug, info, warn, error)
- Context objects for structured logging
- Formatting utilities

#### Validation (`lib/validators.js`)
- URL validation
- File path validation
- Parameter validation
- Theme validation

#### Path Utilities (`lib/paths.js`)
- Path resolution from project root
- File existence checks
- Path normalization

---

### 4. Supporting Services

#### Preview Server
- **Port:** 8000
- **Technology:** Python HTTP server
- **Purpose:** Serves static files and preview dashboard
- **Entry Point:** `/preview/index.html` → redirects to `/preview/basic/`

#### Background Proxy Server (`preview/scripts/background-proxy-server.js`)
- **Port:** 3100
- **Technology:** Node.js + Express
- **Purpose:**
  - Strips `X-Frame-Options` headers for iframe embedding
  - Removes cookie consent banners
  - Configurable allowlist/blocklist

#### Stripe Demo Server (`preview/scripts/stripe-demo-server.js`)
- **Port:** 4242 (optional)
- **Technology:** Node.js + Express
- **Purpose:** Creates PaymentIntents for Stripe checkout demos
- **Requires:** `STRIPE_SECRET_KEY` environment variable

---

## Data Flow

### Preview Presentation Flow

```
1. User selects survey from dropdown
2. Presentation Service validates and queues request
3. Deduplicator checks for duplicates (cooldown window)
4. Queue manages priority (manual > auto)
5. State machine transitions: idle → preparing → presenting
6. Bridge sends 'present' command to Player iframe
7. Player executes tag script present command
8. Survey widget rendered in iframe
9. Status reported back to Bridge → Preview UI
```

### Protocol v1 Communication

```
Bridge (parent) ←→ Player (iframe)
- Envelope: { v: 1, id: "...", type: "...", payload: {...} }
- Commands: present, dismiss, applyTheme, trigger, setPlacement, setTokens
- Reports: status, error, pong
- Handshake: hello → init → ready
```

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

## Design Patterns

### 1. Service Layer Pattern
- Presentation logic extracted into services
- Dependency injection for testability
- Clear separation of concerns

### 2. State Machine Pattern
- Explicit state management for presentation lifecycle
- Prevents invalid state transitions
- Clear state definitions and transitions

### 3. Queue Pattern
- Request queuing with priority
- Deduplication to prevent duplicates
- Lock mechanism to prevent concurrent operations

### 4. Event-Driven Architecture
- Loose coupling via event bus
- Event filtering and routing
- Event history for debugging

### 5. Protocol Pattern
- Versioned message contract (Protocol v1)
- Structured message envelope
- Acknowledgment discipline

---

## Security Considerations

### Preview System
- Player iframe uses sandbox attributes
- postMessage with origin validation
- No direct DOM manipulation across iframe boundaries
- CORS handling for external resources

### Background Proxy
- Configurable allowlist/blocklist
- Hostname validation
- Protocol validation (http/https only)

### Preview Dashboard
- URL validation before fetching
- Path validation to prevent directory traversal
- File operation error handling

---

## Performance Considerations

### Preview System
- Lazy loading of player iframe
- Request deduplication to prevent duplicate presentations
- Queue management to prevent resource exhaustion
- State machine prevents invalid transitions

### Preview Dashboard
- Browser reuse for multiple pages
- Timeout management for slow-loading sites
- Graceful degradation for problematic sites

### Services
- Health check endpoints for monitoring
- Graceful shutdown handling
- Exponential backoff for retries

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

## Related Documentation

- [Application Overview](../application-overview.md) - Complete application overview
- [Preview System Architecture](preview-system-overview.md) - Detailed preview system architecture
- [Services Architecture](services.md) - Supporting services documentation
- [Data Model](data-model.md) - Data structures and models
- [Protocol v1](../protocols/protocol-v1.md) - Communication protocol specification
- [Getting Started](../getting-started/quick-start.md) - Quick start guide
- [API Reference](../api/) - API documentation

---

## Recent Improvements

See [Implementation Summary](../improvements/implementation-summary.md) for details on recent improvements:

- ✅ Centralized configuration system
- ✅ Standardized error handling
- ✅ Comprehensive validation
- ✅ Presentation service with state machine
- ✅ Event-driven architecture
- ✅ Queue and deduplication system
- ✅ Performance monitoring
- ✅ Debugging tools

---

**Maintained by:** Pulse Insights
**Status:** Active development

