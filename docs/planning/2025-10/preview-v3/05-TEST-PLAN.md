# Test Plan — Bridge/Player Protocol v1

## Unit tests

- **Envelope validation**: ignore wrong `v`, reject unknown origin, accept known types.
- **Ack timeout**: Promise rejects with `ack_timeout` after 3s if no status/error.
- **Heartbeat**: two missed pongs triggers inactive path (soft warning).
- **Origin derivation**: `derivePlayerOrigin()` returns correct origin for relative src, proxy, and absolute URLs.

## Integration tests (headless browser)

1) **Handshake**: `hello → init → ready` within 5s; state = IDLE.
2) **Present success**: `present` → `status{ok:true}`; Agent badge changes to Presenting.
3) **Present failure**: Player returns `error{present_fail}`; Agent badge resets to Idle; toast logged.
4) **Apply theme (href)**: link loads; status ok.
5) **Apply theme (css)**: style injected; status ok.
6) **Trigger**: send `simulateExitIntent`; status ok.
7) **Concurrency**: two `present` fired quickly; first Promise rejects with `cancelled`, second resolves.
8) **Ack timeout with geometry** (compat on): implicit ack path resolves and logs `implicit_ack` warning.
9) **Security**: forged message from wrong `origin` ignored (no state change).
10) **Heartbeat recovery**: pause pongs; bridge downgrades to Idle; resume pongs; next command succeeds.

## Performance budgets

- Handshake p95 < 400 ms (local dev).
- Ack p95 < 250 ms for `present` and `trigger` in preview.
