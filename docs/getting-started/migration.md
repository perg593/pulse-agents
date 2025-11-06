# Migration Guide

This guide helps you migrate from the old pulse widgets codebase to the new standardized version.

## Overview

The codebase has been significantly refactored to improve maintainability, reliability, and developer experience. This migration guide covers the breaking changes and how to adapt your code.

## Breaking Changes

### 1. Configuration System

**Before:**
```javascript
// Hardcoded values scattered throughout codebase
const SERVER_PORT = 8000;
const STRIPE_DEMO_PORT = 4242;
const BEHAVIOR_IDLE_MS = 10000;
```

**After:**
```javascript
// Centralized configuration
const { getPort } = require('./config/ports.js');
const { BEHAVIOR_CONSTANTS } = require('./config/constants.js');

const SERVER_PORT = getPort('SERVER_PORT', 'development');
const BEHAVIOR_IDLE_MS = BEHAVIOR_CONSTANTS.IDLE_MS;
```

### 2. Error Handling

**Before:**
```javascript
// Inconsistent error handling
console.error('Error:', error.message);
throw new Error('Something went wrong');
```

**After:**
```javascript
// Standardized error handling
const { ErrorFactory, ErrorHandler } = require('./lib/errors.js');
const { log } = require('./lib/logger.js');

try {
  // ... code ...
} catch (error) {
  const customError = ErrorFactory.themeGeneration('Theme failed', themeName, [error.message]);
  log.error('Theme generation failed', customError, { themeName });
  throw customError;
}
```

### 3. Input Validation

**Before:**
```javascript
// No validation or basic checks
if (!url) {
  console.error('URL is required');
  process.exit(1);
}
```

**After:**
```javascript
// Comprehensive validation
const { URLValidator, ParameterValidator } = require('./lib/validators.js');

const urlValidation = URLValidator.isValid(url);
if (!urlValidation.valid) {
  const error = ErrorFactory.validation(`Invalid URL: ${urlValidation.error}`, 'url', url);
  log.error('URL validation failed', error);
  process.exit(1);
}
```

### 4. Logging

**Before:**
```javascript
// Inconsistent logging
console.log('Starting process...');
console.error('Error occurred');
console.warn('Warning message');
```

**After:**
```javascript
// Standardized logging
const { log } = require('./lib/logger.js');

log.info('Starting process...');
log.error('Error occurred', error);
log.warn('Warning message');
```

## Migration Steps

### Step 1: Update Dependencies

1. Install new dependencies:
```bash
npm install
```

2. Update Puppeteer in legacy packages:
```bash
cd legacy/theme-mvp
npm install
```

### Step 2: Update Configuration Usage

1. Replace hardcoded ports with centralized config:
```javascript
// Old
const PORT = 8000;

// New
const { getPort } = require('./config/ports.js');
const PORT = getPort('SERVER_PORT', 'development');
```

2. Replace hardcoded constants:
```javascript
// Old
const IDLE_MS = 10000;

// New
const { BEHAVIOR_CONSTANTS } = require('./config/constants.js');
const IDLE_MS = BEHAVIOR_CONSTANTS.IDLE_MS;
```

### Step 3: Update Error Handling

1. Replace console.error with standardized logging:
```javascript
// Old
console.error('Error:', error.message);

// New
const { log } = require('./lib/logger.js');
log.error('Error occurred', error);
```

2. Use custom error classes:
```javascript
// Old
throw new Error('Theme generation failed');

// New
const { ErrorFactory } = require('./lib/errors.js');
throw ErrorFactory.themeGeneration('Theme generation failed', themeName);
```

### Step 4: Add Input Validation

1. Validate command line arguments:
```javascript
// Old
const url = process.argv[2];
if (!url) {
  console.error('URL is required');
  process.exit(1);
}

// New
const { ParameterValidator } = require('./lib/validators.js');
const schema = {
  url: { type: 'string', required: true }
};
const validation = ParameterValidator.validateArgs(process.argv.slice(2), schema);
if (!validation.valid) {
  validation.errors.forEach(error => console.error(`  - ${error}`));
  process.exit(1);
}
```

2. Validate file operations:
```javascript
// Old
if (!fs.existsSync(filePath)) {
  console.error('File not found');
  process.exit(1);
}

// New
const { FileValidator } = require('./lib/validators.js');
if (!FileValidator.exists(filePath)) {
  const error = ErrorFactory.fileOperation('File not found', filePath, 'read');
  log.error('File operation failed', error);
  process.exit(1);
}
```

### Step 5: Update Path Handling

1. Use path utilities:
```javascript
// Old
const outputPath = path.resolve(process.cwd(), 'output', 'file.css');

// New
const { PathUtils } = require('./lib/paths.js');
const outputPath = PathUtils.resolveFromRoot('output/file.css');
```

### Step 6: Update Scripts

1. Update shell scripts to use centralized config:
```bash
# Old
SERVER_PORT="${SERVER_PORT:-8000}"

# New
PORTS_CONFIG=$(node -e "
  const config = require('${ROOT_DIR}/config/ports.js');
  const ports = config.getPorts('development');
  console.log('SERVER_PORT=' + ports.SERVER_PORT);
")
eval "${PORTS_CONFIG}"
```

## Deprecated Patterns

### ❌ Deprecated: Silent Error Catching
```javascript
// Don't do this
try {
  // ... code ...
} catch (error) {
  /* ignore */
}
```

### ✅ Recommended: Proper Error Handling
```javascript
// Do this instead
try {
  // ... code ...
} catch (error) {
  log.warn('Operation failed, continuing with fallback', error);
  // Handle gracefully or use fallback
}
```

### ❌ Deprecated: Hardcoded Values
```javascript
// Don't do this
const PORT = 8000;
const TIMEOUT = 5000;
```

### ✅ Recommended: Configuration Constants
```javascript
// Do this instead
const { getPort } = require('./config/ports.js');
const { BEHAVIOR_CONSTANTS } = require('./config/constants.js');

const PORT = getPort('SERVER_PORT', 'development');
const TIMEOUT = BEHAVIOR_CONSTANTS.OVERLAY_AUTO_HIDE_MS;
```

### ❌ Deprecated: Basic Console Logging
```javascript
// Don't do this
console.log('Starting process...');
console.error('Error occurred');
```

### ✅ Recommended: Standardized Logging
```javascript
// Do this instead
const { log } = require('./lib/logger.js');

log.info('Starting process...');
log.error('Error occurred', error);
```

## Testing

After migration, run the test suite to ensure everything works:

```bash
# Run all tests
node test/run-tests.js

# Run specific tests
node test/errors.test.js
node test/validators.test.js
node test/logger.test.js
node test/config.test.js
```

## Troubleshooting

### Common Issues

1. **Module not found errors**: Ensure all dependencies are installed with `npm install`

2. **Configuration errors**: Check that config files exist and are properly formatted

3. **Port conflicts**: Use the centralized port configuration to avoid conflicts

4. **Validation failures**: Check input parameters against the validation schemas

### Getting Help

If you encounter issues during migration:

1. Check the test suite for examples of proper usage
2. Review the error messages for specific guidance
3. Check the configuration files for correct values
4. Ensure all dependencies are up to date

## Rollback Plan

If you need to rollback changes:

1. The old code patterns are still supported but deprecated
2. You can gradually migrate components one at a time
3. The new utilities are backward compatible where possible
4. Legacy files are preserved in the `legacy/` directory

## Future Updates

This migration establishes the foundation for future improvements:

- Enhanced error recovery strategies
- More comprehensive validation rules
- Additional logging levels and formatting options
- Extended configuration options
- Performance monitoring and metrics

The new architecture makes it easier to add these features without breaking existing functionality.
