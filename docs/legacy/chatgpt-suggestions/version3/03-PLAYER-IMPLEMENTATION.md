# Player Implementation (Protocol v1)

The Player runs inside an iframe. It must perform the handshake, **ack every command once**, and report geometry so the Bridge can align overlays.

---

## 1) Boot & handshake

```js
// on load
post({ type:'hello', payload:{ playerVersion:'1.0.0', supports:['applyTheme','trigger'] } });

on('init', (payload, id) => {
  applyPlacement(payload.placement);
  applyDensity(payload.density);
  applyTokens(payload.tokens);
  ack(id, { ok:true });           // optional 'init' ack
  post({ type:'ready', id });     // required
});
```

**Origin lock:** On first accepted message, set `bridgeOrigin = event.origin` and reject any others.

---

## 2) Ack semantics (when to ack)

Ack **after** the asynchronous work finishes:

- `present`: after Pulse Tag’s `present` call resolves (or its “shown” callback).  
  Payload example: `{ ok:true, event:'present-called', widget:{ visible:true, bounds:{...} } }`

- `dismiss`: after the widget closes.

- `applyTheme`: if `href` → create `<link>` and wait for `onload`; if `css` → inject `<style>`; then ack.

- `trigger`: after `pi('command',...)` returns (or on next tick if fire‑and‑forget).

- `setPlacement`/`setTokens`: update config synchronously; ack immediately.

On failure, `nack` with taxonomy code + `recoverable?: boolean`.

---

## 3) Geometry reporting
Use `ResizeObserver` + visibility checks to push bounds whenever they change (debounce 16–32ms).

```js
const ro = new ResizeObserver(() => emitBounds());
function emitBounds() {
  const b = widget.getBoundingClientRect();
  post({ type:'status', payload:{ ok:true, widget:{ visible: !widget.hidden, bounds:{ x:b.x, y:b.y, w:b.width, h:b.height } } } });
}
```

---

## 4) Heartbeat
On `ping {id}`, reply quickly with:
```js
ack(id, { ok:true });
post({ type:'pong' });
```

---

## 5) Security
- Validate `event.origin === bridgeOrigin` before processing.
- Post replies with `window.parent.postMessage(out, bridgeOrigin)` (never `"*"` in production).
- No dynamic `eval`; treat payloads as data only.

---

## 6) Minimal skeleton (pseudo‑TS)

```ts
let bridgeOrigin = '*'; // lock on first valid message

function post(msg){ parent.postMessage({ v:1, id: msg.id || rid(), type: msg.type, payload: msg.payload, origin:'player' }, bridgeOrigin); }
function ack(id, payload={ ok:true }){ post({ type:'status', id, payload }); }
function nack(id, payload){ post({ type:'error',  id, payload }); }

window.addEventListener('message', (ev) => {
  const m = ev.data; if (!m || m.v !== 1) return;
  if (bridgeOrigin === '*') bridgeOrigin = ev.origin;
  if (ev.origin !== bridgeOrigin) return;

  switch (m.type) {
    case 'init': /* apply settings */ ack(m.id); post({ type:'ready', id:m.id }); break;
    case 'present': present(m.payload).then(() => ack(m.id, { ok:true, event:'present-called' })).catch(e => nack(m.id, { code:'present_fail', message:String(e), recoverable:true })); break;
    case 'dismiss': /* ... */ ack(m.id); break;
    case 'applyTheme': /* href/css */ ack(m.id, { ok:true, event:'apply-theme-applied' }); break;
    case 'trigger': /* pi('command',...) */ ack(m.id, { ok:true, event:`trigger-${m.payload.command}` }); break;
    case 'setPlacement': /* ... */ ack(m.id); break;
    case 'setTokens': /* ... */ ack(m.id); break;
    case 'ping': ack(m.id); post({ type:'pong' }); break;
    default: nack(m.id, { code:'unknown_cmd' });
  }
});
```

---

## 7) Acceptance checks (Player)
- Sends `hello` immediately on load; `ready` after `init`.
- Acks or nacks every command exactly once.
- Emits geometry on first show and when bounds change.
- Locks origin and posts to that origin only.
