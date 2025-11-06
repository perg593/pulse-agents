# Phase‑B Follow-up

1. Wire the demo ingestion flow to `RulesStore.shared()` using `RulesStore.fromIngestion(...)` once we normalize the sheet data so that `attachResponses` can actually drive auto-present.
2. Decide when to remove the legacy behavior detectors (`setupBehaviorDetectors`) so scroll auto-present comes exclusively from the new scroll-depth engine/responses driver.
3. Once (2) is complete, populate real rules and confirm no duplicate presents occur before re-enabling auto behavior.
4. Consider exposing a hook when the Behavior Lab overlay mounts so we can call `scrollDepthEngine.retarget(...)` at exactly the right time instead of relying on `initializeBehaviorLab`.
