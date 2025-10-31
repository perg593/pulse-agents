# Pulse Insights — Demo Studio
## Step 3: Triggers, Events, Toasts & Telemetry (v3)

**Scope (what changes in Step‑3):**
- Add a **single event pipeline** (`emit`) that fans out to the log panel, on‑screen toasts, and a pluggable telemetry sink.
- Standardize **trigger definitions** in one config and wire them to `window.pi('command', ...)` via the Step‑2 adapter.
- Show **user feedback** (toasts) for key actions and warnings (presented, tag ready, theme applied, errors).
- Do **not** change IA/labels from Step‑1; do **not** add dark mode (that’s Step‑4).

---

## A) New/Updated files

```
preview/v3/
  ui/
    events.js       # NEW: central emit() and event types
    toast.js        # NEW: toasts (render + queue + dismiss)
    telemetry.js    # NEW: sinks (console by default)
    log.js          # (from Step‑2) keep; emit() will call log()
  adapter/
    pulse-adapter.js  # UPDATED: call emit() at key points
  services/
    themes.js         # UPDATED: emit() on apply/remove/generate
  triggers/
    config.js       # NEW: TRIGGER_CONFIG and helpers
```

> Keep your Step‑2 selector mapping shim. No DOM ID renames are required in Step‑3.

---

## B) Event model (authoritative)

```ts
// ui/events.js (types for reference; use JSDoc or TS as you prefer)

export type TriggerId =
  | 'present_now'
  | 'exit_intent'
  | 'scroll_60'
  | 'idle_10s'
  | 'rage_click';

export type DemoEvent =
  | { type: 'init'; ts: number; data?: any }
  | { type: 'tag_ready'; ts: number; ready: boolean }
  | { type: 'present'; ts: number; surveyId: string; force?: boolean }
  | { type: 'trigger'; ts: number; triggerId: TriggerId }
  | { type: 'theme_applied'; ts: number; themeId: string; origin: 'example'|'generated'|'manual' }
  | { type: 'theme_revoked'; ts: number; count: number }
  | { type: 'error'; ts: number; code: string; message: string; data?: any };
```

### `emit()` contract

```js
// ui/events.js
import { log } from './log.js';
import { toast } from './toast.js';
import { sinks } from './telemetry.js';

/** Fan out events to log, toasts, and telemetry sinks. */
export function emit(evt) {
  // 1) log panel (structured -> human line)
  switch (evt.type) {
    case 'init':
      log('ui','event','Init', evt.data); break;
    case 'tag_ready':
      log('tag','event', evt.ready ? 'Tag ready' : 'Tag not found'); break;
    case 'present':
      log('tag','event', `Presented ${evt.surveyId}`, { force: !!evt.force }); break;
    case 'trigger':
      log('trigger','event', `Trigger ${evt.triggerId}`); break;
    case 'theme_applied':
      log('theme','event', `Applied theme ${evt.themeId}`, { origin: evt.origin }); break;
    case 'theme_revoked':
      log('theme','event', `Revoked ${evt.count} generated assets`); break;
    case 'error':
      log('ui','error', `${evt.code}: ${evt.message}`, evt.data); break;
  }

  // 2) on-screen toasts (user feedback)
  switch (evt.type) {
    case 'tag_ready':
      toast.info(evt.ready ? 'Tag ready.' : 'Tag not found — using demo mode.'); break;
    case 'present':
      toast.success('Agent presented.'); break;
    case 'theme_applied':
      toast.success('Theme applied.'); break;
    case 'theme_revoked':
      toast.info('Cleaned up generated assets.'); break;
    case 'error':
      toast.error(evt.message); break;
  }

  // 3) telemetry sinks (safe, no PII)
  for (const sink of sinks) {
    try { sink(evt); } catch {}
  }
}
```

---

## C) Toasts (UI feedback)

**Goal:** Small, accessible messages that don’t clutter the demo.

### Markup host
Add a container to `index.html` **inside** the `.pi-v3` root:

```html
<div id="pi-v3-toasts" aria-live="polite" aria-atomic="true"></div>
```

### Implementation

```js
// ui/toast.js
const HOST_ID = 'pi-v3-toasts';

function host() {
  let el = document.getElementById(HOST_ID);
  if (!el) {
    el = document.createElement('div');
    el.id = HOST_ID;
    el.setAttribute('aria-live','polite');
    el.setAttribute('aria-atomic','true');
    document.body.appendChild(el);
  }
  return el;
}

function push(kind, text, ms) {
  const wrap = document.createElement('div');
  wrap.className = `pi-toast pi-toast--${kind}`;
  wrap.role = kind === 'error' ? 'alert' : 'status';
  wrap.innerHTML = `<div class="pi-toast__body">${text}</div><button class="pi-toast__x" aria-label="Dismiss">×</button>`;

  const h = host();
  h.appendChild(wrap);

  const close = () => { wrap.classList.add('is-out'); setTimeout(() => wrap.remove(), 180); };
  wrap.querySelector('button').addEventListener('click', close);

  const t = setTimeout(close, ms ?? (kind === 'error' ? 6000 : 3000));
  wrap.addEventListener('pointerenter', () => clearTimeout(t));

  // Cap stack at 3
  const nodes = h.querySelectorAll('.pi-toast');
  if (nodes.length > 3) nodes[0].remove();
}

export const toast = {
  success: (t, ms) => push('success', t, ms),
  info:    (t, ms) => push('info', t, ms),
  warn:    (t, ms) => push('warn', t, ms),
  error:   (t, ms) => push('error', t, ms)
};
```

### Styles (minimal; uses Step‑4 tokens later)

```css
/* v3.css (append) */
.pi-v3 #pi-v3-toasts {
  position: fixed; inset: 12px 12px auto auto;
  display: grid; gap: 8px; z-index: 9999;
}
.pi-toast {
  background: var(--pi-color-surface, #161a22);
  color: var(--pi-color-text, #e7eaf0);
  border: 1px solid var(--pi-color-border, #2a2f3a);
  border-radius: var(--pi-radius, 8px);
  padding: 10px 12px; box-shadow: var(--pi-shadow-2, 0 4px 12px rgba(0,0,0,.25));
  transform: translateY(0); opacity: 1; transition: opacity .18s ease, transform .18s ease;
}
.pi-toast.is-out { opacity: 0; transform: translateY(-4px); }
.pi-toast__x { background: transparent; border: 0; color: inherit; font-size: 16px; margin-left: 8px; cursor: pointer; float: right; }
.pi-toast--success { border-color: color-mix(in srgb, var(--pi-success,#22c55e), transparent 70%); }
.pi-toast--warn    { border-color: color-mix(in srgb, var(--pi-warning,#f59e0b), transparent 70%); }
.pi-toast--error   { border-color: color-mix(in srgb, var(--pi-danger,#ef4444), transparent 70%); }
```

---

## D) Triggers (single source of truth)

```js
// triggers/config.js
export const TRIGGER_CONFIG = [
  { id: 'present_now', label: 'Present now', kind: 'present', primary: true },
  { id: 'exit_intent', label: 'Simulate exit‑intent', kind: 'behavior', command: ['simulateExitIntent'] },
  { id: 'scroll_60',  label: 'Simulate 60% scroll', kind: 'behavior', command: ['simulateScrollDepth', 0.6] },
  { id: 'idle_10s',   label: 'Simulate 10s idle',   kind: 'behavior', command: ['simulateIdle', 10000] },
  { id: 'rage_click', label: 'Simulate rage click', kind: 'behavior', command: ['simulateRageClick'] }
];
```

**Binding (example)**

```js
// v3.js (or a small triggers/wire.js)
import { TRIGGER_CONFIG } from './triggers/config.js';
import { presentSurvey, sendTrigger } from './adapter/pulse-adapter.js';
import { store } from './v3.js';
import { emit } from './ui/events.js';
import { UI, N } from './ui/selectors.js';

function wireTriggers() {
  // Present now
  UI(N.triggerPresent)?.addEventListener('click', () => {
    if (!store.selectedAgent?.id) return;
    presentSurvey(store.selectedAgent.id, { force: true });
    emit({ type:'present', ts: Date.now(), surveyId: store.selectedAgent.id, force: true });
  });

  // Others
  const map = {
    exit_intent: N.triggerExit,
    scroll_60:   N.triggerScroll,
    idle_10s:    N.triggerTimer,
    rage_click:  N.triggerRage
  };
  for (const spec of TRIGGER_CONFIG) {
    if (spec.id === 'present_now') continue;
    const el = UI(map[spec.id]);
    el?.addEventListener('click', () => {
      if (spec.command) sendTrigger(...spec.command);
      emit({ type:'trigger', ts: Date.now(), triggerId: spec.id });
    });
  }
}

document.addEventListener('DOMContentLoaded', wireTriggers);
```

---

## E) Telemetry

```js
// ui/telemetry.js
export const sinks = [
  /** Console sink (demo-safe; strips ts when logging) */
  (evt) => {
    // eslint-disable-next-line no-console
    console.log('[PulseDemo]', evt.type, { ...evt, ts: undefined });
  }
];

// In the future you can push a network sink here:
// sinks.push((evt) => fetch('/telemetry', { method:'POST', body: JSON.stringify(evt) }));
```

---

## F) Adapter & services: add emits

### adapter/pulse-adapter.js (diff)
```diff
 import { store, setState } from '../v3.js';
-import { log } from '../ui/log.js';
+import { emit } from '../ui/events.js';

 export async function bootTag() {
   try {
     if (typeof window.bootPulseTag === 'function') await window.bootPulseTag();
     const ready = typeof window.pi === 'function';
     setState({ tagReady: ready });
-    log('tag', 'event', ready ? 'Tag ready' : 'Tag not found');
+    emit({ type:'tag_ready', ts: Date.now(), ready });
     return ready;
   } catch (e) {
     setState({ tagReady: false });
-    log('tag', 'error', 'Failed to boot tag', { error: String(e) });
+    emit({ type:'error', ts: Date.now(), code:'boot_fail', message:'Failed to boot tag', data:{ error:String(e) } });
     return false;
   }
 }

 export function presentSurvey(id, opts = { force:false }) {
   if (!store.tagReady) { setState({ pendingSurveyId: id }); 
-    log('tag', 'info', 'Queued survey until tagReady', { id }); return; }
+    emit({ type:'error', ts: Date.now(), code:'not_ready', message:'Tag not ready — queued', data:{ id } }); return; }
   if (!opts.force && store.lastPresentedId === id) { /* silent */ return; }
   try {
     window.pi && window.pi('present', id);
     setState({ lastPresentedId: id, agentStatus: 'Presenting' });
-    log('tag', 'event', 'Presented survey', { id, force: !!opts.force });
+    emit({ type:'present', ts: Date.now(), surveyId:id, force: !!opts.force });
   } catch (e) {
-    log('tag', 'error', 'Present failed', { id, error: String(e) });
+    emit({ type:'error', ts: Date.now(), code:'present_fail', message:'Present failed', data:{ id, error:String(e) } });
   }
 }
```

### services/themes.js (diff)
```diff
-import { log } from '../ui/log.js';
+import { emit } from '../ui/events.js';

 export function applyThemeByHref(id, label, href) {
   // ... append link
-  log('theme', 'event', 'Applied curated theme', { id, label });
+  emit({ type:'theme_applied', ts: Date.now(), themeId:id, origin:'example' });
 }

 export function removeTheme(id) {
   // ... remove link & registry
-  log('theme', 'event', 'Removed theme', { id });
+  // no toast needed; silent removal
 }

 export async function generateFromUrl(url) {
   try {
     // ... revoke previous blobs
-    log('theme','event','Generated themes',{ count: descriptors.length });
+    // no toast here; will toast on apply
     return descriptors;
   } catch(e) {
-    log('theme','error','Generation failed',{ error: String(e) });
+    emit({ type:'error', ts: Date.now(), code:'gen_fail', message:'Theme generation failed', data:{ error:String(e) } });
     return [];
   }
 }

 export function applyGeneratedTheme(theme) {
   // ... append link
-  log('theme','event','Applied generated theme',{ id });
+  emit({ type:'theme_applied', ts: Date.now(), themeId: theme.id, origin:'generated' });
 }
```

---

## G) Error handling matrix (updated)

| Scenario                          | Event(s)                         | Toast        | Log level |
|----------------------------------|----------------------------------|--------------|-----------|
| CSV feed offline (fallback)      | `error{code:'sheet_off'}`        | Error        | error     |
| Preview URL blocked (CORS)       | `error{code:'cors'}`             | Error        | error     |
| Tag not found at boot            | `tag_ready{ready:false}`         | Info (demo)  | event     |
| Present before tag ready         | `error{code:'not_ready'}`        | Error        | error     |
| Theme generation failed          | `error{code:'gen_fail'}`         | Error        | error     |

> You can reuse the same `emit({type:'error', ...})` call sites from Step‑2 wherever you currently `log('...','error',...)`.

---

## H) DOM IDs and selectors (added in Step‑3)

- **Toast host:** `#pi-v3-toasts` (auto‑injected if missing).
- No other new mandatory IDs. Keep using the Step‑2 canonical names via the selector mapping shim.

---

## I) Manual test checklist (5 minutes)

1. **Boot:** load v3 and confirm a toast “Tag ready.” (or “Tag not found — using demo mode.”). Log panel reflects the same.
2. **Present:** select an agent and click **Present now** → toast “Agent presented.” Agent badge flips to *Presenting*.
3. **Triggers:** click each simulated trigger → see `trigger` lines in the log; no errors.
4. **Themes:** apply a curated theme → toast “Theme applied.” Generate from URL → first suggestion auto‑applies and toasts. Regenerate → no memory leak warnings; log shows “Revoked N” via `theme_revoked` if you call it when cleaning up.
5. **Errors:** Temporarily break the generator to force an error → you get a red error toast; log line with `code='gen_fail'`.
6. **Telemetry:** Open console → see `[PulseDemo] present {...}` lines without timestamps.

---

## J) Acceptance criteria (Step‑3)

1. All user‑visible feedback comes from **toasts** driven by `emit()`.
2. **TRIGGER_CONFIG** drives non‑present triggers; **Present now** still uses the adapter + emits a `present` event.
3. `emit()` always fans out to **log + toast + telemetry** (console sink only by default).
4. Errors produce both a red toast and a log entry (with `level='error'`).
5. No changes to IA/labels or dark mode tokens.
