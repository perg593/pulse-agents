# Quick Reference: Testing & Launch

## 🚀 Launch Commands

```bash
# Full preview (recommended)
npm start

# Lightweight preview (fast)
npm run start:lite

# Custom ports
SERVER_PORT=8001 BACKGROUND_PROXY_PORT=3101 npm start
```

## 🧪 Test Commands

```bash
# All tests
npm test

# Specific suites
npm run test:unit
npm run test:integration
npm run test:preview
npm run test:generators
```

## 🧹 Cleanup Commands

```bash
# Clean logs and temp files
npm run clean

# Clean everything (including build artifacts and node_modules)
npm run clean:all

# Manual cleanup
bash scripts/cleanup.sh
```

## 📍 Service Ports

- **Preview Server**: `http://localhost:8000`
- **Background Proxy**: `http://localhost:3100`
- **Stripe Demo**: `http://localhost:4242` (optional)

## 🔍 Health Checks

```bash
curl http://localhost:8000/ && echo "✅ Preview"
curl http://localhost:3100/background-proxy/health && echo "✅ Proxy"
curl http://localhost:4242/stripe-demo/health && echo "✅ Stripe"
```

## 🛑 Stop Services

```bash
# Stop all
pkill -f "python3 -m http.server"
pkill -f "background-proxy-server.js"
pkill -f "stripe-demo-server.js"

# Or use cleanup script
npm run clean
```

## 📋 Log Files

- Preview: `/tmp/pulse-preview.log`
- Proxy: `/tmp/pulse-background-proxy.log`
- Stripe: `/tmp/pulse-stripe-demo.log`

View logs: `tail -f /tmp/pulse-*.log`

## 📚 Full Documentation

See [Testing and Launch Guide](docs/getting-started/testing-and-launch-guide.md) for complete details.
