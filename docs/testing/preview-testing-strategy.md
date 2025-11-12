# Preview System Testing Strategy

## Overview

This document outlines the testing strategy for the Pulse Widgets Preview System, including test organization, coverage goals, and best practices.

## Test Pyramid

```
        /\
       /  \     E2E Tests (Few)
      /────\    
     /      \   Integration Tests (Some)
    /────────\  
   /          \ Unit Tests (Many)
  /────────────\
```

### Unit Tests (Foundation)

**Location**: `tests/unit/preview/`

**Purpose**: Test individual components in isolation

**Coverage**: 90%+ code coverage

**Examples**:
- PresentationQueue deduplication logic
- PresentationDeduplicator time-windowed checks
- StateMachine transition validation
- EventBus event routing

**Tools**: Node.js test runner

---

### Integration Tests (Middle Layer)

**Location**: `tests/integration/preview/`

**Purpose**: Test component interactions

**Coverage**: All presentation scenarios

**Examples**:
- Bridge ↔ Player communication
- PresentationService orchestration
- Queue → Deduplicator → Service flow
- Event bus event flow

**Tools**: Node.js test runner with mocks

---

### E2E Tests (Top Layer)

**Location**: `tests/e2e/preview/`

**Purpose**: Test complete user workflows

**Coverage**: Critical user flows

**Examples**:
- Complete presentation flow
- `present` parameter scenario
- Multiple survey scenarios
- Error recovery flows

**Tools**: Playwright

---

## Test Organization

```
tests/
├── unit/
│   └── preview/
│       ├── presentationQueue.test.js
│       ├── presentationDeduplicator.test.js
│       ├── stateMachine.test.js
│       ├── eventBus.test.js
│       └── presentationService.test.js
├── integration/
│   └── preview/
│       ├── presentationScenarios.test.mjs
│       ├── presentParameter.test.mjs
│       └── raceConditions.test.mjs
├── e2e/
│   └── preview/
│       ├── completePresentationFlow.test.mjs
│       ├── multipleSurveys.test.mjs
│       └── errorRecovery.test.mjs
└── support/
    └── preview/
        ├── mockBridge.js
        ├── mockPlayer.js
        ├── mockTag.js
        └── testHelpers.js
```

## Coverage Goals

### Unit Tests
- **Target**: 90%+ code coverage
- **Focus**: All public APIs, edge cases, error conditions
- **Tools**: Coverage reporting via test framework

### Integration Tests
- **Target**: All presentation scenarios covered
- **Focus**: Component interactions, event flows
- **Tools**: Manual coverage tracking

### E2E Tests
- **Target**: All critical user flows covered
- **Focus**: End-to-end workflows, browser compatibility
- **Tools**: Playwright coverage (if available)

## Writing Tests

### Unit Test Structure

```javascript
const { Component } = require('../../preview/basic/lib/component');

test('Component handles valid input', () => {
  const component = new Component();
  const result = component.process('valid');
  assertEqual(result, 'expected');
});

test('Component rejects invalid input', () => {
  const component = new Component();
  assertThrows(() => {
    component.process(null);
  }, ValidationError);
});
```

### Integration Test Structure

```javascript
import { createMockBridge } from '../../support/preview/mockBridge.js';
import { PresentationService } from '../../preview/basic/services/presentationService.js';

test('PresentationService coordinates with bridge', async () => {
  const bridge = createMockBridge();
  const service = new PresentationService({ bridge });
  
  await service.present('1234', { source: 'test' });
  
  assert(bridge.presentCalled);
  assertEqual(bridge.lastSurveyId, '1234');
});
```

### E2E Test Structure

```javascript
import { test, expect } from '@playwright/test';

test('present parameter auto-presents survey', async ({ page }) => {
  await page.goto('http://localhost:3000/?present=1234');
  
  // Wait for survey widget
  const widget = await page.waitForSelector('#_pi_surveyWidgetContainer', {
    timeout: 10000
  });
  
  expect(widget).toBeVisible();
});
```

## Mocking Guidelines

### When to Mock

- External dependencies (Pulse Insights SDK)
- Browser APIs (postMessage, EventTarget)
- Async operations (network requests)
- Time-dependent operations (setTimeout, Date)

### Mock Structure

```javascript
function createMockBridge() {
  return {
    presentCalled: false,
    lastSurveyId: null,
    present: function(surveyId) {
      this.presentCalled = true;
      this.lastSurveyId = surveyId;
      return Promise.resolve();
    }
  };
}
```

## Test Data Fixtures

**Location**: `tests/fixtures/preview/`

**Purpose**: Reusable test data

**Examples**:
- Sample survey records
- Test configurations
- Expected outcomes

## Running Tests

### All Tests
```bash
npm test
```

### Unit Tests Only
```bash
npm run test:unit
```

### Integration Tests Only
```bash
npm run test:integration
```

### E2E Tests Only
```bash
npm run test:e2e
```

### Specific Test File
```bash
node tests/unit/preview/presentationQueue.test.js
```

## Continuous Integration

Tests should run:
- On every commit
- Before merging PRs
- On scheduled basis (nightly)

## Test Maintenance

- Update tests when APIs change
- Remove obsolete tests
- Add tests for new features
- Review coverage reports regularly

## Best Practices

1. **Test behavior, not implementation** - Focus on what, not how
2. **Use descriptive test names** - "should present survey when URL parameter set"
3. **Keep tests independent** - No shared state between tests
4. **Test edge cases** - Null, undefined, empty strings, etc.
5. **Test error conditions** - What happens when things go wrong
6. **Mock external dependencies** - Don't rely on external services
7. **Use fixtures for test data** - Don't hardcode test data
8. **Clean up after tests** - Reset state, clear timers, etc.

