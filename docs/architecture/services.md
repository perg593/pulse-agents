# Services Architecture

**Last Updated:** 2025-02-15  
**Purpose:** Documentation of supporting services for the Pulse Widgets Theme Toolkit

---

## Overview

The Pulse Widgets Theme Toolkit uses several supporting services to enable the preview dashboard functionality. All services use centralized port configuration and support graceful shutdown.

---

## Service List

### 1. Preview Server

**Location:** Root directory  
**Port:** 8000 (configurable via `SERVER_PORT`)  
**Technology:** Python HTTP server  
**Purpose:** Serves static files and preview dashboard

#### Features

- Serves static files from project root
- Entry point: `/preview/index.html` → redirects to `/preview/basic/`
- Supports all preview assets (HTML, CSS, JS, images)
- No special configuration required

#### Startup

```bash
python3 -m http.server 8000
```

#### Health Check

```bash
curl http://localhost:8000/
```

#### Configuration

- Port: `config/ports.js` → `SERVER_PORT`
- Environment variable: `SERVER_PORT`
- Default: `8000`

---

### 2. Background Proxy Server

**Location:** `preview/scripts/background-proxy-server.js`  
**Port:** 3100 (configurable via `BACKGROUND_PROXY_PORT`)  
**Technology:** Node.js + Express  
**Purpose:** Proxy for loading external sites in iframes

#### Features

- Strips `X-Frame-Options` headers for iframe embedding
- Removes cookie consent banners (Osano, OneTrust, TrustArc, etc.)
- Configurable allowlist/blocklist
- CORS handling

#### Startup

```bash
node preview/scripts/background-proxy-server.js
```

#### Health Check

```bash
curl http://localhost:3100/background-proxy/health
```

Response:
```json
{
  "status": "ok",
  "port": 3100,
  "allowlist": ["*"]
}
```

#### Configuration

**Port:**
- Config: `config/ports.js` → `BACKGROUND_PROXY_PORT`
- Environment variable: `BACKGROUND_PROXY_PORT`
- Default: `3100`

**Allowlist:**
- Environment variable: `BACKGROUND_PROXY_ALLOWLIST`
- Default: `*` (all hosts allowed)
- Format: Comma-separated list of hostnames

**Blocklist:**
- Environment variable: `BACKGROUND_PROXY_BLOCKLIST`
- Default: `localhost,127.,::1`
- Format: Comma-separated list of hostname prefixes

#### Usage

The proxy is accessed via `/proxy?url=...` endpoint:

```javascript
const proxyUrl = `http://localhost:3100/proxy?url=${encodeURIComponent(targetUrl)}`;
```

#### Cookie Consent Banner Removal

The proxy automatically injects CSS to hide common cookie consent banners:
- OneTrust (`#onetrust-banner-sdk`, `.onetrust-pc-dark-filter`)
- Cookie Consent (`.cc-window`, `.cc-banner`)
- Osano (`.osano-cm-window`, `.osano-cm-wrapper`)
- TrustArc (`.truste_overlay`, `.truste_box_overlay`)
- And more...

---

### 3. Stripe Demo Server

**Location:** `preview/scripts/stripe-demo-server.js`  
**Port:** 4242 (configurable via `STRIPE_DEMO_PORT`)  
**Technology:** Node.js + Express  
**Purpose:** Creates PaymentIntents for Stripe checkout demos  
**Status:** Optional

#### Features

- Creates PaymentIntents via Stripe API
- Supports query parameters for amount/currency
- Health check endpoint
- Error handling

#### Startup

```bash
STRIPE_SECRET_KEY=sk_test_... node preview/scripts/stripe-demo-server.js
```

#### Health Check

```bash
curl http://localhost:4242/stripe-demo/health
```

Response:
```json
{
  "status": "ok",
  "port": 4242
}
```

#### Configuration

**Port:**
- Config: `config/ports.js` → `STRIPE_DEMO_PORT`
- Environment variable: `STRIPE_DEMO_PORT`
- Default: `4242`

**Stripe Secret Key:**
- Environment variable: `STRIPE_SECRET_KEY` (required)
- Format: `sk_test_...` or `sk_live_...`

#### Usage

The Stripe demo server is used by the Stripe checkout background (`preview/backgrounds/stripe-checkout/`):

```javascript
// In Stripe checkout page
const response = await fetch('http://localhost:4242/stripe-demo/create-payment-intent', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ amount: 2599, currency: 'usd' })
});
```

#### Query Parameters

The Stripe checkout page supports query parameters:
- `?amount=2599` - Payment amount in cents
- `?currency=usd` - Currency code

---

## Service Management

### Launch Scripts

#### Full Launch (`scripts/launch/preview.sh`)

Launches all services:
- Preview server
- Background proxy
- Stripe demo server (if `STRIPE_SECRET_KEY` is set)
- Builds preview data and demo data

```bash
npm start
# or
./scripts/launch/preview.sh
```

#### Lite Launch (`scripts/launch/preview-lite.sh`)

Launches only essential services:
- Preview server
- Background proxy
- Skips build steps

```bash
npm run start:lite
# or
./scripts/launch/preview-lite.sh
```

#### Services Script (`scripts/launch/services.sh`)

Core service management script:
- Starts/stops services
- Health checks with exponential backoff
- Graceful shutdown
- Process management

### Service Lifecycle

1. **Startup:**
   - Check dependencies (Node.js version, ports available)
   - Start services in order (proxy → stripe → preview)
   - Wait for health checks
   - Log startup status

2. **Runtime:**
   - Health check endpoints available
   - Logs written to `/tmp/pulse-*.log`
   - Process IDs tracked

3. **Shutdown:**
   - Graceful shutdown on SIGTERM/SIGINT
   - Cleanup of resources
   - Process termination

### Health Checks

All services implement health check endpoints:

```bash
# Preview server
curl http://localhost:8000/

# Background proxy
curl http://localhost:3100/background-proxy/health

# Stripe demo server
curl http://localhost:4242/stripe-demo/health
```

### Logging

Logs are written to `/tmp/`:

- Preview server: `/tmp/pulse-preview.log`
- Background proxy: `/tmp/pulse-background-proxy.log`
- Stripe demo: `/tmp/pulse-stripe-demo.log`

View logs:
```bash
tail -f /tmp/pulse-*.log
```

### Stopping Services

#### Stop All Services

```bash
pkill -f "python3 -m http.server"
pkill -f "background-proxy-server.js"
pkill -f "stripe-demo-server.js"
```

#### Stop Individual Services

```bash
# Preview server
pkill -f "python3 -m http.server"

# Background proxy
pkill -f "background-proxy-server.js"

# Stripe demo server
pkill -f "stripe-demo-server.js"
```

#### Using Cleanup Script

```bash
npm run clean
# or
bash scripts/cleanup.sh
```

---

## Port Configuration

All ports are configured in `config/ports.js`:

```javascript
const PORTS = {
  SERVER_PORT: 8000,
  STRIPE_DEMO_PORT: 4242,
  BACKGROUND_PROXY_PORT: 3100,
  WEBPACK_DEV_PORT: 3035,
  TEST_SERVER_PORT: 9898
};
```

### Environment-Specific Overrides

Test environment uses different ports:

```javascript
const PORT_OVERRIDES = {
  test: {
    SERVER_PORT: 8001,
    STRIPE_DEMO_PORT: 4243,
    BACKGROUND_PROXY_PORT: 3101
  }
};
```

### Environment Variables

Ports can be overridden via environment variables:

```bash
SERVER_PORT=8001 BACKGROUND_PROXY_PORT=3101 npm start
```

---

## Service Dependencies

### Preview Server
- **Dependencies:** None (Python HTTP server)
- **Required by:** Preview dashboard

### Background Proxy
- **Dependencies:** Node.js, Express, CORS
- **Required by:** Preview dashboard (for external backgrounds)

### Stripe Demo Server
- **Dependencies:** Node.js, Express, Stripe SDK
- **Required by:** Stripe checkout demo background (optional)

---

## Troubleshooting

### Port Conflicts

If a port is already in use:

```bash
# Find process using port
lsof -tiTCP:8000 -sTCP:LISTEN

# Kill process
kill -9 <PID>
```

### Service Won't Start

1. Check dependencies: `node --version` (should be 16+)
2. Check logs: `tail -f /tmp/pulse-*.log`
3. Verify configuration: `node -e "console.log(require('./config/ports.js').getPorts('development'))"`

### Services Start But Don't Respond

1. Wait 30 seconds for full initialization
2. Check firewall settings
3. Verify no other services are using the ports
4. Check service logs for errors

### Background Proxy Issues

- **Host not allowed:** Check `BACKGROUND_PROXY_ALLOWLIST`
- **CORS errors:** Verify proxy is running and accessible
- **Cookie banners still showing:** Check selector list in proxy code

### Stripe Demo Server Issues

- **Missing secret key:** Set `STRIPE_SECRET_KEY` environment variable
- **PaymentIntent creation fails:** Check Stripe secret key validity
- **CORS errors:** Verify server is running and accessible

---

## Related Documentation

- [Architecture Overview](overview.md) - Complete system architecture
- [Configuration API](../api/config.md) - Port configuration API
- [Getting Started](../getting-started/quick-start.md) - Quick start guide
- [Testing and Launch Guide](../getting-started/testing-and-launch-guide.md) - Testing workflows

---

**Maintained by:** Pulse Insights  
**Status:** Active development

