# Quick Start Guide

**Last Updated:** 2025-02-15

Get up and running with the Pulse Agents Preview Dashboard in minutes.

**Note:** The theme generator has been moved to a separate repository: https://github.com/perg593/theme-generator

---

## Prerequisites

- **Node.js** 16+ (check with `node --version`)
- **Python 3** (for preview server)
- **npm** (comes with Node.js)

---

## Installation

### 1. Install Root Dependencies

```bash
npm install
```

---

## Quick Start: Launch Preview Dashboard

```bash
npm start
```

This starts:
- Preview server (port 8000)
- Background proxy (port 3100)
- Stripe demo server (port 4242, if `STRIPE_SECRET_KEY` is set)

### Step 3: Open Preview

Open your browser to:
```
http://localhost:8000/preview/index.html
```

The preview redirects to `/preview/basic/` for the streamlined experience.

---

## Common Commands

### Launch Commands

```bash
# Full preview (recommended) - builds data and starts all services
npm start

# Lightweight preview (fast) - skips build steps
npm run start:lite

# Custom ports
SERVER_PORT=8001 BACKGROUND_PROXY_PORT=3101 npm start
```

### Test Commands

```bash
# All tests
npm test

# Specific suites
npm run test:unit          # Unit tests only
npm run test:integration   # Integration tests only
npm run test:preview       # Preview tests only
npm run test:generators    # Theme generator tests
```

### Build Commands

```bash
# Build preview data and demo data
npm run build

# Build widgets
npm run build:widgets

# Build theme generator preview manifest
cd theme-generator/v1 && npm run preview:build
```

### Cleanup Commands

```bash
# Clean logs and temp files
npm run clean

# Clean everything (including build artifacts and node_modules)
npm run clean:all

# Manual cleanup
bash scripts/cleanup.sh
```

---

## Service Ports

| Service | Port | URL | Purpose |
|--------|------|-----|---------|
| Preview Server | 8000 | http://localhost:8000 | Serves static files and preview dashboard |
| Background Proxy | 3100 | http://localhost:3100 | Proxies external sites for iframe embedding |
| Stripe Demo Server | 4242 | http://localhost:4242 | Creates PaymentIntents (optional) |

All ports are configurable via `config/ports.js` or environment variables.

---

## Health Checks

Verify all services are running:

```bash
curl http://localhost:8000/ && echo "✅ Preview Server"
curl http://localhost:3100/background-proxy/health && echo "✅ Background Proxy"
curl http://localhost:4242/stripe-demo/health && echo "✅ Stripe Demo Server"
```

---

## Stop Services

### Stop All Services

```bash
pkill -f "python3 -m http.server"
pkill -f "background-proxy-server.js"
pkill -f "stripe-demo-server.js"
```

### Or Use Cleanup Script

```bash
npm run clean
```

---

## Log Files

Logs are written to `/tmp/`:

- Preview Server: `/tmp/pulse-preview.log`
- Background Proxy: `/tmp/pulse-background-proxy.log`
- Stripe Demo: `/tmp/pulse-stripe-demo.log`

View logs:
```bash
tail -f /tmp/pulse-*.log
```

---

## Next Steps

### Learn More

- **[Application Overview](../application-overview.md)** - Complete application overview
- **[Architecture Overview](../architecture/overview.md)** - System architecture
- **[Setup Guide](setup-guide.md)** - Detailed installation instructions
- **[Testing and Launch Guide](testing-and-launch-guide.md)** - Testing workflows

### Common Workflows

- **[Generate Themes](../../README.md#3-generate-themes-from-a-live-site)** - Theme generation workflow
- **[Preview Dashboard](../../README.md#5-launch-the-demo-studio)** - Preview dashboard usage
- **[Service Management](../../README.md#service-management)** - Service management

### Troubleshooting

- **[Deployment Troubleshooting](../deployment/troubleshooting.md)** - Deployment issues
- **[Service Troubleshooting](../architecture/services.md#troubleshooting)** - Service issues

---

## Quick Reference

### Generate Theme
```bash
cd theme-generator/v1
node main.js <website-url> <client-name>
```

### Launch Preview
```bash
npm start
```

### Run Tests
```bash
npm test
```

### Check Services
```bash
curl http://localhost:8000/ && echo "✅ Preview"
curl http://localhost:3100/background-proxy/health && echo "✅ Proxy"
curl http://localhost:4242/stripe-demo/health && echo "✅ Stripe"
```

---

**Need help?** Check the [full documentation](../README.md) or [troubleshooting guides](../deployment/troubleshooting.md).
