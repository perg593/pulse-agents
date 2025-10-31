# Pulse Widgets Test Suite

This directory contains the centralized test suite for the Pulse Widgets Theme Toolkit.

## Structure

```
tests/
├── unit/              # Unit tests
│   ├── config/       # Configuration tests
│   ├── lib/          # Utility library tests
│   └── generators/   # Theme generator tests
├── integration/      # Integration tests
│   ├── preview/      # Preview system tests
│   └── generators/   # Generator integration tests
├── fixtures/         # Shared test fixtures
├── support/          # Test utilities and helpers
└── run-all.sh        # Unified test runner
```

## Running Tests

### Run All Tests
```bash
npm test
# or
bash tests/run-all.sh
```

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

# Integration tests
node tests/integration/preview/bridge.contract.test.mjs
node tests/integration/preview/surveyBridge.integration.test.mjs
```

## Test Categories

### Unit Tests
- **config/** - Tests for configuration modules (ports, constants, paths)
- **lib/** - Tests for utility libraries (errors, logger, validators)
- **generators/** - Tests for theme generator components

### Integration Tests
- **preview/** - Tests for preview system (bridge, survey player, services)
- **generators/** - End-to-end tests for theme generation pipeline

## Adding New Tests

1. Place unit tests in `tests/unit/` under the appropriate subdirectory
2. Place integration tests in `tests/integration/` under the appropriate subdirectory
3. Add shared fixtures to `tests/fixtures/`
4. Add test utilities to `tests/support/`
5. Update `tests/run-all.sh` if adding new test categories

## Test Frameworks

- **Unit tests**: Custom test framework (simple, lightweight)
- **Integration tests**: Node.js test runner (native Node.js)
- **Generator tests**: Vitest (for TypeScript tests)

## Fixtures

Shared test fixtures are stored in `tests/fixtures/`. These include:
- Example theme data
- Mock survey responses
- Test site snapshots

## Support Utilities

Test utilities in `tests/support/` provide:
- DOM simulation helpers (`testUtils.mjs`)
- Bridge context setup
- Mock implementations

