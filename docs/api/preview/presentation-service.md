# Presentation Service API

## Overview

The PresentationService orchestrates survey presentations using a state machine, queue, and deduplicator.

## Class: PresentationService

### Constructor

```javascript
const service = new PresentationService(dependencies, options);
```

**Parameters**:
- `dependencies` (Object): Service dependencies
  - `bridge` (Object): Survey bridge instance
  - `findRecord` (Function): Function to find survey record by ID
  - `ensureBackground` (Function): Function to ensure background loaded
  - `ensurePlayer` (Function): Function to ensure player loaded
  - `ensureTag` (Function): Function to ensure tag ready
  - `applyIdentifier` (Function): Function to apply identifier
  - `sendPresent` (Function): Function to send present command
- `options` (Object, optional): Configuration options
  - `timeoutMs` (number): Presentation timeout (default: 10000)
  - `cooldownMs` (number): Cooldown period (default: 10000)

**Returns**: PresentationService instance

---

### Methods

#### `present(surveyId, options)`

Present a survey.

**Parameters**:
- `surveyId` (string): Survey ID to present
- `options` (Object, optional):
  - `force` (boolean): Force presentation even if duplicate (default: false)
  - `allowDuplicate` (boolean): Allow duplicate presentations (default: false)
  - `forceReload` (boolean): Force player reload (default: false)
  - `source` (string): Source of request (default: 'unknown')

**Returns**: Promise<void>

**Example**:
```javascript
await service.present('1234', {
  source: 'manual',
  force: false
});
```

**Throws**:
- `DuplicatePresentationError`: If duplicate detected and not forced
- `PresentationError`: If presentation fails

---

#### `cancel(surveyId)`

Cancel a queued presentation request.

**Parameters**:
- `surveyId` (string): Survey ID to cancel

**Returns**: boolean - True if cancelled, false if not found

**Example**:
```javascript
const cancelled = service.cancel('1234');
```

---

#### `getState(surveyId)`

Get current presentation state.

**Parameters**:
- `surveyId` (string, optional): Survey ID to get state for

**Returns**: Object with state information:
- `currentState` (string): Current state machine state
- `currentOperation` (Object|null): Current operation details
- `queueState` (Object): Queue state
- `history` (Object|null): Presentation history for survey

**Example**:
```javascript
const state = service.getState('1234');
console.log(state.currentState); // 'idle', 'preparing', 'presenting', etc.
```

---

#### `clear()`

Clear all state (queue, deduplicator, state machine).

**Example**:
```javascript
service.clear();
```

---

## Events

The service emits events via the event bus:

- `presentation:idle` - State machine entered idle state
- `presentation:preparing` - Started preparing presentation
- `presentation:presenting` - Started presenting survey
- `presentation:presented` - Survey successfully presented
- `presentation:failed` - Presentation failed
- `presentation:queued` - Request queued
- `presentation:processed` - Request processed
- `presentation:rejected` - Request rejected
- `presentation:error` - Error occurred
- `presentation:cancelled` - Presentation cancelled
- `presentation:cleared` - State cleared

**Example**:
```javascript
const eventBus = getEventBus();
eventBus.on('presentation:presented', (data) => {
  console.log('Survey presented:', data.surveyId);
});
```

---

## State Machine States

- `idle` - No active presentation
- `preparing` - Ensuring prerequisites
- `presenting` - Sending present command
- `presented` - Survey successfully presented
- `failed` - Presentation failed

---

## Error Handling

All errors are instances of `PresentationError` or subclasses:

- `DuplicatePresentationError` - Duplicate presentation attempt
- `PresentationTimeoutError` - Presentation timed out
- `PresentationCancelledError` - Presentation was cancelled
- `PresentationError` - Generic presentation error

**Example**:
```javascript
try {
  await service.present('1234');
} catch (error) {
  if (error instanceof DuplicatePresentationError) {
    console.log('Survey already presented');
  } else if (error instanceof PresentationError) {
    console.log('Presentation failed:', error.message);
  }
}
```

---

## Usage Example

```javascript
const { PresentationService } = require('./preview/basic/services/presentationService');
const { getEventBus } = require('./preview/basic/lib/eventBus');

// Create service with dependencies
const service = new PresentationService({
  bridge: surveyBridge,
  findRecord: findRecordBySurveyId,
  ensureBackground: ensureBackgroundForRecord,
  ensurePlayer: ensurePlayerLoadedForRecord,
  ensureTag: bootPulseTag,
  applyIdentifier: applyIdentifier,
  sendPresent: sendPresentForRecord
});

// Listen to events
const eventBus = getEventBus();
eventBus.on('presentation:presented', (data) => {
  console.log('Survey presented:', data.surveyId);
});

// Present a survey
await service.present('1234', {
  source: 'manual',
  force: false
});
```

