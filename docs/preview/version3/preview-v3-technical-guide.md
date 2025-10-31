# Pulse Demo Studio v3 — Technical Guide

This document covers the architecture, modules, and data flows that power `preview/v3/index.html`. Version 3 replaces the “basic” preview with a modular system built around a namespaced DOM, adapters, and a token-driven design layer. Use this guide to extend features, troubleshoot integrations, or prepare deployments.

---

## 1. Project structure

```
preview/v3/
├── index.html                # Entry page (accordion rail + preview stage)
├── v3.js                     # Main controller store + UI wiring
├── v3.css                    # Component styles consuming design tokens
├── adapter/pulse-adapter.js  # Bridge to survey iframe/tag
├── services/
│   ├── surveys.js            # Agent catalog loader (CSV + fallback)
│   └── themes.js             # Curated/generated theme helpers
├── triggers/config.js        # Trigger definitions
├── ui/
│   ├── selectors.js          # Canonical selector mapping shim
│   ├── log.js                # Structured log writer
│   ├── events.js             # emit() fan-out (log, toast, telemetry)
│   ├── toast.js              # Toast rendering/queue
│   ├── telemetry.js          # Telemetry sinks (console default)
│   └── theme.js              # Quick-knob + light/dark API
└── theme/
    ├── tokens.css            # Token root (brand, spacing, effects)
    ├── theme-dark.css        # Default palette
    └── theme-light.css       # Light-mode overrides
```

Supporting assets live outside `v3/`:

- `preview/v3/data/example-themes.json` — curated theme manifest copied from the generator output.
- `app/survey/bridge.js` (shared) — iframe bridge used by Pulse adapters.

---

## 2. Layout & DOM contract

### Root structure

`index.html` wraps the page in `<body class="pi-v3">`. Namespacing keeps token overrides scoped and simplifies future theming.

```
<body class="pi-v3">
  <div class="pi-v3__app">
    <aside class="pi-v3__rail">…</aside>
    <main class="pi-v3__preview">…</main>
  </div>
  <div id="pi-v3-toasts" aria-live="polite" aria-atomic="true"></div>
</body>
```

#### Left rail — accordion

Single-open accordion with sections that mirror the Demo Studio flow:

1. **Agent** — combobox (`#pi-v3-agent-select`), placement pill group, variant select, Launch button, embed link.
2. **Appearance** — tabs (Auto vs Manual), generate-theme controls, curated presets, “Quick knobs” (color/radius/density).
3. **Triggers** — present-now primary button + simulated triggers grid.
4. **Examples** — industry & use-case filters, info chip.
5. **Tools** — status badges, appearance mode toggle, event-log button, reset button.

#### Preview stage

Toolbar (URL, device, placement pills, safe-area toggle, reload). Below it, `.pi-v3__frame-wrapper` hosts:

- The preview iframe (`#pi-v3-frame`).
- Safe-area overlay (`.pi-v3__safe-outline`).
- Agent overlay container (`#pi-v3-agent-overlay`) where the Pulse survey iframe mounts.
- Ghost agent placeholder (visible until the real agent loads).

The sidebar log panel (`.pi-v3__log-panel`) is globally positioned and toggled via Tools.

#### Selector shim

The Step‑2 spec defined canonical IDs (`previewUrl`, `triggerPresent`, etc.) that differ from the Step‑1 markup. Rather than rename the DOM (to avoid churn mid‑build), `ui/selectors.js` maps canonical names to actual selectors (`#pi-v3-preview-url`, `[data-device="Desktop"]`, …) and attaches `data-el` attributes at runtime. All modules call `UI(N.previewUrl)` to retrieve elements.

---

## 3. State model & event bus (`v3.js`)

`v3.js` exports a central store and event bus:

```js
export const store = {
  url: 'https://example.com',
  device: 'Desktop',         // 'Desktop' | 'Tablet' | 'Mobile'
  placement: 'BR',           // 'BR' | 'BL' | 'TR' | 'TL'
  safeArea: true,
  tagReady: false,
  agentStatus: 'Idle',       // 'Idle' | 'Presenting'
  lastPresentedId: undefined,
  pendingSurveyId: undefined,
  agents: [],
  selectedAgent: undefined,
  stylesheetRegistry: new Map(),   // theme descriptors
  generatedThemeAssets: [],
  activeThemeId: undefined,
  logs: [],
  themeMode: 'dark',               // 'dark' | 'light' | 'auto'
  brandColor: '#7c5cff',
  radius: 8,
  density: 0                       // 1 cosy, 0 comfortable, -1 compact
};

export const bus = new EventTarget();
export function setState(patch) {
  Object.assign(store, patch);
  bus.dispatchEvent(new Event('state'));
}
```

A watcher (`bus.addEventListener('state', render)`) re-renders UI slices depending on state (placement, device, safe area, toasts, knobs, theme mode, etc.).

### Initialization workflow

`DOMContentLoaded → init()`, which:

1. Caches DOM nodes using `UI()` selectors.
2. Loads user theme preferences via `Theme.initFromStorage()` and applies quick-knob defaults.
3. Attaches interaction handlers (accordion, toolbar, placement, agent selection, themes, triggers, examples, tools, appearance toggle, log panel).
4. Calls `render()` once, then subscribes to store updates.
5. Initializes the Pulse adapter when the overlay container exists.
6. Boots the tag via `bootTag()`.
7. Fetches surveys (`loadSurveys`) and curated themes (`loadExampleThemes`), storing results in state and logging counts via `emit({ type:'init', … })`.

---

## 4. Data services

### 4.1 Surveys (`services/surveys.js`)

- Primary source: Google Sheet CSV (`SHEET_CSV_URL`).
- Fallback: local record for “Cyberhill Partners – Experience Agent Demo”.
- Exports `loadSurveys() → Promise<SurveyRecord[]>`. Each record includes `id`, `label`, optional `identifier`, optional `backgroundUrl`.
- On sheet failure, emits `error{ code:'sheet_off' }`, logs a warning, and returns the fallback array.

### 4.2 Themes (`services/themes.js`)

- Curated themes loaded from `preview/v3/data/example-themes.json` (copied from generator output). `loadExampleThemes()` returns descriptors with `id`, `label`, `href`, metadata.
- `generateFromUrl(url)` proxies to the existing generator client (`preview/basic/theme-generator-client.js`), revokes old blobs, and returns descriptors with `blobUrl`. Emits `error{code:'gen_fail'}` on failure.
- `applyThemeByHref(id,label,href)` and `applyGeneratedTheme(theme)` call `applyThemeHref` via adapter and update `store.stylesheetRegistry`, then emit `theme_applied`.
- `revokeGeneratedAssets()` revokes `blob:` URLs, clears state, and emits `theme_revoked`.
- `removeTheme(id)` clears registry entries and resets active theme (silent UI update).

---

## 5. Adapter & tag integration (`adapter/pulse-adapter.js`)

`initPulseAdapter(container)` wraps `createSurveyBridge` (shared with legacy preview). The adapter mediates between UI actions and the survey iframe.

### Key operations

- **`bootTag()`** — merges config, loads the iframe, and sets a timeout (3 s) to emit `tag_ready{ ready:false }` if the tag doesn’t respond. Clears pending timers once the tag reports ready.
- **`handleReady()`** — marks `tagReady=true`, emits `tag_ready{ ready:true }`, flushes any pending survey by emitting `present`.
- **`presentSurvey(agent, opts)`**:
  - Normalizes the agent object.
  - If tag not ready or account mismatch → reloads bridge, sets `pendingSurveyId`, emits `error{ code:'not_ready' }`.
  - Otherwise calls `bridge.present`, updates state, emits `present`.
- **`applyIdentifier()`** — `window.pi('identify', identifier)` for account switching.
- **`sendTrigger(command)`** — posts either `command` array or trigger ID; emits `error{code:'trigger_fail'}` on failure.
- **`applyThemeHref/clearThemeHref` + manual CSS** — pass-through to bridge theme APIs.

The adapter never touches DOM directly beyond the overlay container; it depends entirely on the store and emits/logs for UI feedback.

---

## 6. Event pipeline & telemetry

### `emit(evt)` (`ui/events.js`)

Central dispatch for user/system events. Each call:

1. **Logs** via `log(source, level, message, data)` in `ui/log.js`. Entries append to `store.logs` (max 200) and trigger re-render for the log panel.
2. **Toasts** via `toast.info|success|error` (`ui/toast.js`). Toast host is `#pi-v3-toasts`; queue enforces TTL (4 s by default).
3. **Telemetry sinks** (`ui/telemetry.js`) — default sink prints `[PulseDemo] eventType {…}` to the browser console; additional sinks can be pushed (e.g., fetch to analytics endpoint).

Event types implemented (Step‑3 spec):

- `init`, `tag_ready`, `present`, `trigger`, `theme_applied`, `theme_revoked`, `error`.

### Log module (`ui/log.js`)

`configureLog(getStore, onWrite)` installs callbacks; `log(source, level, message, data)` pushes entries to `store.logs` and runs `onWrite` to notify UI.

### Telemetry (console sink)

`console.log('[PulseDemo]', type, { ts, … })` ensures preview operators can inspect sequences without opening the log panel.

---

## 7. UI wiring highlights (`v3.js`)

### 7.1 Toolbar

- URL input validates on Enter/blur; invalid entries display inline hint (`--pi-danger`). Valid URLs are normalized (`https://` prefix) and stored.
- Device buttons toggle `store.device`, influencing frame width & ghost agent height.
- Placement pills (toolbar + Agent segment) sync via `store.placement`.
- Safe area toggled through `store.safeArea`, showing `.pi-v3__safe-outline`.
- Reload icon calls `reloadFrame(true)` (sets iframe `src` to `store.url`).

### 7.2 Agent selection

- Combobox uses datalist backed by `loadSurveys()` results. `agentLookup` maps by label and ID.
- On selection: stores `selectedAgent`, applies identifier, updates preview URL if `backgroundUrl`, and calls `presentSurvey`.
- “Launch Agent” always forces presentation (`force:true`) and sets a temporary timeout to return `agentStatus` to `Idle` after 2.5 s (until real player events are integrated).

### 7.3 Appearance

- Tabs (Auto/Manual) simply toggle panels (`switchTabs`).
- Generate theme → fetch suggestions, auto-apply first generated theme, update `store.activeThemeId`.
- Manual preset select → apply curated theme via `applyThemeByHref`.
- Applied styles list reads `store.stylesheetRegistry` and renders chips with remove buttons.
- Quick knobs:
  - Brand color input updates `--pi-brand` via `Theme.applyQuickKnobs`.
  - Radius slider updates `--pi-radius`.
  - Density select sets `data-density` (`-1/0/1`), altering spacing tokens.

### 7.4 Behavior lab

Manual forcing now lives in the rail (“Present now”). Everything else moved into the **Behavior Lab** card that sits above the preview iframe. The lab keeps behavioural demos in one place:

- **Preloaded survey** — the first survey returned by `loadSurveys()` is auto-selected and presented so triggers have something to act on. The summary pill mirrors `store.selectedAgent`.
- **Behavior list** — `TRIGGER_CONFIG` feeds two stacks:
  - *Perform these behaviors* → ids in `PERFORMABLE_BEHAVIORS` (exit intent, scroll 60%, idle 10s, rage click). They can be fired from the list or triggered physically in the stage.
  - *Simulate journeys* → longer sequences (checkout drop-off, pricing hesitation, returning visitor, support struggle). These always run as scripted simulations.
- **Hands-on stage** — `<div id="pi-v3-behavior-stage">` mimics a product page. `initBehaviorDetectors` instruments it so real gestures call back into the adapter. The message bar (`pi-v3__behavior-message`) announces detections or simulations.

Run-through for operators:

1. **Exit intent**  
   - Do it yourself: move the cursor upward until it leaves the stage; detector fires `exit_intent` and auto-simulates the trigger.  
   - Or click the list button to replay the scripted version.  
   Watch for `Exit intent simulated` in the log and the green toast.
2. **Scroll depth 60 %**  
   - Scroll the stage to roughly 60 %—the detector arms at 20 % and fires once `scrollTop` crosses the threshold (`describeBehaviorDetail` prints the percent).  
   - Clicking the list button issues `['simulateScrollDepth', { percent: 60 }]`.
3. **Idle for 10 s**  
   - Stop interacting with the stage; the idle timer (`IDLE_TIMEOUT_MS`) triggers `idle_10s`, reflected via `Idle detector armed` → `Idle complete` log entries.  
   - List button runs the same simulation immediately.
4. **Rage click**  
   - Mash the red “Why isn’t this working?” button. Four clicks within 600 ms (and 36 px radius) trip the detector.  
   - The scripted version sends `['simulateRageClick']`.
5. **Checkout drop-off**, **Pricing hesitation**, **Returning visitor**, **Support struggle**  
   - Pure simulations orchestrated in `runScenarioTimeline`. Each step emits `scenario-progress` logs, then a `scenario-qualified` line and an auto-`present` attempt. Use them to narrate longer journeys without touching the console.

Every trigger funnels through `fireTrigger` → `sendTrigger`/`sendCommand`, so toasts, logs, and telemetry stay consistent whether the action was performed or simulated. Encourage presenters to keep the log panel open so detections (especially the detector metadata like `~62% depth reached`) are visible to the audience.

### 7.5 Examples

- Examples update the info chip and log selection (no backend wiring in Step‑2).

### 7.6 Tools

- Status badges bound to `store.tagReady`/`store.agentStatus`.
- Appearance pill group toggles between dark/light/auto via `Theme.setMode`; state persisted in `localStorage`.
- Event Log toggles the log panel.
- Reset demo clears themes, quick knobs, agent selection, and resets store defaults (including theme mode/brand/radius/density).

---

## 8. Design tokens & theming

### Token files

- `tokens.css` — defines brand, semantically named neutrals, spacing, radius, density, transitions.
- `theme-dark.css` / `theme-light.css` — override neutrals and `color-scheme`. Light theme activated by adding `.is-light` class; `force-dark` ensures dark mode even if system prefers light.

### Component styling (v3.css)

- All components reference token variables for backgrounds, borders, text, and shadows (`var(--pi-color-surface)`, `var(--pi-brand)`, etc.).
- Buttons use consistent hover/active states (`color-mix` with brand colors).
- Toasts adopt `.pi-toast` naming and token colors.
- Focus rings apply `--pi-ring` across interactive elements.
- `prefers-reduced-motion` disables transitions/animations.

### Theme API (`ui/theme.js`)

```js
Theme.setMode('dark' | 'light' | 'auto');
Theme.applyQuickKnobs({ brand, radius, density });
Theme.initFromStorage(); // called at boot
```

`setMode('auto')` listens to `(prefers-color-scheme: light)` and toggles `.is-light` accordingly. Mode is persisted under `pi-v3-theme-mode`.

---

## 9. Triggers configuration

`triggers/config.js` holds the canonical list:

```js
export const TRIGGER_CONFIG = [
  { id: 'present_now', label: 'Present now', type: 'present', dom: 'present' },
  { id: 'exit_intent', label: 'Simulate exit-intent', dom: 'exit-intent', command: ['simulateExitIntent'] },
  …
];
```

`dom` aligns with the `data-trigger` attributes in markup, while `command` arrays feed the Pulse adapter. Adding new triggers requires updating this config and ensuring the player responds to the command via `bridge`.

---

## 10. Deployment considerations

- `.cfignore` excludes heavy directories (`node_modules`, `theme-generator`, etc.), making Cloudflare uploads lean.
- `preview/v3/data/example-themes.json` avoids depending on `theme-generator/` output at runtime.
- During Cloudflare deploy (Git or Wrangler), ensure `/preview/v3` is included and `theme/` CSS is loaded after `v3.css`.

---

## 11. Quick troubleshooting

| Symptom | Likely cause | Where to check |
| ------- | ------------ | -------------- |
| Toast shows “Tag not ready — queued” repeatedly | Adapter can’t reach `window.pi` | Ensure `bootPulseTag()` script loads; inspect console telemetry for `[PulseDemo] tag_ready`. |
| Generated themes don’t appear | `generateThemesFromUrl` failing | `services/themes.js` emits `error{code:'gen_fail'}` → watch toasts/console. |
| Curated themes missing | `example-themes.json` not found | Confirm file copied to `preview/v3/data/` and served by deploy. |
| No agents listed | CSV feed offline | Fallback message, logs `error{code:'sheet_off'}`. |
| Appearance toggle not persisting | localStorage blocked | Theme API falls back to dark mode; manual toggles still work in-session. |
| Ghost agent never hides | Tag never emits ready/present | Check adapter events; look for `[PulseDemo]` console output. |

---

## 12. Extending v3

- **New triggers**: add config entry, ensure player supports the command, update UI if label changes.
- **Additional quick knobs**: extend `Theme.applyQuickKnobs` and wire UI control to update tokens.
- **Telemetry sinks**: push new sink functions into `sinks` array (e.g., `sinks.push(evt => fetch('/telemetry', { method:'POST', body: JSON.stringify(evt) }))`).
- **Tag event callbacks**: extend `handleStatus` or `emit` to capture more player messages.
- **Dark mode enhancements**: tweak `theme-light.css` to brand-specific palettes (Step‑4 leaves placeholders for client themes).

With the modularized store, adapter, and token system, v3 can evolve without touching the legacy preview. Use this guide as the foundation for future Steps (e.g., analytics, multi-agent management, etc.).
