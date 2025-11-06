# Bridge Implementation (Protocol v1)

The Bridge lives in the parent window, manages the Player iframe, sends commands, and enforces **acks**, **timeouts**, and **heartbeats**.

---

## 1) API (TS shape)

```ts
class Bridge {
  constructor(opts: {
    iframe: HTMLIFrameElement;
    playerOrigin: string;            // exact origin derived from iframe src
    ackTimeoutMs?: number;           // default 3000
    handshakeTimeoutMs?: number;     // default 5000
    heartbeatMs?: number;            // default 30000
    debug?: boolean;
    compatImplicitAck?: boolean;     // temporary shim; default true during rollout
  });

  init(cfg?: { placement?: 'BR'|'BL'|'TR'|'TL', density?: -1|0|1,
               tokens?: { brand?: string, radius?: number, density?: -1|0|1 } }): Promise<void>;

  present(surveyId: string, opts?: { force?: boolean }): Promise<any>;
  dismiss(): Promise<any>;
  applyTheme(input: { href?: string, css?: string, tokens?: { brand?: string, radius?: number, density?: -1|0|1 } }): Promise<any>;
  trigger(command: string, ...args: any[]): Promise<any>;
  setPlacement(p: 'BR'|'BL'|'TR'|'TL'): Promise<any>;
  setTokens(tokens: { brand?: string, radius?: number, density?: -1|0|1 }): Promise<any>;

  on(event: 'ready'|'status'|'error'|'close', cb:(payload:any)=>void): void;
  destroy(): void;
}
```

---

## 2) State machine
```
UNMOUNTED → BOOTING → IDLE → PRESENTING → DISMISSING → IDLE
              ↘ ERROR
```
- `BOOTING`: waiting for `hello`, then sending `init`, then expecting `ready`.
- `PRESENTING`/`DISMISSING`: a presentation command is in flight (single‑flight lane).

---

## 3) Ack map & emit behavior
- Maintain `acks: Map<id, {resolve,reject,kind}>`.
- When an incoming message has type `status|error` and matching `id`:
  - Resolve/reject the saved Promise.
  - **Also emit** `status`/`error` events to observers (tests & UI rely on this).

```ts
if (m.type === 'status') { entry.resolve(m.payload); emit('status', m.payload); }
if (m.type === 'error')  { entry.reject(m.payload);  emit('error',  m.payload);  }
```

---

## 4) Concurrency lanes
- **Presentation lane**: keep `inFlight.present`. A new `present` cancels the prior one (`reject({code:'cancelled'})`), then sends.
- **Tuning lane**: simple FIFO queue. Safe to overlap with presentation.

---

## 5) Origin derivation
Derive from the iframe `src` (works with relative paths and dev proxies):

```ts
function derivePlayerOrigin(iframe: HTMLIFrameElement): string {
  const u = new URL(iframe.getAttribute('src') || '', window.location.href);
  return u.origin;
}
```
Optionally allow `?playerOrigin=` query param to override in dev.

---

## 6) Heartbeat
- Start after `ready`.
- Every `heartbeatMs`, send `ping` with `awaitAck=true`.
- Two consecutive `ack_timeout` → emit a soft `status { ok:false, event:'player-inactive' }` and keep UI usable.

---

## 7) Compatibility shim (temporary)
If `compatImplicitAck=true` and a command hits `ack_timeout` **but** a geometry/status event arrives indicating success, resolve the Promise and `emit('error',{code:'implicit_ack'})` at `warn` level. Disable this flag when the Player is fully v1.

---

## 8) Logging
Wire Bridge events into your UI’s existing `emit()` → toasts/logs pipeline:
- `ready` → info toast “Player ready”
- `status.ok` on present/theme/trigger → success/info toast
- `error` → red toast with taxonomy code

---

## 9) Minimal usage

```ts
const iframe = document.getElementById('pi-v3-player') as HTMLIFrameElement;
const origin = new URL(iframe.src, location.href).origin;
const bridge = new Bridge({ iframe, playerOrigin: origin, debug:false });

await bridge.init({ placement:'BR', density:0, tokens:{ brand:'#7c5cff', radius:8 } });
bridge.on('status', s => console.log('status', s));
bridge.on('error',  e => console.warn('error', e));

await bridge.present('survey-123', { force:true });
await bridge.applyTheme({ href:'/theme/indigo.css' });
await bridge.trigger('simulateExitIntent');
```

---

## 10) Acceptance checks (Bridge)
- Ignores messages from unexpected origins.
- Emits `status`/`error` on every ack.
- Cancels superseded `present` requests.
- Heartbeat soft‑fails after 2 missed `pong`s.
