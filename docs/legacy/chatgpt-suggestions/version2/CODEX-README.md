# Pulse Demo v3 — Codex Working Pack

This pack codifies the updated plan based on the protocol review and Codex’s risk assessment. It is the *source of truth* for the Bridge ⇄ Player migration to **Protocol v1**.

> Contents
> - 01 — PROTOCOL‑V1.md (envelope, types, timing, errors, security)
> - 02 — BRIDGE‑IMPLEMENTATION.md (API, state, concurrency, origin, heartbeats)
> - 03 — PLAYER‑IMPLEMENTATION.md (handlers, ack semantics, geometry)
> - 04 — COMPAT‑SHIM‑AND‑ROLLOUT.md (flags, migration, revert)
> - 05 — TEST‑PLAN.md (unit/integration/contract tests)
> - 06 — SECURITY‑CHECKLIST.md (origin, sandbox, CSP)

---

## Scope

- Replace legacy `createSurveyBridge` path with a typed **Bridge** that speaks **Protocol v1** via `postMessage`.
- Upgrade the Player iframe to ack every command, respond to heartbeats, and report geometry through `status`.
- Keep preview stable during migration via a **feature flag** and an **implicit‑ack compatibility shim**.
- No IA or UI copy changes; existing log/toast pipeline is reused.

---

## Definitions of Done (DoD)

- **Handshake**: `hello → init → ready` completes < 5s (p95 in local preview).
- **Ack**: 100% of commands receive `status`/`error` with the *same id* < 3s (p95).
- **Security**: every received message’s `event.origin` matches expected; every sent message uses a precise `targetOrigin`.
- **Resilience**: two missed heartbeats downgrade state to *Idle* and surface a soft warning.
- **Tests**: all cases in *05 — TEST‑PLAN.md* pass in CI for both legacy and v1 paths during the compat window.
- **Docs**: headers in `bridge.js` and `player.js` reference **Protocol v1** and error taxonomy.
