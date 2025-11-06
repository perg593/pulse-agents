# ARCH‑PROTOCOL v1 (Updated)

Version: **1.0.1** — adds explicit ack requirements, concurrency guidance, and two new error codes (`implicit_ack`, `cancelled`).

## 1) Envelope

```jsonc
{
  "v": 1,
  "id": "a7f2c",
  "type": "present",
  "payload": { },
  "origin": "bridge" // optional; for logging only
}
```

- **Ack discipline**: Every command MUST be answered by exactly one message with the *same `id`* and `type: "status"` (success) or `type: "error"` (failure).
- Unknown fields are ignored; additive payloads are non‑breaking.

## 2) Types

### Handshake
- `hello` *(Player → Bridge)*: `{ playerVersion: string, supports: string[] }`
- `init` *(Bridge → Player)*: `{ placement?: "BR"|"BL"|"TR"|"TL", density?: -1|0|1, tokens?: { brand?: string, radius?: number, density?: -1|0|1 } }`
- `ready` *(Player → Bridge)*

### Commands *(Bridge → Player)*
- `present`: `{ surveyId: string, force?: boolean }`
- `dismiss`: `{ }`
- `applyTheme`: `{ href?: string, css?: string, tokens?: { brand?: string, radius?: number, density?: -1|0|1 } }`
- `trigger`: `{ command: string, args?: any[] }`
- `setPlacement`: `{ placement: "BR"|"BL"|"TR"|"TL" }`
- `setTokens`: `{ brand?: string, radius?: number, density?: -1|0|1 }`
- `ping`: `{ }`

### Reports *(Player → Bridge)*
- `status`: `{ ok: true, widget?: { visible: boolean, bounds?: { x:number,y:number,w:number,h:number } }, placement?: string, capabilities?: string[] }`
- `error`: `{ code: string, message?: string, recoverable?: boolean, hint?: string }`
- `pong`: `{ }`

## 3) Timing

- **Handshake timeout**: 5000 ms for `hello → ready`.
- **Ack timeout**: 3000 ms per command.
- **Heartbeat**: Bridge sends `ping` every 30000 ms; Player responds `pong`. Two consecutive misses → soft inactive state.

## 4) Concurrency & backpressure

- Only one **presentation** command (`present`/`dismiss`) may be in flight. Newer request **cancels** the prior one (`error{code:"cancelled"}` on the prior promise).
- **Tuning** commands (`applyTheme`, `setTokens`, `setPlacement`) execute in order and may overlap with a presentation in flight.

## 5) Error taxonomy

`boot_fail`, `player_timeout`, `not_ready`, `present_fail`, `gen_fail`, `cors_block`, `unknown_cmd`, `bad_payload`, `ack_timeout`, **`implicit_ack`**, **`cancelled`**.

## 6) Security (non‑negotiable)

- Set `targetOrigin` to the exact Player origin (derived from the iframe `src`). Never `"*"`.
- Reject any message whose `event.origin` doesn’t match the expected origin.
- Player should lock `bridgeOrigin` on the first received message and require it for all replies.
- Prefer `<link rel="stylesheet">` or inert `<style>` for CSS application; never `eval` payloads.

## 7) Geometry

Player SHOULD include `widget.visible` and `widget.bounds` in `status` whenever visibility or placement changes. Bridge uses this to anchor overlays without extra messages.

## 8) Extensibility

Add new commands with new `type` values. Removing fields is breaking; adding fields is safe. Use `supports` in `hello` to gate optional features.
