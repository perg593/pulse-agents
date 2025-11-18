# Configuration API Reference

**Location:** `config/`  
**Purpose:** Centralized configuration for ports, constants, and paths

---

## Port Configuration (`config/ports.js`)

Centralized port management for all services.

### Functions

#### `getPorts(environment)`

Get port configuration for a specific environment.

**Parameters:**
- `environment` (string, optional) - Environment name: `'development'`, `'production'`, or `'test'`. Default: `'development'`

**Returns:** Object with port configuration:
```javascript
{
  SERVER_PORT: 8000,
  STRIPE_DEMO_PORT: 4242,
  BACKGROUND_PROXY_PORT: 3100,
  WEBPACK_DEV_PORT: 3035,
  TEST_SERVER_PORT: 9898
}
```

**Example:**
```javascript
const { getPorts } = require('./config/ports');

const ports = getPorts('development');
console.log(ports.SERVER_PORT); // 8000
```

#### `getPort(portName, environment)`

Get a specific port by name.

**Parameters:**
- `portName` (string) - Name of the port: `'SERVER_PORT'`, `'STRIPE_DEMO_PORT'`, `'BACKGROUND_PROXY_PORT'`, etc.
- `environment` (string, optional) - Environment name. Default: `'development'`

**Returns:** Number - Port number

**Example:**
```javascript
const { getPort } = require('./config/ports');

const serverPort = getPort('SERVER_PORT', 'development');
console.log(serverPort); // 8000
```

### Constants

#### `PORTS`

Default port configuration object.

```javascript
const { PORTS } = require('./config/ports');
console.log(PORTS.SERVER_PORT); // 8000
```

#### `PORT_OVERRIDES`

Environment-specific port overrides.

```javascript
const { PORT_OVERRIDES } = require('./config/ports');
console.log(PORT_OVERRIDES.test.SERVER_PORT); // 8001
```

### Default Ports

| Port Name | Default | Description |
|----------|---------|-------------|
| `SERVER_PORT` | 8000 | Main preview server |
| `STRIPE_DEMO_PORT` | 4242 | Stripe demo server |
| `BACKGROUND_PROXY_PORT` | 3100 | Background proxy server |
| `WEBPACK_DEV_PORT` | 3035 | Webpack dev server (legacy) |
| `TEST_SERVER_PORT` | 9898 | Test server |

### Environment Overrides

Test environment uses different ports to avoid conflicts:

```javascript
{
  SERVER_PORT: 8001,
  STRIPE_DEMO_PORT: 4243,
  BACKGROUND_PROXY_PORT: 3101
}
```

---

## Constants (`config/constants.js`)

Behavior and UI constants for Node.js code.

### Usage

```javascript
const { PRESENTATION, VALIDATION } = require('./config/constants');
```

### Constants Groups

#### `PRESENTATION`

Presentation-related constants:
- `TIMEOUT_MS` - Presentation timeout in milliseconds
- `COOLDOWN_MS` - Cooldown period between presentations
- `DEDUPLICATION_WINDOW_MS` - Duplicate detection window
- `MAX_QUEUE_SIZE` - Maximum queue size

#### `VALIDATION`

Validation-related constants:
- `URL_TIMEOUT_MS` - URL validation timeout
- `MAX_FILE_SIZE` - Maximum file size for validation

---

## Browser Constants (`config/constants-browser.js`)

Browser-specific constants for preview application.

### Usage

```javascript
import {
  BEHAVIOR_CONSTANTS,
  UI_CONSTANTS,
  PRESENTATION_SETTINGS
} from '../../config/constants-browser.js';
```

### Constants Groups

#### `BEHAVIOR_CONSTANTS`

Behavior simulation constants:
- Scroll depth thresholds
- Rage click thresholds
- Timer intervals

#### `UI_CONSTANTS`

UI interaction constants:
- Keyboard shortcuts
- Sequence detection
- Animation durations

#### `PRESENTATION_SETTINGS`

Presentation configuration:
- Default cooldowns
- Lock durations
- Timeout values

---

## Path Utilities (`config/paths.js`)

Common path patterns and utilities.

### Functions

#### `resolveFromRoot(relativePath)`

Resolve a path relative to the project root.

**Parameters:**
- `relativePath` (string) - Path relative to project root

**Returns:** string - Absolute path

**Example:**
```javascript
const { resolveFromRoot } = require('./config/paths');

const themePath = resolveFromRoot('theme-generator/output');
console.log(themePath); // /full/path/to/pulse_widgets/theme-generator/output
```

### Common Paths

- `OUTPUT_DIR` - Theme generator output directory
- `PREVIEW_DIR` - Preview dashboard directory
- `THEMES_DIR` - Generated themes directory

---

## Environment Variables

Configuration can be overridden via environment variables:

- `SERVER_PORT` - Override preview server port
- `STRIPE_DEMO_PORT` - Override Stripe demo server port
- `BACKGROUND_PROXY_PORT` - Override background proxy port
- `NODE_ENV` - Set environment (`development`, `production`, `test`)

---

## Best Practices

1. **Always use centralized configuration** - Don't hardcode ports or paths
2. **Use environment-specific overrides** - Test environment uses different ports
3. **Validate configuration** - Use validators before using config values
4. **Document custom overrides** - If overriding defaults, document why

---

## Related Documentation

- [Error Handling API](../api/lib.md#error-handling) - Error classes
- [Validation API](../api/lib.md#validation) - Input validation
- [Path Utilities API](../api/lib.md#path-utilities) - Path utilities

