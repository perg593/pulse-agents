# Bridge Implementation — Protocol v1

This document replaces legacy `createSurveyBridge` with a class that speaks **v1** and enforces explicit acks, timeouts, and security.

## API (TypeScript notation)

```ts
class Bridge {
  constructor(opts: {
    iframe: HTMLIFrameElement;
    playerOrigin: string;          // exact origin (see Origin section)
    ackTimeoutMs?: number;         // default 3000
    handshakeTimeoutMs?: number;   // default 5000
    heartbeatMs?: number;          // default 30000
    debug?: boolean;
    compatImplicitAck?: boolean;   // default true until Player upgrade complete
  });

  init(cfg?: { placement?: 'BR'|'BL'|'TR'|'TL'; density?: -1|0|1; tokens?: { brand?: string; radius?: number; density?: -1|0|1 } }): Promise<void>;

  present(surveyId: string, opts?: { force?: boolean }): Promise<any>;
  dismiss(): Promise<any>;
  applyTheme(input: { href?: string; css?: string; tokens?: { brand?: string; radius?: number; density?: -1|0|1 } }): Promise<any>;
  trigger(command: string, ...args: any[]): Promise<any>;
  setPlacement(place: 'BR'|'BL'|'TR'|'TL'): Promise<any>;
  setTokens(tokens: { brand?: string; radius?: number; density?: -1|0|1 }): Promise<any>;

  on(event: 'ready'|'status'|'error'|'close', cb: (payload:any)=>void): void;
  destroy(): void;
}
```

## State & timing

- States: `UNMOUNTED → BOOTING → IDLE → PRESENTING → DISMISSING → IDLE` (ERROR on any failure).
- Handshake timeout 5s → `player_timeout` error.
- Command ack timeout 3s → `ack_timeout` error and Agent badge returns to *Idle*.

## Concurrency

- **Presentation lane** (present/dismiss): single‑flight; newer cancels older with `cancelled` code.
- **Tuning lane** (theme/tokens/placement): FIFO; may overlap with presentation.

## Origin derivation

Derive from the iframe `src`:

```ts
function derivePlayerOrigin(iframe: HTMLIFrameElement) {
  const u = new URL(iframe.getAttribute('src') || '', window.location.href);
  return u.origin; // works for dev proxy, relative paths, and prod
}
```

Allow a developer override via `?playerOrigin=` query param in preview.

## Heartbeat

- Start after `ready`.
- Send `ping` every 30s; expect `pong` within `ackTimeoutMs` (3s).
- Two missed pongs → surface “player inactive”; keep UI functional.

## Compatibility shim (until Player acks exist)

If `compatImplicitAck=true` and a command hits `ack_timeout` **but** the UI receives a `status`/geometry event that clearly implies success, resolve the Promise and emit a **warning** event with `code:"implicit_ack"`. Disable this flag in the final PR.

## Events

- `ready`: handshake completed.
- `status`: pass‑through of Player `status` (geometry, placement). Update badges here.
- `error`: pass‑through of Player `error` or locally generated errors (`ack_timeout`, `player_timeout`, `cancelled`).

## Logging

Bridge should integrate with the preview’s `emit()` pipeline so all `status`/`error` surface in the log panel and toasts.
