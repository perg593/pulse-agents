# Phase‑B (Incremental) — Architecture & Principles

**Goal:** Add behavior‑driven triggering to `preview/basic` **without** refactoring the existing layout or duplicating boot. Keep the **manual left rail** working exactly as is.

**We will NOT:**
- Replace `preview/basic/index.html` structure or overlay DOM.
- Introduce a second boot layer (no new `app.js` that loads a second bridge).
- Change the v1 Bridge wrapper API or test contracts.

**We WILL:**
- Add small modules that **plug into** `preview/basic/preview.js` (the orchestrator) via tiny hooks.
- Reuse your existing **Bridge** wrapper and its events (`present()`, `applyTheme()`, `sendTrigger()`, `onStatus`, `onReady`, etc.). The v1 path queues until ready and emits `present-called` on ack.
- Preserve integration test expectations (queued present → ready → `present-called`; cancellation error code).

---

## Minimal new modules (all optional to import individually from `preview.js`)

```
preview/basic/lib/behaviorBus.js            # tiny event bus
preview/basic/lib/scrollDepthTarget.js      # scroll engine bound to a target element (not window)
preview/basic/lib/rulesStore.js             # source of truth for current demo rules
preview/basic/lib/presentationController.js # “manual wins / cooldown / single-flight” wrapper
preview/basic/lib/responsesDriver.js        # evaluate rules on behavior events, call controller
```

All modules are **standalone** and **not auto‑booted**. You opt‑in from `preview.js` where you already load the host iframe, overlays, and bridge.

---

## Compatibility knobs

- **Preserve deep links (default):** we do **not** remove `?demo_for` automatically. If you want ephemeral behavior later, set `EPHEMERAL_DEMO_FOR=true` in `preview.js` and we provide a one‑liner to call `history.replaceState` after ingestion.
- **Target scroll container:** the engine accepts `{ target: HTMLElement }` so you can bind to your **internal scrollable stage** instead of `window`. (Fallback to `documentElement` if omitted.)
- **Present API compatibility:** the controller calls your **existing** rail function (`presentSurvey({ id, force, allowDuplicate, source })`) if available; otherwise it falls back to the wrapper’s `present(id)`.

---

## Acceptance (unchanged)

- First load or no demo selected → **Demo Library** overlay shows.
- Selecting a demo adds/retains `?demo_for=...`, ingests its surveys, and **Behavior Lab remains hidden**.
- For this phase, only **Scroll Depth** auto‑triggers. Log milestones at **10,20,…,100%**.
- Manual rail triggers continue to function and **always win** over auto events.
