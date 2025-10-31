# Compatibility Shim & Rollout Plan

## Flags

- `useProtocolV1` (bool or `?useProtocolV1=1` query param): select new Bridge + Player path.
- `compatImplicitAck` (bool, default **true** while rolling out): treat geometry/status as implicit success when ack is missing; log `implicit_ack` warning.

## PR Sequence

1) **PR‑1 — Protocol + Bridge (behind flag)**
   - Add PROTOCOL‑V1.md; add `Bridge` class and wire to preview when `useProtocolV1` is true.
   - Derive `playerOrigin` from iframe `src`; allow `?playerOrigin=` override.
   - Unit tests for envelope, origin validation, timeouts.

2) **PR‑2 — Player updates**
   - Implement handshake, acks, heartbeat; report geometry in `status`.
   - Keep legacy geometry messages for the compat window.

3) **PR‑3 — Enable by default; keep shim**
   - Flip preview to v1 by default; retain `compatImplicitAck=true` for one release.
   - Integration tests verify 100% acks on CI.

4) **PR‑4 — Remove shim and legacy bridge**
   - Set `compatImplicitAck=false`; delete `createSurveyBridge`.
   - Lock CSP/sandbox; finalize docs.

## Revert plan

- If failures spike, toggle `useProtocolV1=false` to drop back to the legacy path.
- Keep PR‑2 deployable separately so Player can be rolled back without touching the Bridge.
