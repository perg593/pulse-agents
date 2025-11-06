# Pulse Demo v3 — Next Steps (Bugfixes & Tests)
**File:** 10-NEXT-STEPS.md  
**Audience:** Cursor/Codex implementers  
**Context:** Based on Codex’s audit, we’ll fix three issues and add small tests so nothing hangs again.

---

## Index
1. [Fix A — Reject queued promises when handshake fails](#fix-a)  
2. [Fix B — Normalize remote `.html` URLs](#fix-b)  
3. [Fix C — Inline selector fallback for complex selectors](#fix-c)  
4. [Optional — `waitUntilReady()` + test-friendly timeouts](#optional)  
5. [PR sequence](#pr-sequence)  
6. [Acceptance checks](#acceptance)

Where this plugs in:
- **Wrapper** `createSurveyBridge(...)` v1 branch, pending‑queue, handshake `catch` (protocol path). fileciteturn0file0  
- **Integration tests** scaffold and style (how we assert ready/present/theme/trigger). fileciteturn0file1

---

## <a id="fix-a"></a>Fix A — Reject queued promises when handshake fails (High)

**Problem**  
If the Player never replies to `init`, `bridgeInstance.init().catch(...)` logs and emits status but **does not reject** the queued actions created by `runOrQueue()`. Callers hang. (Wrapper protocol branch) fileciteturn0file0

**Approach**  
Store `{ run, reject }` in the queue, add `failPending(err)`, call it on handshake failure and on `teardown()`.

**Patch (minimal diff)**

```diff
diff --git a/preview/app/survey/bridge.js b/preview/app/survey/bridge.js
@@
 function createProtocolBridge({ container, onReady, onStatus, onStateChange, onError, onClose }, flags) {
   let currentConfig = null;
   let iframe = null;
   let bridgeInstance = null;
   let bridgeReady = false;
-  const pendingActions = [];
+  const pendingActions = []; // Array<{ run: () => void, reject: (e:any) => void }>
@@
   function teardown() {
     bridgeReady = false;
-    pendingActions.length = 0;
+    while (pendingActions.length) {
+      try { pendingActions.shift().reject({ code:'bridge_destroyed', message:'Bridge destroyed' }); } catch {}
+    }
     if (bridgeInstance) {
       bridgeInstance.destroy();
       bridgeInstance = null;
     }
     if (iframe && iframe.parentNode) {
@@
-  function runOrQueue(action) {
+  function runOrQueue(action) {
     if (bridgeReady && bridgeInstance) {
       return action();
     }
     return new Promise((resolve, reject) => {
-      pendingActions.push(() => {
-        try {
-          const result = action();
-          Promise.resolve(result).then(resolve, reject);
-        } catch (error) {
-          reject(error);
-        }
-      });
+      pendingActions.push({
+        run: () => {
+          try {
+            const result = action();
+            Promise.resolve(result).then(resolve, reject);
+          } catch (error) { reject(error); }
+        },
+        reject
+      });
     });
   }
@@
-  function flushPending() {
+  function flushPending() {
     if (!bridgeReady || !bridgeInstance) return;
-    while (pendingActions.length) {
-      const fn = pendingActions.shift();
-      try {
-        fn();
-      } catch (_error) {
-        // swallow queued errors; they are surfaced via promise rejections/logs
-      }
-    }
+    while (pendingActions.length) {
+      const { run } = pendingActions.shift();
+      try { run(); } catch {}
+    }
   }
+
+  function failPending(error) {
+    while (pendingActions.length) {
+      try { pendingActions.shift().reject(error); } catch {}
+    }
+  }
@@
       bridgeInstance.init().catch((error) => {
         try {
           onError({ code: error?.code || 'player_timeout', message: error?.message || String(error), error });
         } catch (_error) { /* ignore */ }
         onStatus({
           type: 'player-status',
           status: 'present-error',
           message: error?.message || String(error),
           code: error?.code || 'player_timeout'
         });
+        // Reject all queued actions so callers don't hang
+        failPending({ code: error?.code || 'player_timeout', message: error?.message || 'Player did not respond' });
       });
```

**New test (integration, fast)**

`preview/tests/handshakeFailure.integration.test.mjs`
```js
import { strict as assert } from 'node:assert';
import { withDom, withWatch } from './support/testUtils.mjs';
import { pathToFileURL, fileURLToPath } from 'node:url';
import path from 'node:path';

async function importBridgeModule() {
  const modulePath = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', 'app', 'survey', 'bridge.js');
  return import(pathToFileURL(modulePath));
}

test('queued present rejects when init fails', async () => {
  await withDom('http://localhost:8000/preview/basic/index.html?useProtocolV1=1', async () => {
    const container = document.getElementById('container');
    const { createSurveyBridge } = await importBridgeModule();
    const bridge = createSurveyBridge({ container }, { useProtocolV1: true });
    const iframe = bridge.load({ account:'PI', host:'h' });
    // Do NOT send hello/ready -> init() will reject on timeout
    const err = await withWatch(bridge.present('x').catch(e => e), 'queued reject', 2000);
    assert.equal(err?.code, 'player_timeout');
  });
});
```

**Acceptance**  
- If handshake fails, every queued Promise rejects with `{ code:'player_timeout' }`.  
- No test hangs; UI toasts log a single error.

---

## <a id="fix-b"></a>Fix B — Normalize remote `.html` URLs (Medium)

**Problem**  
`normalizeUrl()` treats `example.com/page.html` as a relative path (no scheme), producing a broken `iframe` URL. We should coerce to `https://…` (or proxy).

**Patch (robust normalization)**
```js
// preview/app/services/background.js
export function normalizeUrl(input, { base = window.location.origin, preferProxy = false, proxyOrigin } = {}) {
  if (!input || typeof input !== 'string') return '';
  const s = input.trim();

  // Absolute with scheme
  if (/^[a-z][a-z0-9+.-]*:\/\//i.test(s)) return s;

  // Protocol-relative
  if (/^\/\//.test(s)) return `https:${s}`;

  // Domain-first (example.com/x.html)
  if (/^[\w.-]+\.[a-z]{2,}(?:\/|$)/i.test(s)) {
    const abs = `https://${s}`;
    return preferProxy && proxyOrigin
      ? new URL(`/proxy?url=${encodeURIComponent(abs)}`, proxyOrigin).toString()
      : abs;
  }

  // Root-relative
  if (s.startsWith('/')) return new URL(s, base).toString();

  // Relative
  return new URL(`./${s}`, base).toString();
}
```

**Unit tests (add new file `preview/tests/services/normalizeUrl.test.mjs`)**
```js
import { strict as assert } from 'node:assert';
import { normalizeUrl } from '../../app/services/background.js';

assert.equal(normalizeUrl('example.com/page.html'), 'https://example.com/page.html');
assert.equal(normalizeUrl('//cdn.example.com/x.html'), 'https://cdn.example.com/x.html');
assert.equal(
  normalizeUrl('/local.html', { base: 'https://demo.local' }),
  'https://demo.local/local.html'
);
assert.equal(
  normalizeUrl('example.com/a.html', { preferProxy:true, proxyOrigin:'https://proxy.local' }),
  'https://proxy.local/proxy?url=https%3A%2F%2Fexample.com%2Fa.html'
);
```

**Acceptance**  
- Remote `.html` inputs render reliably; local paths still resolve relative to base.  
- Optional proxy path supported via flags.

---

## <a id="fix-c"></a>Fix C — Inline selector fallback for complex selectors (Medium)

**Problem**  
Inline mode only synthesizes a host when the selector starts with `#` or `.`. Attribute/complex selectors like `[data-slot="survey"]` fail to mount.

**Patch (safe fallback + selector update)**
```js
// preview/app/survey/player.js
function ensureInlineTarget(selector, root = document) {
  // Try the selector if valid
  let host = null;
  try { host = selector ? root.querySelector(selector) : null; } catch { host = null; }
  if (host) return host;

  // Fallback: synthesize stable container
  const fallbackId = 'pi-inline-target';
  host = root.getElementById(fallbackId);
  if (!host) {
    host = root.createElement('div');
    host.id = fallbackId;
    host.style.minHeight = '1px';
    (root.body || root.documentElement).appendChild(host);
  }

  // Update the effective selector so downstream uses the real element
  try { window.PULSE_TAG_INLINE_SELECTOR = `#${fallbackId}`; } catch {}
  return host;
}
```

**Integration test (extend existing suite)**
```js
// pseudo: preview/tests/player.inline.integration.test.mjs
test('inline: complex selector falls back to synthesized host', async () => {
  // configure inlineSelector: '[data-slot="survey"]' with no DOM match
  // load player, call present, expect ack
  // assert window.PULSE_TAG_INLINE_SELECTOR === '#pi-inline-target'
  // and that a div#pi-inline-target exists
});
```

**Acceptance**  
- Inline mode succeeds even when the provided selector doesn’t exist or is complex.  
- Selector is rewritten to the fallback id, making downstream code happy.

---

## <a id="optional"></a>Optional — `waitUntilReady()` & test‑friendly timeouts

**Why**  
Some tests want a Promise instead of event wiring, and faster timeouts in CI.

**Small additions** (wrapper protocol branch) fileciteturn0file0
```diff
 return {
+  waitUntilReady() {
+    if (bridgeReady) return Promise.resolve();
+    return new Promise((resolve, reject) => {
+      const onR = () => { off(); resolve(); };
+      const onE = (e) => { off(); reject(e); };
+      const off = () => {
+        try { bridgeInstance.off?.('ready', onR); } catch {}
+        try { bridgeInstance.off?.('error', onE); } catch {}
+      };
+      bridgeInstance?.on?.('ready', onR);
+      bridgeInstance?.on?.('error', onE);
+    });
+  },
 }
```
Expose Bridge constructor overrides (timeouts) via `runtimeOptions.bridgeOptions`:
```diff
- bridgeInstance = new BridgeV1({ iframe, playerOrigin, compatImplicitAck: flags.compatImplicitAck, debug: flags.debug });
+ bridgeInstance = new BridgeV1({ iframe, playerOrigin, compatImplicitAck: flags.compatImplicitAck, debug: flags.debug, ...(flags.bridgeOptions||{}) });
```

---

## <a id="pr-sequence"></a>PR sequence

- **PR‑A — Handshake failure handling**
  - Patch queue (`{run, reject}`), `failPending`, reject on `init().catch` + `teardown()`.
  - Add `handshakeFailure.integration.test.mjs`.  
  - Touch nothing else. fileciteturn0file0 fileciteturn0file1

- **PR‑B — URL normalization**
  - Implement `normalizeUrl()` changes + small unit tests.

- **PR‑C — Inline fallback**
  - Add `ensureInlineTarget()` fallback and an inline spec.

*(Optional)* **PR‑D — Ready Promise & timeouts**
  - Add `waitUntilReady()` + `bridgeOptions`.

Each PR should keep the suite green and avoid cross‑diff noise.

---

## <a id="acceptance"></a>Acceptance checks

- **No hangs:** Queued calls reject within the handshake timeout if init fails.  
- **Remote `.html`:** Inputs like `example.com/page.html` become `https://example.com/page.html` (or proxy).  
- **Inline:** Complex selectors fall back to a synthesized host; `present` still acks.  
- **Tests:** New specs pass locally and in CI alongside existing contract/integration suites. fileciteturn0file1

---

## Notes
- Keep Protocol v1 as default in public builds; legacy remains dev‑only (separate PR if not already done). fileciteturn0file0
- Avoid expanding scope—these are tight fixes with high payoff.
