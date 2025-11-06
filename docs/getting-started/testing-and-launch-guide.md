# Testing and Launch Guide

This guide explains how to test the application, launch services, and clean up temporary files.

## Prerequisites

Before starting, ensure you have:
- **Node.js 16+** (`node --version`)
- **Python 3** (`python3 --version`)
- **npm** (comes with Node.js)
- **curl** (for health checks)
- **lsof** (for port management)

## Quick Start

### Launch Full Preview (Recommended)

```bash
npm start
# or
npm run dev
# or
bash scripts/launch/preview.sh
```

This will:
- ✅ Install dependencies automatically
- ✅ Build widgets and demo data
- ✅ Start all required services
- ✅ Run theme generator tests
- ✅ Open at `http://localhost:8000/preview/basic/`

### Launch Lightweight Preview (Fast)

For quick testing without full builds:

```bash
npm run start:lite
# or
bash scripts/launch/preview-lite.sh
```

This skips:
- Widget generation
- Demo data builds
- Theme exports
- Tests

But still starts:
- ✅ Preview server (port 8000)
- ✅ Background proxy (port 3100)

## Service Architecture

The application runs multiple services:

| Service | Port | Purpose | Required |
|---------|------|---------|----------|
| **Preview Server** | 8000 | Main static file server | ✅ Yes |
| **Background Proxy** | 3100 | Proxies external sites for iframe embedding | ✅ Yes |
| **Stripe Demo** | 4242 | Stripe checkout demo background | ⚠️ Optional |

### Port Configuration

Ports are configured in `config/ports.js`. Override via environment variables:

```bash
SERVER_PORT=8001 npm start              # Custom preview port
BACKGROUND_PROXY_PORT=3101 npm start   # Custom proxy port
STRIPE_DEMO_PORT=4243 npm start        # Custom Stripe port
```

## Running Tests

### Run All Tests

```bash
npm test
# or
bash tests/run-all.sh
```

This runs:
- Unit tests (config, lib utilities)
- Integration tests (preview bridge, survey player)
- Theme generator tests (v1 and v2)

### Run Specific Test Suites

```bash
# Unit tests only
npm run test:unit

# Integration tests only
npm run test:integration

# Preview tests only
npm run test:preview

# Generator tests only
npm run test:generators
```

### Run Individual Test Files

```bash
# Unit tests
node tests/unit/config/config.test.js
node tests/unit/lib/errors.test.js
node tests/unit/lib/logger.test.js
node tests/unit/lib/validators.test.js

# Integration tests
node tests/integration/preview/bridge.contract.test.mjs
node tests/integration/preview/surveyBridge.integration.test.mjs
```

## Service Management

### Starting Services

#### Full Service Stack
```bash
npm start
```

#### Individual Services

**Preview Server:**
```bash
python3 -m http.server 8000
```

**Background Proxy:**
```bash
cd preview/scripts
node background-proxy-server.js
# Runs on port 3100 by default
```

**Stripe Demo Server:**
```bash
cd preview/scripts
node stripe-demo-server.js
# Runs on port 4242 by default
```

### Stopping Services

#### Stop All Services
```bash
# Graceful shutdown
pkill -f "python3 -m http.server"
pkill -f "background-proxy-server.js"
pkill -f "stripe-demo-server.js"

# Wait for cleanup
sleep 3
```

#### Stop Individual Services

**By Process Name:**
```bash
pkill -f "python3 -m http.server"        # Preview server
pkill -f "background-proxy-server.js"    # Background proxy
pkill -f "stripe-demo-server.js"         # Stripe demo
```

**By Port:**
```bash
# Find process using port
lsof -tiTCP:8000 -sTCP:LISTEN

# Kill process on port
lsof -tiTCP:8000 -sTCP:LISTEN | xargs kill
lsof -tiTCP:3100 -sTCP:LISTEN | xargs kill
lsof -tiTCP:4242 -sTCP:LISTEN | xargs kill
```

### Health Checks

Check if services are running:

```bash
# Preview server
curl http://localhost:8000/ && echo "✅ Preview Server"

# Background proxy
curl http://localhost:3100/background-proxy/health && echo "✅ Background Proxy"

# Stripe demo
curl http://localhost:4242/stripe-demo/health && echo "✅ Stripe Demo"
```

### Service Status

Check what's listening on ports:

```bash
# Check all service ports
lsof -tiTCP:8000 -sTCP:LISTEN && echo "Preview server running"
lsof -tiTCP:3100 -sTCP:LISTEN && echo "Background proxy running"
lsof -tiTCP:4242 -sTCP:LISTEN && echo "Stripe demo running"
```

## Log Files

### Log Locations

| Service | Log File | Default Location |
|---------|----------|------------------|
| Preview Server | `LOG_FILE` | `/tmp/pulse-preview.log` |
| Background Proxy | `BACKGROUND_PROXY_LOG` | `/tmp/pulse-background-proxy.log` |
| Stripe Demo | `STRIPE_DEMO_LOG` | `/tmp/pulse-stripe-demo.log` |
| Preview Lite | `LOG_FILE` | `/tmp/pulse-preview-basic.log` |

### View Logs

```bash
# Tail preview server logs
tail -f /tmp/pulse-preview.log

# Tail background proxy logs
tail -f /tmp/pulse-background-proxy.log

# Tail Stripe demo logs
tail -f /tmp/pulse-stripe-demo.log

# View all logs
tail -f /tmp/pulse-*.log
```

### Custom Log Locations

Override log file locations:

```bash
LOG_FILE=/path/to/custom.log npm start
BACKGROUND_PROXY_LOG=/path/to/proxy.log npm start
STRIPE_DEMO_LOG=/path/to/stripe.log npm start
```

## Cleanup

### Clean Log Files

```bash
# Remove all Pulse log files
rm -f /tmp/pulse-*.log

# Remove specific log files
rm -f /tmp/pulse-preview.log
rm -f /tmp/pulse-background-proxy.log
rm -f /tmp/pulse-stripe-demo.log
rm -f /tmp/pulse-preview-basic.log
```

### Clean Build Artifacts

```bash
# Remove node_modules (will be reinstalled on next start)
rm -rf node_modules
rm -rf theme-generator/v1/node_modules
rm -rf theme-generator/v2/node_modules
rm -rf pi-master/node_modules

# Remove build outputs
rm -rf theme-generator/v1/output
rm -rf theme-generator/v2/output
rm -rf preview/dist
```

### Clean Temporary Files

```bash
# Remove temporary directories
rm -rf tmp/
rm -rf temp/
rm -rf .tmp/

# Remove OS files
find . -name ".DS_Store" -delete
find . -name "Thumbs.db" -delete
```

### Full Cleanup Script

```bash
#!/bin/bash
# Clean all temporary files and logs

echo "🧹 Cleaning up..."

# Stop services
pkill -f "python3 -m http.server" 2>/dev/null
pkill -f "background-proxy-server.js" 2>/dev/null
pkill -f "stripe-demo-server.js" 2>/dev/null

# Remove logs
rm -f /tmp/pulse-*.log

# Remove temporary files
rm -rf tmp/ temp/ .tmp/

# Remove OS files
find . -name ".DS_Store" -delete 2>/dev/null

echo "✅ Cleanup complete"
```

## Troubleshooting

### Port Already in Use

If you get "port already in use" errors:

```bash
# Find what's using the port
lsof -tiTCP:8000 -sTCP:LISTEN
lsof -tiTCP:3100 -sTCP:LISTEN
lsof -tiTCP:4242 -sTCP:LISTEN

# Kill the process
kill -9 <PID>
```

### Services Won't Start

1. **Check dependencies:**
   ```bash
   node --version    # Should be 16+
   python3 --version # Should be 3.x
   ```

2. **Check logs:**
   ```bash
   tail -f /tmp/pulse-preview.log
   ```

3. **Verify configuration:**
   ```bash
   node -e "console.log(require('./config/ports.js').getPorts('development'))"
   ```

4. **Reinstall dependencies:**
   ```bash
   npm install
   cd theme-generator/v1 && npm install
   cd theme-generator/v2 && npm install
   ```

### Services Start But Don't Respond

1. Wait 30 seconds for full initialization
2. Check firewall settings
3. Verify no other services are using the ports
4. Check service logs for errors
5. Try restarting services:
   ```bash
   # Stop all
   pkill -f "python3 -m http.server"
   pkill -f "background-proxy-server.js"
   sleep 3
   
   # Start again
   npm start
   ```

### Test Failures

1. **Ensure services are running:**
   ```bash
   curl http://localhost:8000/ && echo "Preview OK"
   ```

2. **Check test dependencies:**
   ```bash
   npm install
   ```

3. **Run tests individually:**
   ```bash
   node tests/unit/config/config.test.js
   ```

4. **Check test logs for specific errors**

## Development Workflow

### Typical Development Session

1. **Start services:**
   ```bash
   npm start
   ```

2. **Open preview:**
   ```
   http://localhost:8000/preview/basic/
   ```

3. **Make changes** to code

4. **Run tests:**
   ```bash
   npm test
   ```

5. **Check logs** if issues occur:
   ```bash
   tail -f /tmp/pulse-preview.log
   ```

6. **Stop services** when done:
   ```bash
   pkill -f "python3 -m http.server"
   pkill -f "background-proxy-server.js"
   ```

### Quick Iteration (Lite Mode)

For rapid development without full builds:

```bash
# Start lightweight preview
npm run start:lite

# Make changes
# Refresh browser

# Run specific tests
npm run test:unit
```

## Environment Variables

Control service behavior with environment variables:

```bash
# Ports
SERVER_PORT=8001
BACKGROUND_PROXY_PORT=3101
STRIPE_DEMO_PORT=4243

# Logs
LOG_FILE=/custom/path.log
BACKGROUND_PROXY_LOG=/custom/proxy.log

# Feature flags
RUN_WIDGETS=0              # Skip widget generation
RUN_DEMO_DATA=0            # Skip demo data build
RUN_EXAMPLES=0             # Skip theme exports
RUN_PREVIEW_BUILD=0        # Skip preview build
RUN_TESTS=0                # Skip tests
RUN_STRIPE_DEMO_SERVER=0   # Don't start Stripe demo
RUN_BACKGROUND_PROXY=0     # Don't start background proxy
```

## Next Steps

- See [Quick Start Guide](quick-start.md) for first-time setup
- See [Architecture Documentation](../architecture/) for system design
- See [Preview Guide](../preview/) for preview features
- See [Theme Generator Guide](../theme-generator/) for theme generation

