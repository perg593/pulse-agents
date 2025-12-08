# NPM Scripts Reference

Complete reference for all available npm scripts, including ports and usage.

## Quick Reference: Ports

| Service | Port | Config File | Environment Variable |
|---------|------|-------------|---------------------|
| **Preview Server** | `8000` | `config/ports.js` | `SERVER_PORT` |
| **Background Proxy** | `3100` | `config/ports.js` | `BACKGROUND_PROXY_PORT` |
| **Stripe Demo Server** | `4242` | `config/ports.js` | `STRIPE_DEMO_PORT` |
| **Webpack Dev Server** | `3035` | `config/ports.js` | `WEBPACK_DEV_PORT` (legacy) |
| **Test Server** | `9898` | `config/ports.js` | `TEST_SERVER_PORT` |

> **Note:** Ports are centrally configured in `config/ports.js`. Environment variables override config values.

## Development Scripts

### `npm run dev` / `npm start`

**Full preview launcher** - Starts all services with build steps.

**Ports Used:**
- Preview Server: `8000` (default)
- Background Proxy: `3100` (default)
- Stripe Demo Server: `4242` (default, optional)

**What it does:**
1. Checks and installs dependencies
2. Generates widget snapshots (if `pi-master` exists)
3. Builds demo survey dataset
4. Starts background proxy server
5. Starts Stripe demo server (if `STRIPE_SECRET_KEY` is set)
6. Starts Python HTTP server for preview

**URLs:**
- Main preview: `http://localhost:8000/preview/basic/`
- Basic preview: `http://localhost:8000/index.html`
- Proxy health: `http://localhost:3100/background-proxy/health`
- Stripe demo: `http://localhost:4242/` (if enabled)

**Logs:**
- Preview server: `/tmp/pulse-preview.log`
- Background proxy: `/tmp/pulse-background-proxy.log`
- Stripe demo: `/tmp/pulse-stripe-demo.log`

**Environment Variables:**
```bash
SERVER_PORT=8000                    # Preview server port
BACKGROUND_PROXY_PORT=3100          # Background proxy port
STRIPE_DEMO_PORT=4242               # Stripe demo port
STRIPE_SECRET_KEY=sk_test_...       # Required for Stripe demo
LOG_FILE=/tmp/pulse-preview.log     # Log file path
```

---

### `npm run start:lite`

**Lightweight launcher** - Starts only essential services, skips build steps.

**Ports Used:**
- Preview Server: `8000` (default)
- Background Proxy: `3100` (default)

**What it does:**
1. Checks and installs dependencies
2. Starts background proxy server
3. Starts Python HTTP server for preview

**URLs:**
- Main preview: `http://localhost:8000/preview/index.html`
- Basic preview: `http://localhost:8000/index.html`
- Proxy health: `http://localhost:3100/background-proxy/health`

**Logs:**
- Preview server: `/tmp/pulse-preview-basic.log`
- Background proxy: `/tmp/pulse-preview-proxy.log`

**Use when:**
- You don't need to rebuild widgets or demo data
- You want faster startup time
- You're iterating on preview code only

---

## Build Scripts

### `npm run build`

**Build preview data** - Generates preview manifest and demo dataset.

**What it does:**
1. Runs `scripts/build/preview-data.js`
2. Runs `scripts/build/demo-data.js`

**No ports used** - Build scripts only.

**Use when:**
- Survey data has changed
- Preview manifest needs updating
- Before committing changes

---

### `npm run build:widgets`

**Generate widget snapshots** - Creates preview widget HTML from pi-master runtime.

**What it does:**
- Runs `scripts/build/generate-widgets.js`
- Requires `pi-master` directory to exist

**No ports used** - Build script only.

**Use when:**
- Widget templates have changed
- New widget types added

---

## Test Scripts

### `npm test`

**Run all tests** - Executes complete test suite.

**Ports Used:**
- Test Server: `9898` (for integration tests)

**What it does:**
- Runs all unit tests
- Runs all integration tests
- Uses test port overrides from `config/ports.js`

**Test Ports (test environment):**
- Preview Server: `8001`
- Background Proxy: `3101`
- Stripe Demo: `4243`

---

### `npm run test:unit`

**Run unit tests only** - Fast unit test execution.

**What it runs:**
- `tests/unit/config/config.test.js`
- `tests/unit/lib/errors.test.js`
- `tests/unit/lib/logger.test.js`
- `tests/unit/lib/validators.test.js`
- `tests/unit/proxy/url-rewriting.test.js`
- `tests/unit/proxy/race-condition.test.js`

**No ports used** - Pure unit tests.

---

### `npm run test:integration`

**Run integration tests** - Tests that require running services.

**Ports Used:**
- Test Server: `9898`

**What it runs:**
- `tests/integration/preview/bridge.contract.test.mjs`
- `tests/integration/preview/surveyBridge.integration.test.mjs`

---

### `npm run test:preview`

**Run preview integration tests** - All preview-related integration tests.

**Ports Used:**
- Test Server: `9898`

**What it runs:**
- All tests matching `tests/integration/preview/*.test.mjs`

---

### `npm run test:demo-proxy`

**Test demo proxy functionality** - Specific proxy integration test.

**Ports Used:**
- Test Server: `9898`

---

### `npm run test:url-rewriting`

**Test URL rewriting** - Specific URL rewriting integration test.

**Ports Used:**
- Test Server: `9898`

---

### `npm run test:script-interception-unit`

**Unit tests for script interception** - Fast unit tests for script interception.

**No ports used** - Pure unit tests.

---

### `npm run test:script-injection`

**Test script injection** - Integration test for script injection.

**Ports Used:**
- Test Server: `9898`

---

### `npm run test:script-interception`

**Test script interception** - Integration test for script interception.

**Ports Used:**
- Test Server: `9898`

---

## Cleanup Scripts

### `npm run clean`

**Clean build artifacts** - Removes generated files.

**What it removes:**
- Build artifacts
- Temporary files
- Generated preview data (optional)

**Environment Variables:**
```bash
CLEAN_BUILD=1              # Remove build artifacts
CLEAN_NODE_MODULES=0       # Keep node_modules (default)
```

---

### `npm run clean:all`

**Deep clean** - Removes all generated files including node_modules.

**What it removes:**
- Build artifacts
- Temporary files
- Generated preview data
- `node_modules` directories

**Use when:**
- Dependency issues
- Need fresh install
- Before major version updates

---

## Port Configuration

### Centralized Configuration

All ports are defined in `config/ports.js`:

```javascript
const PORTS = {
  SERVER_PORT: 8000,
  STRIPE_DEMO_PORT: 4242,
  BACKGROUND_PROXY_PORT: 3100,
  WEBPACK_DEV_PORT: 3035,
  TEST_SERVER_PORT: 9898
};
```

### Environment Overrides

Ports can be overridden via environment variables:

```bash
# Override preview server port
SERVER_PORT=9000 npm start

# Override multiple ports
SERVER_PORT=9000 BACKGROUND_PROXY_PORT=3200 npm start
```

### Test Environment Ports

Test environment uses different ports to avoid conflicts:

```javascript
PORT_OVERRIDES = {
  test: {
    SERVER_PORT: 8001,
    STRIPE_DEMO_PORT: 4243,
    BACKGROUND_PROXY_PORT: 3101
  }
};
```

---

## Troubleshooting

### Port Already in Use

If a port is already in use, scripts will attempt to stop the existing process:

```bash
# Check what's using a port
lsof -iTCP:8000 -sTCP:LISTEN

# Manually stop a process
kill $(lsof -tiTCP:8000 -sTCP:LISTEN)
```

### Services Not Starting

1. **Check logs:**
   ```bash
   tail -f /tmp/pulse-preview.log
   tail -f /tmp/pulse-background-proxy.log
   ```

2. **Verify ports are free:**
   ```bash
   lsof -iTCP:8000,3100,4242 -sTCP:LISTEN
   ```

3. **Check dependencies:**
   ```bash
   node --version  # Should be 16+
   python3 --version  # Should be 3.x
   ```

### Health Check Endpoints

Verify services are running:

```bash
# Preview server
curl http://localhost:8000/

# Background proxy
curl http://localhost:3100/background-proxy/health

# Stripe demo (if enabled)
curl http://localhost:4242/stripe-demo/health
```

---

## Quick Start Examples

### Development Workflow

```bash
# Start full preview (with builds)
npm start

# Or start lightweight version (faster)
npm run start:lite

# Run tests
npm test

# Clean and rebuild
npm run clean && npm run build
```

### Testing Workflow

```bash
# Run unit tests only (fast)
npm run test:unit

# Run integration tests
npm run test:integration

# Run specific test suite
npm run test:url-rewriting
```

### Custom Ports

```bash
# Use custom ports
SERVER_PORT=9000 BACKGROUND_PROXY_PORT=3200 npm start

# Or export for session
export SERVER_PORT=9000
export BACKGROUND_PROXY_PORT=3200
npm start
```

---

## See Also

- [Port Configuration](../architecture/services.md#port-configuration)
- [Development Setup](../development/setup.md)
- [Scripts README](../../scripts/README.md)
