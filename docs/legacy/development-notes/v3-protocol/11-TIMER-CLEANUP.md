# Pulse Demo v3 — Timer Cleanup (Clean Test Exit)
**File:** 11-TIMER-CLEANUP.md  
**Audience:** Cursor/Codex implementers  
**Goal:** Ensure integration tests exit cleanly by tearing down Bridge resources (heartbeat timers, iframes, listeners) and, as a belt‑and‑suspenders, forcing process exit on success.

---

## Scope (what changes)
1) **Expose `destroy()` on the wrapper** for both legacy and v1 branches, delegating to internal `teardown()` so tests (and UI) can stop all timers and remove the iframe.  
2) **Remove the legacy `message` listener** during teardown (store handler reference).  
3) **Call `bridge.destroy()` in the integration suite** and **`process.exit(0)`** after both suites pass so Node doesn’t linger on any stray handles.

Reference files: wrapper factory and protocol/legacy branches (bridge.js), and the integration suite (surveyBridge.integration.test.mjs).

---

## Patch A — Wrapper: expose `destroy()` and clean up legacy listener

**File:** `preview/app/survey/bridge.js`

### A.1 Add a removable listener in **legacy** branch + expose `destroy()`
```diff
@@
 function createLegacyBridge({ container, onReady, onStatus, onStateChange, onClose }) {
   let frame = null;
   let ready = false;
   let pendingMessages = [];
   let currentConfig = null;
   let legacyState = 'UNMOUNTED';
+  let onMessageRef = null; // NEW: keep a reference to remove later
@@
-  function teardown() {
+  function teardown() {
     const hadFrame = Boolean(frame);
+    // NEW: remove message listener to avoid leaks on reload
+    if (onMessageRef) {
+      try { window.removeEventListener('message', onMessageRef); } catch {}
+      onMessageRef = null;
+    }
     if (frame && frame.parentNode) {
       frame.parentNode.removeChild(frame);
     }
     frame = null;
     ready = false;
     pendingMessages = [];
@@
-  function attachListeners() {
-    window.addEventListener('message', (event) => {
+  function attachListeners() {
+    onMessageRef = (event) => {
       if (!frame || event.source !== frame.contentWindow) return;
       const { data } = event;
       if (!data || typeof data !== 'object') return;
@@
-      onStatus(data);
-    });
+      onStatus(data);
+    };
+    window.addEventListener('message', onMessageRef);
   }
@@
   return {
+    // NEW: make teardown callable by tests/UI
+    destroy() {
+      teardown();
+    },
     load(config = {}) {
       currentConfig = config;
       teardown();
       if (!container) return null;
       try {
         console.log('[bridge] load player', config);
       } catch (_error) {
         /* ignore */
       }
```

### A.2 Expose `destroy()` in **protocol v1** branch
```diff
@@
 function createProtocolBridge({ container, onReady, onStatus, onStateChange, onError, onClose }, flags) {
@@
-  function teardown() {
+  function teardown() {
     bridgeReady = false;
     pendingActions.length = 0;
     if (bridgeInstance) {
       bridgeInstance.destroy();
       bridgeInstance = null;
     }
     if (iframe && iframe.parentNode) {
       iframe.parentNode.removeChild(iframe);
     }
     iframe = null;
   }
@@
   return {
+    // NEW: make teardown callable by tests/UI (stops heartbeat timers, removes iframe)
+    destroy() {
+      teardown();
+    },
     load(config = {}) {
       currentConfig = config;
       teardown();
       if (!container) return null;
       iframe = document.createElement('iframe');
```

> These changes ensure both branches can be torn down explicitly and that the legacy listener doesn’t accumulate across reloads.  
> (File context: wrapper factory and branches in `preview/app/survey/bridge.js`.)

---

## Patch B — Tests: tear down bridges and force a clean exit

**File:** `tests/integration/preview/surveyBridge.integration.test.mjs`

### B.1 Call `destroy()` at the end of each suite
```diff
@@ async function runLegacySuite() {
     assert.deepEqual(postMessages[2].message, { type: 'trigger', triggerId: 'exit-intent' });
+
+    // 🔚 Ensure we tear down timers/iframe from the legacy path
+    bridge.destroy?.();
   });
 }
@@ async function runProtocolSuite() {
     assert.ok(keepPresentCalled, 'latest present resolves successfully after cancellation');
+
+    // 🔚 Tear down v1 bridge to stop heartbeat/ack timers
+    bridge.destroy?.();
   });
 }
```

### B.2 Exit explicitly when both suites pass
```diff
@@ async function run() {
   await runLegacySuite();
   await runProtocolSuite();
   console.log('surveyBridge integration test passed');
 }
 
-run().catch((error) => {
-  console.error(error);
-  process.exitCode = 1;
-});
+run()
+  .then(() => {
+    // Force a clean exit so lingering timers cannot keep the process alive in CI/Node
+    if (typeof process !== 'undefined' && process.exit) process.exit(0);
+  })
+  .catch((error) => {
+    console.error(error);
+    if (typeof process !== 'undefined' && process.exit) process.exit(1);
+  });
```

---

## Verification (fast checklist)

1) Run the suites directly:
```bash
node tests/integration/preview/bridge.contract.test.mjs && node tests/integration/preview/surveyBridge.integration.test.mjs
```
Expected:
- `bridge.contract tests passed`
- `surveyBridge integration test passed`
- Process exits immediately; no lingering timers (no “hung” Node process).

2) Optional: run with `--trace-events-enabled` or a process handle inspector to confirm no active timers remain after `destroy()`.

---

## Notes
- If you later migrate to Jest/Vitest/Playwright as the runner, the explicit `process.exit(0)` may be unnecessary (runners manage process lifecycles). Keep it for the current Node‑script flow.
- If your protocol Bridge adds new timers in the future, keeping `destroy()` wired ensures tests remain clean.
