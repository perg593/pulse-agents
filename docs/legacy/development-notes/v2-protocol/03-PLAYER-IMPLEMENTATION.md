# Player Implementation — Protocol v1

The Player iframe hosts the Pulse Tag, theming, and trigger handling. It must implement the v1 handshake, ack every command, and report geometry in `status`.

## Handshake

1) On load → send `hello { playerVersion, supports }`.  
2) On `init` → apply placement/density/tokens → send `status { ok:true }` (optional) → send `ready` (required).

## Command handlers (ack after async completes)

- **present**: call your Tag’s present; `ack` after success with `status { ok:true, widget:{ visible:true, bounds } }`. On failure → `error { code:'present_fail', message }`.
- **dismiss**: hide/close the widget; `ack` after success.
- **applyTheme**: if `href`, create `<link>` and wait for `load`; if `css`, create `<style>` and inject; then `ack`.
- **trigger**: translate to `pi('command', ...)`; `ack` after completion (or next tick if fire‑and‑forget).
- **setPlacement / setTokens**: update runtime config; `ack` immediately; if geometry changes, include new bounds in the payload or send a follow‑up `status`.

## Geometry reporting

Use `ResizeObserver` + visibility observers inside the Player to produce:

```jsonc
{ "widget": { "visible": true, "bounds": { "x": 944, "y": 620, "w": 320, "h": 188 } }, "placement": "BR" }
```
Send on first present and whenever size/position changes (debounce 16–32ms).

## Security

- Lock to the first message origin: set `bridgeOrigin` from `event.origin` on the first accepted message and require it for all responses.
- Use `window.parent.postMessage(..., bridgeOrigin)` (never `"*"`).

## Errors

Use the taxonomy: `boot_fail`, `present_fail`, `unknown_cmd`, `bad_payload`, etc. Include `recoverable` where appropriate and a short `hint` (e.g., “Check tag install”).

## Heartbeat

Respond `pong` to `ping` within one tick; no extra payload required.
