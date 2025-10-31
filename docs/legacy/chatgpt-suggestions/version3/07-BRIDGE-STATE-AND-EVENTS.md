# Pulse Demo v3 — Bridge State & Events Addendum (Protocol v1)
**File:** 07-BRIDGE-STATE-AND-EVENTS.md  
**Audience:** Codex implementers (Bridge/UI/Tests)  
**Goal:** Add observable Bridge lifecycle + clean logging so the preview never “mystery hangs,” and tests can wait on explicit state instead of polling.

---

## 0) Scope (what changes)
- Extend the **Bridge** with:
  - a read‑only `state` (`'UNMOUNTED'|'BOOTING'|'IDLE'|'PRESENTING'|'DISMISSING'|'ERROR'`),
  - a **`statechange` event** emitted on every transition (with `reason`),
  - a one‑time **`close`** event on `destroy()`.
- Keep emitting existing **`status`** / **`error`** on command acks.
- Pipe `statechange`/`status` into the existing `emit()` logger/toasts so the UI shows “Presenting…/Player inactive/etc.”
- Provide a tiny **test helper** to wait for state transitions deterministically.

No IA copy changes. No protocol wire format changes.

---

## 1) Types (authoritative)
```ts
export type BridgeState =
  | 'UNMOUNTED' | 'BOOTING' | 'IDLE'
  | 'PRESENTING' | 'DISMISSING' | 'ERROR';

export type StateChange = {
  prev: BridgeState;
  next: BridgeState;
  reason?: string;          // 'init-start' | 'ready' | 'present-start' | 'present-complete' | 'present-cancelled' | 'present-failed' | 'dismiss-start' | 'dismiss-complete' | 'heartbeat-missed-2' | 'ack-timeout' | 'player-timeout' | 'destroy' | 'implicit-ack'
  data?: any;               // optional context (e.g., { surveyId })
  ts: number;               // Date.now()
};
```

**Reason codes (canonical):**
- Boot: `init-start`, `ready`, `player-timeout`
- Present: `present-start`, `present-complete`, `present-cancelled`, `present-failed`, `implicit-ack`
- Dismiss: `dismiss-start`, `dismiss-complete`, `dismiss-failed`
- Liveness: `heartbeat-missed-2`
- Lifecycle: `destroy`
- Generic timeout: `ack-timeout`

---

## 2) Bridge API additions
```ts
class Bridge {
  // NEW: read-only state
  public get state(): BridgeState;

  // NEW events (add to your emitter union)
  on(event: 'statechange'|'status'|'error'|'ready'|'close', cb:(p:any)=>void): void;
}
```

---

## 3) Bridge implementation — drop‑in patches

### 3.1 Add state + setter
```ts
// inside Bridge class
private _state: BridgeState = 'UNMOUNTED';
public  get state(): BridgeState { return this._state; }

private setState(next: BridgeState, reason?: string, data?: any) {
  const prev = this._state;
  if (prev === next) return;
  this._state = next;
  const payload: StateChange = { prev, next, reason, data, ts: Date.now() };
  this.emit?.('statechange', payload);
  if (next === 'IDLE' && reason === 'ready') this.emit?.('ready'); // convenience
}
```

### 3.2 Use state in lifecycle
**Init**
```ts
async init(config = {}) {
  this.setState('BOOTING', 'init-start');
  try {
    // ... existing handshake: wait hello → post init → wait ready
    this.setState('IDLE', 'ready');
  } catch (e) {
    this.setState('ERROR', 'player-timeout');
    this.emit?.('error', { code:'player_timeout', message: String(e) });
    throw e;
  }
}
```

**Present & Dismiss**
```ts
present(surveyId: string, opts: { force?: boolean } = {}) {
  this.setState('PRESENTING', 'present-start', { surveyId });
  return this.post('present', { surveyId, force: !!opts.force })
    .then((res) => { this.setState('IDLE', 'present-complete', { surveyId }); return res; })
    .catch((e) => {
      if (e?.code === 'cancelled') this.setState('IDLE', 'present-cancelled', { surveyId });
      else if (e?.code === 'implicit_ack') this.setState('IDLE', 'implicit-ack', { surveyId });
      else this.setState('ERROR', 'present-failed', { surveyId, error: e });
      throw e;
    });
}

dismiss() {
  this.setState('DISMISSING', 'dismiss-start');
  return this.post('dismiss', {})
    .then((res) => { this.setState('IDLE', 'dismiss-complete'); return res; })
    .catch((e) => { this.setState('ERROR', 'dismiss-failed', { error:e }); throw e; });
}
```

**Ack handling (ensure observers get notified)**
```ts
// in onMessage() when matching an ack by id:
if (m.type === 'status') { entry.resolve(m.payload); this.emit?.('status', m.payload); return; }
if (m.type === 'error')  { entry.reject(m.payload);  this.emit?.('error',  m.payload);  return; }
```

**Heartbeat soft‑fail**
```ts
// after two missed pongs:
this.emit?.('status', { ok:false, event:'player-inactive' });
this.setState('IDLE', 'heartbeat-missed-2');
```

**Destroy**
```ts
destroy() {
  // ...cleanup timers/listeners/acks
  this.setState('UNMOUNTED', 'destroy');
  this.emit?.('close'); // one-time signal
}
```

---

## 4) UI logging hook — route into existing emit() pipeline

### 4.1 Bridge → Events
```ts
// where the Bridge is instantiated (e.g., preview/app/survey/bridge.js)
import { emit } from '../ui/events.js';

bridge.on('statechange', (s) => {
  emit({ type:'bridge_state', ts: s.ts, prev: s.prev, next: s.next, reason: s.reason });
});

bridge.on('status', (p) => {
  if (p?.event) emit({ type:'bridge_event', ts: Date.now(), event: p.event });
});

bridge.on('error', (e) => {
  emit({ type:'error', ts: Date.now(), code: e?.code || 'bridge_error', message: e?.message || 'Bridge error', data: e });
});

bridge.on('close', () => {
  emit({ type:'bridge_state', ts: Date.now(), prev: bridge.state, next: 'UNMOUNTED', reason: 'destroy' });
});
```

### 4.2 Add minimal handlers in `ui/events.js`
```diff
 export function emit(evt) {
   // existing logging
   switch (evt.type) {
+    case 'bridge_state':
+      log('ui','event', `Bridge ${evt.prev} → ${evt.next}`, { reason: evt.reason }); break;
+    case 'bridge_event':
+      log('ui','event', evt.event || 'bridge-event'); break;
     // ... existing cases (tag_ready, present, trigger, theme_applied, error, etc.)
   }

   // existing toasts
   switch (evt.type) {
+    case 'bridge_state':
+      if (evt.reason === 'present-start') toast.info?.('Presenting…');
+      if (evt.reason === 'present-complete') toast.success?.('Agent presented.');
+      if (evt.reason === 'heartbeat-missed-2') toast.info?.('Player inactive — will recover on next command.');
+      if (evt.next === 'ERROR') toast.error?.('Bridge error');
+      break;
+    case 'bridge_event':
+      // optional: show nothing or a subtle info toast
+      break;
     // ... existing cases
   }

   // telemetry sinks stay as-is
 }
```

> If you prefer not to modify `emit()`, you can call `log()` directly in the Bridge listeners. Using `emit()` keeps behavior consistent with Step‑3 toasts.

---

## 5) Test helpers

### 5.1 Wait for a state transition
```ts
export function waitForState(bridge, next, { reason, timeout = 2000 } = {}) {
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => reject(new Error(`timeout waiting for state=${next}${reason?`/${reason}`:''}`)), timeout);
    const h = (s) => {
      if (s.next === next && (reason ? s.reason === reason : true)) {
        clearTimeout(t); bridge.off('statechange', h); resolve(s);
      }
    };
    bridge.on('statechange', h);
  });
}
```

### 5.2 Example spec (Playwright/Jest)
```ts
await bridge.init({ placement: 'BR' });
await waitForState(bridge, 'IDLE', { reason: 'ready' });

const p = bridge.present('demo-1', { force: true });
await waitForState(bridge, 'PRESENTING', { reason: 'present-start' });
await p;
await waitForState(bridge, 'IDLE', { reason: 'present-complete' });
```

---

## 6) Acceptance criteria
- `bridge.state` reflects lifecycle; `statechange` emitted on every transition with a reason string.
- `close` emitted exactly once on `destroy()`.
- On every ack, Bridge resolves/rejects **and** emits `status`/`error` to observers.
- Heartbeat soft‑fails after two missed pongs (`player-inactive` event + statechange reason `heartbeat-missed-2`). 
- UI shows clear breadcrumbs through `emit()` (log lines + modest toasts).
- Tests can wait on `statechange` instead of polling time or geometry.

---

## 7) Migration notes
1) Add state machinery + events to Bridge.
2) Wire Bridge listeners to `emit()`; add the two small cases in `ui/events.js`.
3) Replace brittle test polling with `waitForState(...)`.
4) Keep `compatImplicitAck` enabled during Player migration; set reasons to `implicit-ack` when used.
5) After Player acks are universal, disable the shim and remove any special‑case toasts if desired.

---

## 8) Pitfalls & guardrails
- Don’t flip state on **stray** acks (id not found) — they belong to a cancelled command.
- Guard duplicate transitions (`prev === next`) to avoid noisy logs.
- Keep toasts subtle for `statechange`; rely on `status.event` (e.g., `present-called`) for success confirmation.
- This addendum does **not** alter Protocol v1 payloads or security posture (still validate `origin`, still use exact `targetOrigin`).

---

## 9) Tiny “done” checklist
- [ ] Bridge exposes `.state` and emits `statechange`/`close`.
- [ ] `emit()` logs new `bridge_state` and `bridge_event` cases.
- [ ] Present/Dismiss update state at start and completion.
- [ ] Heartbeat soft‑fail maps to `player-inactive` + statechange.
- [ ] Tests use `waitForState` and pass without time‑based polling.
