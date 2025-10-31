# Pulse Demo v3 — Security Implementation Plan
**File:** 08-SECURITY-IMPLEMENTATION.md  
**Audience:** Cursor/Codex implementers (Pages deploy, Bridge, Player, Logging)  
**Objective:** Finish the “CSP/log review” work by adding concrete headers, iframe sandboxing, strict `postMessage` origins, and log/telemetry sanitization. Keep the Player embeddable by the preview while blocking everyone else.

---

## 0) Scope (what changes)
- Add a `_headers` file in the Pages output (`preview/v3/`) with:
  - a strict default CSP for the preview app,
  - a relaxed override for **`/player.html`** so the preview can embed it,
  - cache headers for static assets.
- Ensure the Player iframe is sandboxed (`allow-scripts allow-same-origin`) with `referrerpolicy="no-referrer"`.
- Enforce strict `postMessage` origin rules (exact `targetOrigin`, validate `event.origin`).
- Sanitize all log/telemetry events (no PII, short messages, scrubbed URLs).

This plan **does not** change Protocol v1 wire format. It strengthens deploy posture and logging.

---

## 1) File map (adds/edits)

```
preview/v3/
  _headers                 # NEW — Cloudflare Pages headers/CSP
  index.html               # EDIT — iframe attrs for Player
  player.html              # (existing) — no changes required for CSP; see note below
  ui/logging/sanitize.js   # NEW — log/telemetry sanitizers
  ui/telemetry.js          # EDIT — use sanitizers before sinks
  ui/events.js             # EDIT — (optional) small integration point
```

> If your Player lives at another path, adjust `/player.html` accordingly in the `_headers` sections below.

---

## 2) Cloudflare Pages headers (`preview/v3/_headers`)

### 2.1 Default (applies to all pages unless overridden)
```
/*
  Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; connect-src 'self'; frame-ancestors 'none';
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: geolocation=(), microphone=(), camera=(), payment=(), usb=()
  Cache-Control: no-store
```

- Blocks other sites from iframing the **preview** (`frame-ancestors 'none'`).  
- Allows inline styles for tokens/quick-knobs. Avoid `unsafe-inline` later by moving styles to CSS variables only.

### 2.2 Player override (must be embeddable by the preview)
```
/player.html
  Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; connect-src 'self'; frame-ancestors 'self';
  X-Frame-Options: SAMEORIGIN
```

- `frame-ancestors 'self'` allows the same-origin preview to embed the Player iframe.  
- Keep `X-Frame-Options: SAMEORIGIN` for legacy browsers; CSP is authoritative.

**If curated themes are cross-origin**, add the host explicitly (prefer same-origin deployment if possible):
```
/player.html
  Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline' https://themes.examplecdn.com; img-src 'self' data: blob:; font-src 'self' data:; connect-src 'self'; frame-ancestors 'self';
```

### 2.3 Static assets caching (optional, nice to have)
```
/assets/*
  Cache-Control: public, max-age=86400, immutable
```

---

## 3) Player iframe attributes (`preview/v3/index.html`)
Locate the Player iframe and add sandbox + referrer policy:

```html
<iframe
  id="pi-v3-player"
  src="/player.html"
  sandbox="allow-scripts allow-same-origin"
  referrerpolicy="no-referrer">
</iframe>
```

- Use same-origin for Player when possible. If you *must* host Player on a different domain, update `_headers` (frame-ancestors) and adjust the Bridge’s `playerOrigin` accordingly.

---

## 4) postMessage origin hygiene (Bridge & Player)

### 4.1 Derive exact `playerOrigin` (Bridge)
```ts
// utils/origin.ts (or inline in Bridge bootstrap)
export function derivePlayerOrigin(iframe) {
  const u = new URL(iframe.getAttribute('src') || '', window.location.href);
  return u.origin; // works for relative src, dev proxy, prod
}
```

Use it for `postMessage` and validation:
```ts
const iframe = document.getElementById('pi-v3-player');
const playerOrigin = derivePlayerOrigin(iframe);

iframe.contentWindow.postMessage(msg, playerOrigin); // never '*' in prod
```

### 4.2 Validate `event.origin` (Bridge and Player)
Bridge side (inside `onMessage`):
```ts
if (ev.origin !== playerOrigin || ev.source !== iframe.contentWindow) return; // reject
```

Player side (lock on first message):
```ts
let bridgeOrigin = '*';
window.addEventListener('message', (ev) => {
  const m = ev.data; if (!m || m.v !== 1) return;
  if (bridgeOrigin === '*') bridgeOrigin = ev.origin;     // lock once
  if (ev.origin !== bridgeOrigin) return;                 // reject others
  // ...handle message
});
// respond with: parent.postMessage(out, bridgeOrigin);
```

> In dev only, you may support `?playerOrigin=` override. Never use `"*"` in production builds.

---

## 5) Log & telemetry sanitization

### 5.1 New module: `ui/logging/sanitize.js`
```js
// ui/logging/sanitize.js
const REDACT_PARAMS = ['token','key','secret','auth','session','password','api_key'];

export function scrubUrl(maybeUrl) {
  try {
    const u = new URL(maybeUrl, window.location.origin);
    for (const p of REDACT_PARAMS) if (u.searchParams.has(p)) u.searchParams.set(p, 'REDACTED');
    return u.pathname + (u.search ? '?' + u.searchParams.toString() : '');
  } catch { return String(maybeUrl ?? ''); }
}

export function publicError(err = {}) {
  const code = err.code || 'unknown';
  const message = (err.message || 'Error').toString();
  return {
    code,
    message: message.length > 160 ? message.slice(0, 157) + '…' : message,
    recoverable: !!err.recoverable,
    hint: err.hint
  };
}

/** Whitelist-only payload for telemetry */
export function telemetrySafe(evt = {}) {
  const out = { type: evt.type, ts: evt.ts || Date.now() };
  if (evt.previewUrl) out.previewUrl = scrubUrl(evt.previewUrl);
  if (evt.type === 'present') out.surveyId = String(evt.surveyId || '').slice(0, 64);
  if (evt.type === 'error') Object.assign(out, publicError(evt));
  if (evt.event) out.event = String(evt.event).slice(0, 80);
  return out;
}
```

### 5.2 Use sanitizers in `ui/telemetry.js` (diff)
```diff
- export const sinks = [
-   (evt) => console.log('[PulseDemo]', evt.type, { ...evt, ts: undefined })
- ];
+ import { telemetrySafe } from '../ui/logging/sanitize.js';
+
+ export const sinks = [
+   (evt) => {
+     // eslint-disable-next-line no-console
+     console.log('[PulseDemo]', evt.type, telemetrySafe(evt));
+   }
+ ];
```

### 5.3 (Optional) Touch `ui/events.js` to apply publicError for UI toasts (diff)
```diff
- case 'error':
-   toast.error(evt.message); break;
+ case 'error':
+   import('../ui/logging/sanitize.js').then(({ publicError }) => {
+     const pe = publicError(evt);
+     toast.error(pe.message);
+   });
+   break;
```

You can also pre-sanitize before calling `emit({ type:'error', ... })`; choose one place to avoid double work.

---

## 6) Manual validation (5 minutes)
1) **Headers**: Open DevTools → Network → click `index.html` and `player.html` → confirm **Content-Security-Policy** matches the blocks above.
2) **Framing**: Try to embed the preview page inside another origin → it should be blocked; the preview should embed **`/player.html`** successfully.
3) **CSP violations**: DevTools Console must be free of CSP errors. If you see “Refused to apply style from …”, either host that CSS locally or add its host to `style-src` in the player override.
4) **Logging**: Trigger an error (break a theme URL) → UI toast should show a short message, console should log sanitized payload (no tokens in URLs).

---

## 7) Automated checks (optional but recommended)

**Playwright: assert headers exist**
```ts
test('index.html and player.html have CSP', async ({ request }) => {
  const i = await request.get('http://localhost:5173/index.html');
  const p = await request.get('http://localhost:5173/player.html');
  expect(i.headers()['content-security-policy']).toBeTruthy();
  expect(p.headers()['content-security-policy']).toContain("frame-ancestors");
});
```

**Unit: scrubUrl/publicError**
```ts
import { scrubUrl, publicError, telemetrySafe } from '../../ui/logging/sanitize.js';
test('scrubUrl redacts tokens', () => {
  expect(scrubUrl('/x?a=1&token=abc')).toBe('/x?a=1&token=REDACTED');
});
test('publicError clamps message', () => {
  const e = publicError({ code:'x', message:'m'.repeat(500) });
  expect(e.message.length).toBeLessThanOrEqual(160);
});
test('telemetrySafe whitelist', () => {
  const out = telemetrySafe({ type:'present', ts: 1, previewUrl:'/x?key=123', surveyId:'S'.repeat(500) });
  expect(out.previewUrl.includes('REDACTED')).toBe(true);
  expect(out.surveyId.length).toBeLessThanOrEqual(64);
});
```

---

## 8) Acceptance criteria
- `_headers` served with: **global CSP** blocking foreign frames, **player override** allowing same-origin framing, sane cache headers for assets.
- Player iframe has sandbox + referrer policy.
- Bridge and Player both use exact `targetOrigin` and reject unexpected `event.origin`.
- Logs/toasts and telemetry contain **no PII or secrets**, with short, friendly messages.
- No CSP violations in the console during normal flows.
- (Optional) Playwright CI asserts headers are present and non-empty.

---

## 9) Rollback
- Revert `_headers` if CSP blocks something critical; use the Player override section to relax only the necessary directives.
- Remove sanitization import temporarily if it causes bundling issues, but **do not** ship raw payloads to telemetry—fall back to console only.

---

## 10) Notes
- Keep the Player same-origin with the preview whenever possible. Cross-origin Players require explicit host allowances in `frame-ancestors` and stricter origin negotiation.
- Don’t add `unsafe-eval` to `script-src`. If a build tool requires it in dev, ensure production build strips it.

