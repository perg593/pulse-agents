# Pulse Demo Studio

This document walks from a quick overview through deep technical detail so teammates can pick up the preview workspace at the level they need.

## 1. Quickstart (2 minutes)

1. **Install + launch**
```bash
./scripts/launch-preview.sh
```
   The script installs missing dependencies, regenerates data, and hosts the preview at `http://localhost:8000/preview/index.html`.

   > The index now redirects to the basic preview. Visit `/preview/v3/index.html` to explore the modular v3 prototype.

   > The remainder of this guide covers the modular interface (former default). Use it when you need advanced background controls or widget matrix demos.

2. **Load a background site** – Paste any URL (or `/preview/simple-background.html`) into *Site Background* and click **Load Site**.

3. **Pick a production survey** – Choose from *Production Surveys* and click **Present Selected Survey**. The player calls the live Pulse tag with account `PI-81598442`.

4. **Apply themes** – Select a client/theme/widget fixture, then click **Apply Theme** to inject the generated CSS into the running survey.

5. **Experiment with triggers** – Use the buttons in *Triggers* to simulate exit intent, rage clicks, scroll depth, timers, or to directly present the selected survey.

## 2. Guided Tour (5–10 minutes)

- **Sidebar panels**
  - *Client + Theme* loads fixtures and CSS from `theme-generator/output/preview-manifest.json`.
  - *Production Surveys* reads `preview/app/data/demo-surveys.json` (generated from the CSV) and feeds ID + metadata to the survey player.
  - *Triggers* posts structured commands to the player so you can demo behavioural journeys without editing console configuration.
  - *Site Background* swaps the iframe underneath the survey overlay. Inline demos require a same-origin page (use the bundled simple background or add your own under `preview/app/backgrounds/`).
  - *Manual CSS* injects any stylesheet into the running tag – useful for drop-in overrides or comparing competitor themes.

- **Workspace**
  - The background `iframe` mirrors the prospective client site.
  - The overlay container hosts `survey/player.html`, an iframe that loads the production `surveys.js` tag and exposes a postMessage bridge back to the UI.
  - Inline mode widens the container, reveals the inline note, and tells the player to attach to an on-page selector.

## 3. Architecture Snapshot (15 minutes)

```
preview/
├── app/
│   ├── data/demo-surveys.json        # Generated from CSV; drives production demo dropdown
│   ├── main.js                       # Orchestrates UI, state, and survey bridge
│   ├── services/                     # HTTP, manifest, demo-data, background helpers
│   ├── survey/bridge.js              # postMessage bridge -> survey player iframe
│   ├── survey/player.html|js         # Runs surveys-tag.js, handles triggers + CSS
│   ├── styles/main.css               # UI styling
│   └── ui/                           # DOM utilities, trigger renderer, status helpers
├── scripts/
│   ├── build-preview-data.js         # Existing manifest builder
│   ├── build-demo-data.js            # NEW: CSV → JSON converter
│   └── surveys-tag.js                # Production-aligned tag stub
├── demo-accounts-surveys-css.csv     # Source CSV maintained from the console
└── index.html                        # Shell that loads the modular app
```

- **Survey Player handshake**
  1. `main.js` asks `survey/bridge.js` to load `survey/player.html` with query params (account, present IDs, inline mode, theme CSS).
  2. `player.js` sets `window.PULSE_TAG_*` globals, injects `surveys-tag.js`, and listens for `pulseinsights:ready`.
  3. Once the remote tag boots, it notifies the parent via `postMessage({ type: 'player-ready' })` and exposes actions such as `present`, `apply-theme`, `apply-manual-css`, and behavioural `trigger`s.
  4. The parent flushes queued commands (themes, manual CSS) and updates the status list.

- **Data pipeline**
  - `scripts/refresh-preview.sh` (and the wrapper `launch-preview.sh`) now run `preview/scripts/build-demo-data.js` so the UI always has an up-to-date JSON feed of demo surveys.
  - Theme metadata continues to flow from `theme-generator/output/preview-manifest.json`, built by `npm run preview:build`.

## 4. Deep Dive (When you need to extend)

### Survey triggers

`survey/player.js` houses small simulators that mimic behavioural pathways:

| Trigger ID      | Simulation strategy |
| --------------- | ------------------- |
| `exit-intent`   | Dispatches a `mouseout` near the top of the viewport. |
| `rage-click`    | Sends a burst of click events to approximate frustration. |
| `scroll-depth`  | Scrolls the document to the bottom and fires `scroll`. |
| `time-delay`    | Resolves after 1.5s to demonstrate a timer callback. |
| `pageview`      | Calls `PulseInsightsObject.incrementPageviews()` when available. |

Add custom triggers by extending the table inside `buildTriggerConfig()` (UI label) and the map inside `runTrigger()` (player behaviour).

### Inline demonstrations

- Inline mode widens the survey frame and renders an “inline canvas” with a configurable target selector.
- Real inline surveys typically reference a selector configured in the console; if the selector requires special markup, create a bespoke background under `preview/app/backgrounds/` and point the background URL there.
- The selector can be overridden by editing `inlineTargetSelector` in `demo-accounts-surveys-css.csv`.

### Styling hooks

- Themes from the manifest are injected as `<link id="pi-theme-css">` once the player is ready.
- Manual CSS uses `<link id="pi-manual-css">`. Removing or swapping styles is as simple as sending a new link via the UI.
- If you need to inject raw CSS text, extend `survey/player.js` to detect `data.inlineCss` messages and append `<style>` elements.

### Module boundaries

- **UI modules** handle DOM refs only and never store global state.
- **Services** (HTTP, manifest, demo data, background) are stateless helpers.
- **Survey bridge** is the sole place that manipulates the iframe, ensuring a single postMessage contract.
- `main.js` acts as the conductor, mutating the `state` object and delegating work.

## 5. Extending & Deploying

- **Adding new demo surveys** – Update `preview/demo-accounts-surveys-css.csv` and rerun `scripts/build-demo-data.js` (or the full refresh script) to regenerate the JSON used by the UI.
- **Custom triggers** – Define the trigger in `buildTriggerConfig()` and mirror it inside `runTrigger()`.
- **Automation** – `scripts/launch-preview.sh` can be scheduled (e.g., via CI) to rebuild assets nightly. It exits once the HTTP server and health checks succeed, leaving Python’s `http.server` running in the background.
- **Fallback strategy** – If you need the preview without internet access, point `window.PULSE_TAG_SRC` at a local copy of `surveys.js` inside `survey/player.js`.

---

Need a different view? Start at the top of this file for the 2-minute version, or jump into section 4 to hack on the internals.
