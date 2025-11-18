# Pulse Agents Demo

This repository contains the Pulse Agents preview dashboard (`preview/`) and supporting assets. The codebase has been standardized with centralized configuration, improved error handling, and comprehensive validation.

**Note:** The theme generator has been moved to a separate repository: https://github.com/perg593/theme-generator

## 📦 Current Structure

```
.
├── config/                 # Centralized configuration (ports, constants, paths)
├── lib/                    # Shared utilities (errors, logging, validation, paths)
├── tests/                  # Centralized test suite (unit + integration)
├── docs/                   # Centralized documentation
├── preview/                # Demo studio (modular UI, production tag bridge, fixtures)
├── fonts/                  # Local font assets used during theme testing
└── legacy/                 # Archived interfaces (no longer maintained)
```

Key preview assets:
- `preview/app/` – The new ES module based demo studio (UI, services, survey player, generated data).
- `preview/scripts/` – Node helpers (`build-preview-data`, `build-demo-data`, `surveys-tag.js`).
- `preview/widgets/…` – HTML fixtures still available for rapid visual regressions.
- `preview/demo-accounts-surveys-css.csv` – Source of production survey metadata (converted to JSON at build time).

## 🚀 Common Workflows

### 1. Install Dependencies
```bash
# Install root dependencies
npm install
```

### 2. Run Tests
```bash
# Run all tests (unit + integration)
npm test

# Run unit tests only
npm run test:unit

# Run integration tests only
npm run test:integration

# Run specific test file
node tests/unit/lib/errors.test.js
```

### 3. Launch the Demo Studio (production tag + triggers)
```bash
npm start                              # or: ./scripts/launch/preview.sh
open http://localhost:8000/preview/index.html
```

## 🔄 Service Management

### Restart All Services
To restart all services (useful after configuration changes or when services become unresponsive):

```bash
# Stop all services gracefully
pkill -f "python3 -m http.server"
pkill -f "stripe-demo-server.js"
pkill -f "background-proxy-server.js"

# Wait for cleanup
sleep 3

# Restart all services
npm start                              # or: ./scripts/launch/preview.sh
```

### Individual Service Management

#### Preview Server (Main)
```bash
# Stop
pkill -f "python3 -m http.server"

# Start
python3 -m http.server 8000

# Check status
curl http://localhost:8000/
```

#### Stripe Demo Server
```bash
# Stop
pkill -f "stripe-demo-server.js"

# Start
cd preview/scripts
node stripe-demo-server.js

# Check status
curl http://localhost:4242/stripe-demo/health
```

#### Background Proxy Server
```bash
# Stop
pkill -f "background-proxy-server.js"

# Start
cd preview/scripts
node background-proxy-server.js

# Check status
curl http://localhost:3100/background-proxy/health
```

### Service Health Checks
```bash
# Check all services at once
curl http://localhost:8000/ && echo "✅ Preview Server"
curl http://localhost:4242/stripe-demo/health && echo "✅ Stripe Demo"
curl http://localhost:3100/background-proxy/health && echo "✅ Background Proxy"
```

### Troubleshooting Services

#### Port Conflicts
If you get "port already in use" errors:
```bash
# Find processes using ports
lsof -tiTCP:8000 -sTCP:LISTEN
lsof -tiTCP:4242 -sTCP:LISTEN
lsof -tiTCP:3100 -sTCP:LISTEN

# Kill specific processes
kill -9 <PID>
```

#### Service Won't Start
1. Check dependencies: `node --version` (should be 16+)
2. Check logs: `tail -f /tmp/pulse-preview.log`
3. Verify configuration: `node -e "console.log(require('./config/ports.js').getPorts('development'))"`

#### Services Start But Don't Respond
1. Wait 30 seconds for full initialization
2. Check firewall settings
3. Verify no other services are using the ports
4. Check service logs for errors

> `/preview/index.html` now redirects to the streamlined basic experience. Open `/preview/v3/index.html` for the exploratory v3 prototype.

## 🏗️ Architecture Improvements

The codebase has been significantly improved with:

### Centralized Configuration
- **`config/ports.js`** - Centralized port management for all services
- **`config/constants.js`** - Behavior and UI constants
- **`config/paths.js`** - Common path patterns and utilities

### Error Handling & Logging
- **`lib/errors.js`** - Custom error classes with proper error handling
- **`lib/logger.js`** - Standardized logging with levels and formatting
- **`lib/validators.js`** - Input validation for files, URLs, ports, and themes
- **`lib/paths.js`** - Path utilities for consistent file operations

### Process Management
- Improved cleanup procedures with graceful shutdown
- Race condition fixes in service startup
- Enhanced dependency checks with version validation
- Exponential backoff for health checks

### Testing
- Comprehensive unit tests for all utilities
- Test runner with colored output and summary
- >80% code coverage for new utilities

The studio now supports:
- loading any prospective site and presenting live production surveys,
- swapping in generated themes or manual CSS on demand,
- simulating behavioural triggers (exit intent, rage clicks, scroll depth, timers),
- demonstrating inline surveys via the dedicated survey player canvas.

### 5. (Optional) Run the Stripe Checkout demo background

```bash
# one-time: install dependencies (already covered by npm install)
node preview/scripts/stripe-demo-server.js   # starts on http://localhost:4242
```

Then, inside the preview, set the background URL to `/preview/backgrounds/stripe-checkout/index.html`
(or `http://localhost:8000/preview/backgrounds/stripe-checkout/index.html`). The page loads Stripe
Elements with test keys, the demo Pulse tag, and talks to the local server to create PaymentIntents.
Query parameters such as `?amount=2599&currency=usd` are supported for quick tweaks.

You can also launch the services together via `RUN_STRIPE_DEMO_SERVER=1 ./scripts/launch/services.sh`.

### 6. Background proxy (load sites that set X-Frame-Options)

`./scripts/launch/services.sh` now starts a lightweight Node proxy on `http://localhost:3100` by
default. Any background URL that points to a remote `http://`/`https://` address is routed through
`/proxy?url=…`, which strips `X-Frame-Options`/`frame-ancestors` headers so the page can render in an
iframe. Local backgrounds (e.g., `/preview/backgrounds/stripe-checkout/index.html`) are left alone
so Stripe Elements continues to run same-origin.

- Disable the proxy by setting `RUN_BACKGROUND_PROXY=0`.
- Change the port with `BACKGROUND_PROXY_PORT=3200` and update `window.__PI_PROXY_ORIGIN__`
  (the default inline script in the preview HTML points to `http://localhost:3100`).
- For production, swap `window.__PI_PROXY_ORIGIN__` to whatever Worker/Function hosts the proxy.
- The proxy strips `X-Frame-Options` / `frame-ancestors` and injects a small script that hides
  common cookie-consent banners (Osano, OneTrust, TrustArc, etc.) so demos start clean.

📚 **Need a deeper walkthrough?** See [`docs/`](docs/) for centralized documentation:
- **[Application Overview](docs/application-overview.md)** - Complete application overview
- **[Getting Started](docs/getting-started/)** - Installation and quick start
- **[Architecture](docs/architecture/)** - System architecture and design
- **[API Reference](docs/api/)** - API documentation
- **[Guides](docs/guides/)** - How-to guides

---

**Maintained by**: Pulse Insights  
**Status**: Active development on preview dashboard

**Theme Generator**: Moved to https://github.com/perg593/theme-generator  
