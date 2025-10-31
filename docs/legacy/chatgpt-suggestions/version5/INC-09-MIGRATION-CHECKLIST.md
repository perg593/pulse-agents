# Phase‑B (Incremental) — Migration & Decisions Checklist

## Decide
- [ ] Keep deep links (default) or set EPHEMERAL_DEMO_FOR=true to remove `demo_for` after ingestion.
- [ ] Confirm CSS selector for internal scroll stage.
- [ ] Confirm ingestion object shape; map to { when, do:'present', arg: survey_id } via RulesStore.fromIngestion().
- [ ] Route behavior logs through existing logger (disable our console log with { log:false }).

## Implement
- [ ] Add /lib modules (no auto-boot).
- [ ] Import & wire in preview.js only (single orchestrator).
- [ ] Start scroll engine with { target: stage } and attach responses.
- [ ] Rail remains unchanged; optional: use presenter.presentManual for unified logs.
