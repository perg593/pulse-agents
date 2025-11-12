# DevTools Trigger Analysis: Sociable Society Demo

## Overview

Analysis of DevTools detection mechanisms and their impact on trigger behavior in the survey player system.

## DevTools Detection Mechanisms

### 1. Viewport Polling (Lines 112-142 in `player.js`)

The player implements DevTools-aware viewport change detection:

```112:142:preview/app/survey/player.js
// DevTools-aware viewport change detection
// DevTools opening/closing may not always trigger resize events reliably
let viewportPollInterval = null;
let lastPolledViewport = { width: window.innerWidth, height: window.innerHeight };

function startViewportPolling() {
  if (viewportPollInterval) return;
  viewportPollInterval = window.setInterval(() => {
    const currentViewport = { width: window.innerWidth, height: window.innerHeight };
    const viewportChanged = 
      Math.abs(currentViewport.width - lastPolledViewport.width) > 50 ||
      Math.abs(currentViewport.height - lastPolledViewport.height) > 50;
    
    if (viewportChanged) {
      lastPolledViewport = currentViewport;
      refreshGeometryState();
    }
  }, 500);
}

function stopViewportPolling() {
  if (viewportPollInterval) {
    clearInterval(viewportPollInterval);
    viewportPollInterval = null;
  }
}

// Start polling on load
if (!document.hidden) {
  startViewportPolling();
}

// Use ResizeObserver if available for more reliable viewport change detection
if (typeof window.ResizeObserver === 'function') {
  const viewportResizeObserver = new ResizeObserver(() => {
    refreshGeometryState();
  });
  viewportResizeObserver.observe(document.documentElement);
}
```

**Purpose**: DevTools opening/closing may not reliably trigger `resize` events, so the code polls every 500ms to detect viewport changes.

**Impact**: When DevTools opens, the viewport height changes, triggering geometry state refreshes.

### 2. Adaptive Timeout Detection (Lines 536-568 in `player.js`)

The `finalizePresentAck` function includes DevTools detection to adjust timeouts:

```536:568:preview/app/survey/player.js
function finalizePresentAck(ackId, extra = {}) {
  if (!ackId) {
    broadcastStatus(extra);
    return;
  }
  // Adaptive timeout: increase if page seems slow or DevTools might be open
  // Base timeout increased from 2400ms to 4000ms for better reliability
  let timeoutMs = 4000;
  
  // Detect slow rendering: if page load took long, extend timeout
  if (typeof window.performance !== 'undefined' && window.performance.timing) {
    const loadTime = window.performance.timing.loadEventEnd - window.performance.timing.navigationStart;
    if (loadTime > 3000) {
      timeoutMs = 6000; // Extend timeout for slow pages
    }
  }
  
  // Detect potential DevTools: if outerHeight significantly different from innerHeight
  // This suggests DevTools might be open (though not always reliable)
  if (typeof window.outerHeight !== 'undefined' && window.outerHeight > 0) {
    const heightDiff = window.outerHeight - window.innerHeight;
    if (heightDiff > 200 || heightDiff < -200) {
      timeoutMs = Math.max(timeoutMs, 5000); // Extend timeout if DevTools might be affecting layout
    }
  }
  
  waitForVisibleGeometry(timeoutMs).then((geometryState) => {
    const snapshot = geometryState || captureWidgetGeometryState();
    const payload = { ok: true, ...extra };
    sendAckStatus(ackId, payload, { geometryOverride: snapshot });
    broadcastStatus(payload, { geometryOverride: snapshot });
  });
}
```

**Detection Method**: Compares `window.outerHeight` vs `window.innerHeight`. If the difference exceeds 200px (either direction), it assumes DevTools might be open.

**Timeout Adjustment**: Extends timeout to at least 5000ms when DevTools is detected.

## Trigger Flow

### Trigger Execution Path

1. **User Action** → Trigger button clicked in UI (`preview/app/main.js:373-389`)
2. **Bridge Layer** → `surveyBridge.sendTrigger(triggerId)` (`preview/app/survey/bridge.js:265-267` or `594-610`)
3. **Player Layer** → `runTrigger(triggerId)` (`preview/app/survey/player.js:570-607`)
4. **Event Simulation** → Triggers dispatch DOM events or call tag functions

### Available Triggers

```362:371:preview/app/main.js
function buildTriggerConfig() {
  return [
    { id: 'present-selected', label: 'Present Selected' },
    { id: 'exit-intent', label: 'Simulate Exit Intent' },
    { id: 'rage-click', label: 'Simulate Rage Click' },
    { id: 'scroll-depth', label: 'Simulate Scroll Depth' },
    { id: 'time-delay', label: 'Simulate Timer' },
    { id: 'pageview', label: 'Increment Pageview' }
  ];
}
```

## Potential Issues with DevTools Open

### 1. Geometry State Race Conditions

**Problem**: When DevTools opens/closes:
- Viewport size changes rapidly
- Multiple geometry refresh cycles may fire
- `waitForVisibleGeometry()` timeout may expire before widget becomes visible
- Widget visibility detection may be inconsistent

**Evidence**: The code includes extensive geometry debugging logs:
```1233:1289:preview/app/survey/player.js
  // Log visibility determination for debugging
  if (!isVisible && area > 0) {
    console.debug('[player] widget not visible despite area', {
      area,
      visibility,
      display,
      opacity,
      isIntersecting: intersectionEntry?.isIntersecting,
      intersectionRatio: intersectionEntry?.intersectionRatio
    });
  }
  
  updateGeometryState(state);
}

function updateGeometryState(state) {
  const currentViewport = {
    width: window.innerWidth || 0,
    height: window.innerHeight || 0
  };
  const viewportChanged = 
    Math.abs(currentViewport.width - lastViewportSize.width) > 1 ||
    Math.abs(currentViewport.height - lastViewportSize.height) > 1;
  
  const signature = computeGeometrySignature(state.widget, currentViewport);
  const signatureMatches = signature === geometryStateSignature;
  
  // Force update if viewport changed, even if widget coordinates are the same
  if (signatureMatches && !viewportChanged) {
    return;
  }
  
  // Log geometry state changes for debugging
  if (viewportChanged) {
    console.debug('[player] viewport size changed, forcing geometry update', {
      previous: lastViewportSize,
      current: currentViewport,
      widgetVisible: state.widget?.visible
    });
  }
  
  geometryStateSignature = signature;
  lastViewportSize = currentViewport;
  currentGeometryState = cloneGeometryState(state);
  
  console.debug('[player] geometry state updated', {
    widgetVisible: state.widget?.visible,
    widgetBounds: state.widget?.bounds,
    placement: state.placement,
    viewport: currentViewport,
    signature
  });
  
  broadcastStatus({}, { geometryOverride: currentGeometryState });
  postLegacyStatus('widget-geometry', buildLegacyGeometryPayload(currentGeometryState));
  resolveGeometryWaiters(currentGeometryState);
}
```

### 2. DevTools Detection False Positives

**Problem**: The DevTools detection heuristic is unreliable:
- `outerHeight` vs `innerHeight` difference can occur for reasons other than DevTools:
  - Browser UI changes
  - Zoom level changes
  - Mobile browser chrome
  - Custom browser extensions

**Impact**: Timeouts may be unnecessarily extended, causing delays in trigger responses.

### 3. Viewport Polling Overhead

**Problem**: The 500ms polling interval runs continuously:
- Adds CPU overhead
- May cause performance issues on slower devices
- Could interfere with rapid trigger sequences

## What Likely Happened with "Sociable Society Demo"

### Scenario Analysis

Since "sociable society" doesn't appear in the codebase, this likely refers to:
1. A demo account name (not found in current demo data)
2. A survey name that was renamed or removed
3. A test scenario identifier

### Most Likely Issue

When triggering a demo with DevTools open:

1. **Trigger Sent** → `handleTrigger()` called → `surveyBridge.sendTrigger()` executed
2. **DevTools Detected** → Height difference detected → Timeout extended to 5000ms+
3. **Geometry Refresh** → Viewport polling detects change → Multiple geometry updates fire
4. **Race Condition** → Widget visibility check happens during viewport transition
5. **Timeout Expires** → `waitForVisibleGeometry()` resolves with `visible: false` state
6. **Trigger Appears to Fail** → Survey doesn't present, or presents with incorrect geometry

### Debugging Steps

To diagnose what happened:

1. **Check Console Logs**: Look for:
   - `[player] geometry state updated` messages
   - `[player] viewport size changed` messages
   - `[player] widget not visible despite area` warnings
   - `[bridge] status` messages showing trigger events

2. **Check Network Tab**: Verify:
   - Survey data loaded correctly
   - Tag script loaded (`surveys-tag.js`)
   - No CSP violations

3. **Check Geometry State**: In console, check:
   ```javascript
   // Check if widget is visible
   document.getElementById('_pi_surveyWidgetContainer')
   
   // Check viewport dimensions
   { inner: { width: window.innerWidth, height: window.innerHeight },
     outer: { width: window.outerWidth, height: window.outerHeight } }
   ```

## Recommendations

### 1. Improve DevTools Detection

Replace unreliable height-based detection with more reliable methods:

```javascript
// Better DevTools detection
function detectDevTools() {
  // Method 1: Console API override detection
  let devtools = false;
  const element = new Image();
  Object.defineProperty(element, 'id', {
    get: function() {
      devtools = true;
    }
  });
  console.log(element);
  
  // Method 2: Timing-based detection
  const start = performance.now();
  console.log('%c', '');
  const elapsed = performance.now() - start;
  
  return devtools || elapsed > 1;
}
```

### 2. Debounce Geometry Updates

Add debouncing to prevent rapid-fire geometry updates:

```javascript
let geometryUpdateTimer = null;
function debouncedRefreshGeometryState() {
  if (geometryUpdateTimer) {
    clearTimeout(geometryUpdateTimer);
  }
  geometryUpdateTimer = setTimeout(() => {
    refreshGeometryState();
  }, 100);
}
```

### 3. Add Trigger-Specific Logging

Enhance trigger logging to include DevTools state:

```javascript
function runTrigger(triggerId, args = []) {
  const devToolsOpen = detectDevTools();
  console.log('[player] trigger fired', {
    triggerId,
    devToolsOpen,
    viewport: { width: window.innerWidth, height: window.innerHeight },
    timestamp: Date.now()
  });
  // ... rest of trigger logic
}
```

### 4. Increase Timeout When DevTools Detected

The current timeout extension (5000ms) may still be insufficient. Consider:
- Increasing to 8000ms when DevTools detected
- Adding exponential backoff for retries
- Providing user feedback when delays occur

## Conclusion

The DevTools detection mechanism is designed to handle viewport changes when DevTools opens, but the implementation has limitations:

1. **Unreliable Detection**: Height-based detection can produce false positives
2. **Race Conditions**: Rapid viewport changes can cause geometry state inconsistencies
3. **Timeout Issues**: Extended timeouts may still be insufficient for slow renders
4. **Debugging Difficulty**: Limited visibility into trigger failures when DevTools is open

The "sociable society demo" trigger likely failed due to a combination of:
- DevTools causing viewport changes
- Geometry state not updating correctly
- Timeout expiring before widget became visible
- Race condition between trigger execution and geometry refresh

To prevent future issues, implement more robust DevTools detection and add better error handling/logging around trigger execution.



