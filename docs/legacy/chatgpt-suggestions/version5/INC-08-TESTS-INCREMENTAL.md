# Phase‑B (Incremental) — Tests

## 1) PresentationController
- Manual lock suppresses autos for lock window.
- Auto cooldown suppresses repeat within cooldown.
- Delegation prefers presentSurvey (if present), else bridge.present.

## 2) scrollDepthTarget
- Fake element with scrollTop/scrollHeight/clientHeight → milestones at 10/20/… fire once.

## 3) responsesDriver
- Rules: [{ when:'scroll>=30', do:'present', arg:'S1' }]; emitting behavior:scroll-depth {percent:30} calls presenter.presentAuto('S1') once.
