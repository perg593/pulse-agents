# Tests — Focused & Incremental

## 1) PresentationController
- **Manual lock:** `presentManual('X')` then `presentAuto('Y')` within lock → returns `{ suppressed:'manual-lock' }` and only 'X' fired.
- **Cooldown:** `presentAuto('A')` then again within `autoCooldownMs` → `{ suppressed:'cooldown' }` and only one fire.
- **Delegation:** With a stub `presentSurvey`, the controller calls it (not the bridge).

## 2) Scroll engine retarget
- Create a fake stage element with `scrollTop/scrollHeight/clientHeight`; start engine; retarget to another element; ensure milestones are emitted from the **new** target only.

## 3) Responses catch‑up
- With rules `[ { when:'scroll>=30', do:'present', arg:'S1' } ]` and `engine.getPercent() → 45`, when `catalog:loaded` fires, driver immediately calls `presenter.presentAuto('S1')` once (no scroll needed).

> You can adapt your current harness; all modules are plain ESM and do not touch the bridge. The v1 bridge behavior and integration tests remain unchanged.
