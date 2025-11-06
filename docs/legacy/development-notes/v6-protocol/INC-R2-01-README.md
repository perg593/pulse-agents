# Phase‑B (Incremental, Round‑2) — Behaviors + Coexistence (No Refactor)

**Objective**  
Layer behavior‑driven triggering into **existing** `preview/basic` without changing `index.html` or replacing `preview.js`. Keep manual left‑rail behavior 100% intact.

**Key Alignments with Cursor Feedback**
- **Single orchestrator:** We keep `preview.js` as the only boot path (no duplicate bridge/boot).
- **Unify events/logs:** A tiny bus and logger proxy so your existing `logBehavior(...)` and manual listeners become the single source of truth—no parallel systems.
- **Scroll target = internal stage:** The engine binds to **`#behavior-stage`** (or your final selector) and supports **retarget/reinit** when Behavior Lab is shown later.
- **Rules “catch‑up” on load:** If rules load after the user already scrolled past a threshold, the driver evaluates immediately (no missed fires).
- **Presenter delegates to your `presentSurvey(id, options)`** so Behavior Lab state and logs stay consistent. Falls back to `bridge.present(id)` if needed.
- **Deep‑link default:** We **keep** `?demo_for` (bookmarkable). Optional `EPHEMERAL_DEMO_FOR=true` later if you want removal.

**Deliverables**
- Minimal `/lib` helpers (opt‑in from `preview.js` only):
  - `behaviorBus.js` (EventTarget bus + proxy hook for your `logBehavior`)
  - `scrollDepthTarget.js` (bind to `#behavior-stage`, with **retarget** and **getPercent**)
  - `rulesStore.js` (normalize rules from your sheet ingestion)
  - `presentationController.js` (manual‑wins, single‑flight, cooldown; delegates to `presentSurvey`)
  - `responsesDriver.js` (evaluate `scroll>=N` rules; **catch‑up** on load)
- A short wiring guide (exact import points + 3 small hooks).
- Focused unit tests (controller, scroll engine retarget, catch‑up).

**Contracts preserved**
- Uses your existing v1 bridge wrapper: `createSurveyBridge`, `present`, `applyTheme`, `sendTrigger`, status/ready/error events. The v1 path queues until ready, acks with `present-called`, and cancels superseded presents with `code:'cancelled'`. We rely on that, unchanged.  <!-- cite in chat -->
