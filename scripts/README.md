# Pulse Widgets Scripts

This directory contains all scripts for building, launching, and managing the Pulse Widgets system.

## Structure

```
scripts/
├── launch/          # Launch scripts
├── build/           # Build scripts
├── dev/             # Development scripts
└── utils/           # Utility scripts
```

## Launch Scripts (`launch/`)

### `preview.sh`
Main preview launcher - starts all services including preview server, Stripe demo server, and background proxy.

```bash
./scripts/launch/preview.sh
# or
npm start
```

### `preview-lite.sh`
Lightweight launcher - starts only preview server and background proxy (skips build steps).

```bash
./scripts/launch/preview-lite.sh
# or
npm start:lite
```

### `services.sh`
Service management script - handles starting/stopping services, health checks, and cleanup.

```bash
./scripts/launch/services.sh
```

## Build Scripts (`build/`)

### `generate-widgets.js`
Generates preview widget HTML from pi-master runtime.

```bash
node scripts/build/generate-widgets.js
# or
npm run build:widgets
```

### `preview-data.js`
Builds preview manifest and default CSS.

```bash
node scripts/build/preview-data.js
```

### `demo-data.js`
Builds demo survey dataset.

```bash
node scripts/build/demo-data.js
```

### `apply-theme.js`
Applies theme to preview.

```bash
node scripts/build/apply-theme.js
```

### Combined Build
```bash
npm run build
```

Runs `preview-data.js` and `demo-data.js` together.

## Development Scripts (`dev/`)

### Theme Generator v2
```bash
npm run dev:theme-v2
```

Starts the development server for theme-generator/v2 (TypeScript web UI version).

## Usage

All scripts should be run from the project root directory. Scripts automatically resolve paths relative to the project root.

## Environment Variables

Scripts respect environment variables for configuration:
- `SERVER_PORT` - Preview server port (default: 8000)
- `STRIPE_DEMO_PORT` - Stripe demo server port (default: 4242)
- `BACKGROUND_PROXY_PORT` - Background proxy port (default: 3100)
- `LOG_FILE` - Log file path (default: /tmp/pulse-preview.log)

## Notes

- Launch scripts automatically install dependencies if missing
- Build scripts check for required directories before running
- All scripts include error handling and cleanup procedures

