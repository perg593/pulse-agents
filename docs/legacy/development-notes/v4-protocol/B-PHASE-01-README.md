# Phase‑B: Behaviors & Coexistence (Clean Pack)
**Scope:** Add behavior‑driven triggering to `preview/basic` while guaranteeing the existing **manual left‑rail flow** remains intact. No breaking changes to the v1 Bridge wrapper or the rail.

**Compatibility Guarantees**
- The **manual rail** continues to call `bridge.present(id)` exactly as today. No changes required.
- Behavior‑driven triggers use a small **Presentation Controller** that sits *above* the existing v1 wrapper to enforce: Manual‑wins, single‑flight, cooldown.
- All new code lives under `preview/basic/js/…`; prior Step‑1/2/3 scaffolding is unchanged.

**What this phase delivers**
1) Deterministic first‑load routing and overlays (Demo Library / Behavior Lab).  
2) A scroll‑depth engine emitting milestones every **10%** with console logs.  
3) Demo Catalog fetch that maps `demo_for` → surveys & simple rules (e.g., `scroll>=30 → present SURVEY_ABC`).  
4) Presentation Controller that arbitrates **manual vs auto**.  
5) Response handler that evaluates rules and calls the controller (or falls back to the bridge if the controller isn’t present).  
6) Tests focused on **coexistence** (manual lock, cooldown).

**Acceptance (unchanged from earlier brief)**
- Host iframe loads **https://pulseinsights.com/agents**.
- No `?demo_for` → show **Demo Library** overlay.  
- Selecting a library entry → add `?demo_for=…`, load that config, **Behavior Lab remains hidden** by default.  
- **Only Scroll‑Depth** is active now; it controls presentation.  
- Console logs behavior events at **10, 20, …, 100%**.  
- On first load with `?demo_for`, consume it and **remove it** immediately via `history.replaceState` (ephemeral).

**Dependency contracts (unchanged)**
- Uses your existing v1 wrapper from `preview/app/survey/bridge.js` (`createSurveyBridge`, `present`, `applyTheme`, `sendTrigger`, status/error/ready events).  
- Your integration test already proves queued → ready → `present-called` and cancellation semantics; we rely on those as‑is.
