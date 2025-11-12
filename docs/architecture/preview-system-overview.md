# Preview System Architecture Overview

## Purpose and Scope

The Pulse Widgets Preview System is a comprehensive testing and demonstration application for Pulse Insights survey widgets. It provides a controlled environment for testing survey presentation scenarios, themes, and behaviors.

## Key Components

### 1. Preview Application (`preview/basic/preview.js`)
- Main UI and orchestration layer
- Manages survey selection, theme application, and behavior simulation
- Coordinates between bridge, player, and tag components

### 2. Survey Bridge (`preview/app/survey/bridge.js`)
- Communication layer between preview app and player iframe
- Implements Protocol v1 for message passing
- Manages player iframe lifecycle

### 3. Player Iframe (`preview/app/survey/player.js`)
- Isolated survey execution environment
- Loads Pulse Insights tag script
- Handles survey presentation and widget rendering

### 4. Tag Script (`preview/scripts/surveys-tag.js`)
- Wrapper around Pulse Insights SDK
- Provides error handling and retry logic
- Manages deferred presentation commands

## Architecture Layers

```
┌─────────────────────────────────────────┐
│     Preview Application (UI Layer)      │
│  - Survey selection                     │
│  - Theme management                     │
│  - Behavior simulation                  │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│     Presentation Service                │
│  - State machine                       │
│  - Queue management                    │
│  - Deduplication                      │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│     Survey Bridge                       │
│  - Protocol v1                          │
│  - Message routing                     │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│     Player Iframe                       │
│  - Tag script loading                  │
│  - Widget rendering                    │
└─────────────────────────────────────────┘
```

## Data Flow

### Presentation Flow

1. **User Action** → Preview app receives presentation request
2. **Presentation Service** → Validates and queues request
3. **Deduplicator** → Checks for duplicates
4. **Queue** → Manages request priority and ordering
5. **Bridge** → Sends present command to player
6. **Player** → Executes tag script present command
7. **Tag Script** → Calls Pulse Insights SDK
8. **Widget Rendered** → Survey appears in iframe

## State Management

The system uses a state machine for presentation lifecycle:

- `idle` → Initial state, no active presentation
- `preparing` → Ensuring prerequisites (background, player, tag)
- `presenting` → Sending present command
- `presented` → Survey successfully presented
- `failed` → Presentation failed

## Component Communication

Components communicate via:
- **Event Bus**: Centralized event system for loose coupling
- **Protocol v1**: Structured messages between bridge and player
- **Direct calls**: For synchronous operations

## Technology Stack

- **Language**: JavaScript (ES6+)
- **Module System**: CommonJS
- **Browser APIs**: EventTarget, CustomEvent, postMessage
- **Testing**: Node.js test runner, Playwright (E2E)

## Key Design Patterns

1. **Service Layer**: Presentation logic extracted into services
2. **State Machine**: Explicit state management for presentation lifecycle
3. **Queue Pattern**: Request queuing with priority and deduplication
4. **Event-Driven**: Loose coupling via event bus
5. **Dependency Injection**: Services receive dependencies via constructor

## Security Considerations

- Player iframe uses sandbox attributes
- postMessage with origin validation
- No direct DOM manipulation across iframe boundaries
- CORS handling for external resources

## Performance Considerations

- Lazy loading of player iframe
- Request deduplication to prevent duplicate presentations
- Queue management to prevent resource exhaustion
- State machine prevents invalid transitions

## Future Improvements

- Web Workers for heavy processing
- Service Worker for offline support
- IndexedDB for state persistence
- WebSocket for real-time updates

