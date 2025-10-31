# Pulse Demo v3 — Consolidated Implementation Plan
**File:** 09-IMPLEMENTATION-PLAN.md  
**Audience:** Cursor/Codex implementers  
**Objective:** Implement the remaining work to harden, polish, and ship the v3 Preview with **Protocol v1** as default. This plan is incremental, testable, and directly references the current code and tests.

---

## 0) Scope
This document covers the concrete changes implied by the architecture review:

- Make **Protocol v1** the default path in public builds (legacy stays dev-only).
- Add CSP & headers (_headers) + Player iframe sandbox; sanitize logs/telemetry.
- Resolve Node ESM warnings (scoped `"type":"module"` or `.mjs` rename).
- Clean up legacy listener teardown.
- Add **dismiss** command support and test.
- Add a few high-value tests (wrong-origin rejection, `present_fail`, `close` lifecycle).
- Deploy via Cloudflare Pages with a crisp readiness checklist.

Where relevant, we cite the current wrapper and tests to anchor changes:
- Wrapper (factory + protocol/legacy branches): fileciteturn0file0  
- Integration test suite (assertions for ready, present/theme/trigger, cancellation): fileciteturn0file1

---

## 1) Make Protocol v1 the default (public builds)

### 1.1 Current behavior
`createSurveyBridge(...)` chooses between **legacy** and **v1** based on `runtimeOptions.useProtocolV1` or `?useProtocolV1=`; default is **false**. fileciteturn0file0

### 1.2 Change
- In **production/Pages builds**, default **on** unless explicitly overridden.

**Patch (wrapper, near flags construction):**
```diff
  const flags = {
-   useProtocolV1:
-     runtimeOptions.useProtocolV1 ??
-     globalFlags.useProtocolV1 ??
-     false,
+   useProtocolV1:
+     runtimeOptions.useProtocolV1 ??
+     globalFlags.useProtocolV1 ??
+     // default ON when running on Cloudflare Pages or production host
+     (/\.pages\.dev$/.test(location.hostname) || /pulseinsights\.com$/.test(location.hostname)),
    playerOrigin: runtimeOptions.playerOrigin ?? globalFlags.playerOrigin,
    compatImplicitAck: runtimeOptions.compatImplicitAck ?? true,
    debug: runtimeOptions.debug ?? false
  };
```

**Acceptance:**
- On local `localhost` the default remains *off* (unless query param or runtime override).  
- On Pages/production domains, the default is *on* and the **v1** path is used.

> Note: The v1 path already derives `playerOrigin`, sets iframe `sandbox`, wires **ready/status/error/statechange/close**, and queues actions until ready. fileciteturn0file0

---

## 2) Security: CSP headers + Player sandbox + log sanitization

### 2.1 Add `_headers` (Pages)
Create `preview/v3/_headers` with:
```
/*
  Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; connect-src 'self'; frame-ancestors 'none';
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: geolocation=(), microphone=(), camera=(), payment=(), usb=()
  Cache-Control: no-store

/player.html
  Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; connect-src 'self'; frame-ancestors 'self';
  X-Frame-Options: SAMEORIGIN
```
- Default blocks framing the Preview; `/player.html` is same-origin embeddable.

### 2.2 Ensure sandboxed Player iframe
The v1 wrapper already sets this on `iframe` creation:  
`sandbox="allow-scripts allow-same-origin"`. Verify it remains. fileciteturn0file0

### 2.3 Sanitize logs/telemetry (minimal module)
Create `preview/v3/ui/logging/sanitize.js`:
```js
const REDACT_PARAMS = ['token','key','secret','auth','session','password','api_key'];

export function scrubUrl(maybeUrl) {
  try {
    const u = new URL(maybeUrl, location.origin);
    REDACT_PARAMS.forEach(p => u.searchParams.has(p) && u.searchParams.set(p, 'REDACTED'));
    return u.pathname + (u.search ? '?' + u.searchParams.toString() : '');
  } catch { return String(maybeUrl ?? ''); }
}

export function publicError(err = {}) {
  const code = err.code || 'unknown';
  const msg = (err.message || 'Error').toString();
  return { code, message: msg.length > 160 ? msg.slice(0,157) + '…' : msg, recoverable: !!err.recoverable, hint: err.hint };
}

export function telemetrySafe(evt = {}) {
  const out = { type: evt.type, ts: evt.ts || Date.now() };
  if (evt.previewUrl) out.previewUrl = scrubUrl(evt.previewUrl);
  if (evt.type === 'present') out.surveyId = String(evt.surveyId || '').slice(0, 64);
  if (evt.type === 'error') Object.assign(out, publicError(evt));
  if (evt.event) out.event = String(evt.event).slice(0, 80);
  return out;
}
```

Wire into your sinks (example `ui/telemetry.js`):
```diff
- export const sinks = [(evt) => console.log('[PulseDemo]', evt.type, evt)];
+ import { telemetrySafe } from './logging/sanitize.js';
+ export const sinks = [(evt) => console.log('[PulseDemo]', evt.type, telemetrySafe(evt))];
```

**Acceptance:**
- Preview cannot be iframed by other sites; `/player.html` can be framed by Preview.
- Console shows no CSP violations during normal flows.
- Logs never print secrets or long traces; error toasts use trimmed messages.

---

## 3) Remove Node ESM warnings

You currently import the ESM wrapper from tests, so Node warns about module type. fileciteturn0file1

### Option A (preferred): scoped package.json
Create `preview/app/survey/package.json`:
```json
{ "type": "module" }
```

### Option B: rename to `.mjs`
- `preview/app/survey/bridge.js` → `bridge.mjs`  
- `preview/app/survey/bridgeV1.js` → `bridgeV1.mjs`  
- Update wrapper import:  
  `import { Bridge as BridgeV1, derivePlayerOrigin } from './bridgeV1.mjs';` fileciteturn0file0  
- Update `importBridgeModule()` in tests to point to `bridge.mjs`. fileciteturn0file1

**Acceptance:** Running the two Node scripts shows **no** `[MODULE_TYPELESS_PACKAGE_JSON]` warnings.

---

## 4) Legacy listener cleanup

The legacy path registers a `window.message` listener and never removes it; add removal in legacy `teardown()`. fileciteturn0file0

**Patch sketch:**
```diff
- function attachListeners() {
-   window.addEventListener('message', onMessage);
- }
+ let onMessageRef = null;
+ function attachListeners() {
+   onMessageRef = (event) => { /* existing legacy onMessage body */ };
+   window.addEventListener('message', onMessageRef);
+ }
  function teardown() {
    // existing cleanup...
+   if (onMessageRef) window.removeEventListener('message', onMessageRef), onMessageRef = null;
  }
```

**Acceptance:** Reloading the preview multiple times does not increase `message` listeners (check with DevTools Performance/Memory if desired).

---

## 5) Implement `dismiss` + test

### 5.1 Wrapper additions
Expose `dismiss()` through the protocol branch (it already exists on v1 Bridge):
```diff
return {
  // ... existing
+ dismiss() {
+   return runOrQueue(() => bridgeInstance.dismiss().catch((error) => {
+     onStatus({ type:'player-status', status:'present-error', message: error?.message || String(error), code: error?.code, payload: error });
+     throw error;
+   }));
+ },
  // ...
};
```

### 5.2 Player handler (ensure it acks)
Inside your Player, add a handler that hides the widget and acks `{ ok:true, event:'dismiss-called' }`.

### 5.3 Test (integration suite)
Extend `surveyBridge.integration.test.mjs`: queue a `dismiss()`, assert the `dismiss` envelope was sent and that a `status` with `event:'dismiss-called'` is forwarded by the wrapper. Reuse the same `withWatch()` helper. fileciteturn0file1

**Acceptance:** `dismiss()` resolves; wrapper emits `player-status` event with `status:'present-called'` → `status:'dismiss-called'` sequence when you present then dismiss.

---

## 6) Add high-value tests

### 6.1 Wrong-origin rejection (contract layer)
Post a valid‑looking v1 message from the **wrong origin**. Expect: Bridge ignores it (no state change, no status emitted). Build on your `bridge.contract.test.mjs` harness. (You already simulate multiple hellos/ready; add this extra post.) fileciteturn0file1

### 6.2 Error path: `present_fail`
Have the Player respond with `{ type:'error', id, payload:{ code:'present_fail', message:'...' } }` to the present id. Expect: wrapper surfaces `present-error` with `code:'present_fail'` and does **not** leave the Bridge in `PRESENTING`. fileciteturn0file1

### 6.3 Lifecycle `close`
Call `bridgeInstance.destroy()` through the wrapper and assert a one-time `close` event reaches the UI callback; ensure pending action queue is flushed with rejections.

**Acceptance:** New specs pass locally and in CI; suite remains fast (contract & integration split).

---

## 7) Deploy steps (Cloudflare Pages)

1) **Commit**: protocol default, CSP headers, sanitizers, legacy cleanup, tests.
2) **Push** to your repo (Pages connected). Build output dir is **`preview/v3`**.
3) **Verify Preview**:
   - `/` loads v3 UI; `/player.html` frames successfully.  
   - Console: no CSP errors; no module warnings.
   - `?useProtocolV1=1` or default shows v1 behavior; legacy path disabled by default.
4) **Promote** to production when green.

---

## 8) Readiness checklist (copy into PR template)

**Protocol & wrapper**
- [ ] v1 default in Pages; legacy gated to dev. fileciteturn0file0  
- [ ] present/applyTheme/trigger/dismiss acks forwarded as `status.event`. fileciteturn0file1  
- [ ] statechange wired to UI; close emitted on destroy. fileciteturn0file0

**Security**
- [ ] `_headers` present; preview blocked from being iframed; `/player.html` same‑origin embeddable.  
- [ ] Player iframe sandboxed; Bridge uses exact `playerOrigin`. fileciteturn0file0  
- [ ] Logs sanitized; no secrets/long traces in toasts or telemetry.

**Tests**
- [ ] Contract + integration pass; no Node module warnings. fileciteturn0file1  
- [ ] Added specs for `dismiss`, wrong-origin, present_fail, close lifecycle.

**Deploy**
- [ ] Pages preview builds from `preview/v3`; promote when verified.

---

## 9) Rollback
- Toggle default back to legacy by setting `useProtocolV1=false` in the wrapper defaults, or pass `?useProtocolV1=0` while investigating.  
- Remove `_headers` temporarily if CSP blocks a needed asset; re‑add with the specific origin whitelisted.

---

## 10) Notes & rationale
- Making v1 default in public builds prevents accidental use of the permissive legacy branch (which uses `"*"` targetOrigin and lacks origin validation). fileciteturn0file0  
- Tests already exercise all happy paths plus cancellation; these added tests catch classes of regressions that used to “hang” suites. fileciteturn0file1
