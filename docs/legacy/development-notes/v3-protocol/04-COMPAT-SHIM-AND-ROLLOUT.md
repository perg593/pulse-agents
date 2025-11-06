# Compatibility Shim & Rollout Plan

Goal: ship Protocol v1 without breaking today’s preview. We stage changes behind flags, verify, then remove the old path.

---

## 1) Flags
- `useProtocolV1` (bool or `?useProtocolV1=1`) — use new Bridge + protocol path.
- `compatImplicitAck` (bool; default **true** initially) — if a command times out but geometry implies success, resolve promise and log a warning `implicit_ack`. Set to **false** when Player fully acks.

---

## 2) PR sequence (small, safe increments)

**PR‑1 — Protocol + Bridge (behind flag)**
- Add `01-PROTOCOL-V1.md` to repo.
- Add `Bridge` class; keep legacy `createSurveyBridge` as default.
- Add unit tests for envelope, origin checks, acks, timeouts.

**PR‑2 — Player updates**
- Implement `hello/init/ready` + acks for all commands + heartbeat + geometry reporting.
- Keep legacy geometry messages for the compat window.

**PR‑3 — Flip default to v1 (keep shim)**
- Preview uses `useProtocolV1=true` by default.
- Run integration tests against real Player; watch ack rate.

**PR‑4 — Remove shim and legacy path**
- Set `compatImplicitAck=false`, delete old bridge.
- Lock CSP/sandbox; freeze protocol v1 headers in code.

---

## 3) Metrics & acceptance during rollout
- **Ack rate**: 100% of commands in CI return `status|error` with same id.
- **Handshake p95**: < 400ms locally.
- **Zero messages** accepted from wrong origin.
- **Two missed pongs** → soft inactive, no crashes.

---

## 4) Revert plan
- Toggle `useProtocolV1=false` to fallback to legacy bridge.
- Player changes can be deployed independently (keep old message handling for one release).

---

## 5) Developer experience (DX)
- Provide `?playerOrigin=` override in dev proxies.
- Log every v1 message once when `debug=true`.
- Shorter timeouts in test env: `ack=1000ms`, `handshake=2000ms`, heartbeat disabled.
