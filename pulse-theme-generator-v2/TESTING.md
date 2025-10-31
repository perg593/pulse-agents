# Local Testing Guide

## Prerequisites

1. **Node.js**: Version 18+ required
2. **Dependencies**: Install with `npm install`
3. **Playwright**: Browser binaries for extraction tests (optional, only if testing extraction)

## Quick Start

```bash
# Install dependencies
npm install

# Run all tests
npm test

# Run tests in watch mode (for development)
npx vitest

# Run tests with coverage
npx vitest --coverage
```

## Running Unit Tests

### Run All Tests

```bash
npm test
```

### Run Specific Test Files

```bash
# Run parser tests only
npx vitest tests/parser.test.ts

# Run mapper tests only
npx vitest tests/mapper.test.ts
```

### Run Tests in Watch Mode

```bash
# Watch mode - reruns tests on file changes
npx vitest --watch

# Watch mode with UI
npx vitest --ui
```

### Run Tests with Coverage

```bash
npx vitest --coverage
```

## Testing the Application

### 1. Test the Web UI

```bash
# Start the dev server
npm run dev

# Or with custom port
PORT=3000 npm run dev
```

Then open http://localhost:5173 (or your custom port) in your browser.

**Environment Variables:**
```bash
# Set SASS root path (optional)
export PULSE_SASS_ROOT=/path/to/sass

# Set output directory (optional)
export PULSE_OUTPUT_DIR=./custom-output

# Start server
npm run dev
```

### 2. Test CLI Extraction

```bash
# Extract theme from a website
npm run extract -- --url https://example.com

# With options
npm run extract -- \
  --url https://example.com \
  --pages 3 \
  --scheme light \
  --out ./output \
  --sass /path/to/sass
```

### 3. Test CLI Mapping

```bash
# Map raw findings to schema
npm run map -- --raw ./output/raw-findings.json

# With custom output and SASS root
npm run map -- \
  --raw ./output/raw-findings.json \
  --out ./output \
  --sass /path/to/sass
```

## Test Structure

```
tests/
├── parser.test.ts      # SASS parser unit tests
└── mapper.test.ts      # Mapper confidence scoring tests
```

## Writing New Tests

Create test files in the `tests/` directory:

```typescript
import { describe, it, expect } from "vitest";
import { yourFunction } from "../src/yourModule.js";

describe("Your Module", () => {
  it("should do something", () => {
    expect(yourFunction()).toBe(expected);
  });
});
```

## Debugging Tests

### Run Single Test

```bash
# Run a specific test by name
npx vitest -t "should parse simple SASS variables"
```

### Debug Mode

```bash
# Run in debug mode (for VS Code debugging)
npx vitest --inspect-brk
```

Then attach VS Code debugger to port 9229.

### Verbose Output

```bash
# Show detailed test output
npx vitest --reporter=verbose
```

## Integration Testing

For integration tests that require network access or Playwright:

```bash
# Run all tests (including integration)
npm test

# Skip network tests (if needed)
SKIP_PUBLIC_SITE_TESTS=1 npm test
```

## Environment Setup

### Required Environment Variables (Optional)

```bash
# SASS root directory (defaults to ../Old-Pulse-Themes-Framework-2025/01-css-pulse)
export PULSE_SASS_ROOT=/path/to/sass

# Output directory (defaults to ./output)
export PULSE_OUTPUT_DIR=./output
```

### Example .env File

Create a `.env` file in the project root:

```env
PULSE_SASS_ROOT=/path/to/your/sass
PULSE_OUTPUT_DIR=./test-output
PORT=5173
```

## Common Issues

### Tests Fail: "Cannot find module"

**Solution**: Make sure you've run `npm install` and that TypeScript compiles:
```bash
npm run build
```

### Playwright Browser Not Found

**Solution**: Install Playwright browsers:
```bash
npx playwright install chromium
```

### Schema Cache Issues

**Solution**: Clear the cache directory:
```bash
rm -rf .cache/
```

### Port Already in Use

**Solution**: Use a different port:
```bash
PORT=3000 npm run dev
```

## Continuous Testing

For TDD workflow, run tests in watch mode:

```bash
# Terminal 1: Watch mode
npx vitest --watch

# Terminal 2: Run dev server
npm run dev
```

## Test Coverage

Generate coverage report:

```bash
npx vitest --coverage
```

Coverage report will be generated in `coverage/` directory.

## Next Steps

1. **Add more tests**: Extend test coverage for extractor, legacy compiler, etc.
2. **Integration tests**: Add end-to-end tests with real websites
3. **Visual regression**: Add screenshot comparison tests
4. **Performance tests**: Add benchmarks for large sites

## Troubleshooting

If tests fail:

1. Check Node.js version: `node --version` (should be 18+)
2. Clear node_modules and reinstall: `rm -rf node_modules && npm install`
3. Clear cache: `rm -rf .cache/`
4. Check TypeScript compilation: `npm run build`
5. Check for linting errors: Run your IDE's linter

For more help, see the main README.md or check the test output for specific error messages.

