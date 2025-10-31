# Pulse Insights — Demo Studio
## Step 2: Component Specs & Integration Wiring (v3)

**Scope:** Connect the v3 scaffold from Step‑1 to the existing preview/tag/theme logic. Keep toasts & telemetry for Step‑3 and visual tokens/dark mode for Step‑4.

- ✅ Implement real data flows: load agents, boot tag, present agent, apply curated & generated themes, trigger simulations.
- ✅ Replace “ghost‑only” wiring where specified.
- 🚫 Do **not** implement toasts/analytics/dark‑mode in this step.

---

## A) Project layout (adds on top of Step‑1)

```
preview/
  v3/
    index.html
    v3.css
    v3.js               # Step‑1 scaffold; keep
    adapter/
      pulse-adapter.js  # NEW: bridge to tag/theme functions and window.pi
    services/
      surveys.js        # NEW: survey list from Sheet or fallback
      themes.js         # NEW: curated + generated theme helpers
    ui/
      log.js            # NEW: central log/emit; used by all sections
```

> Names are suggestions—keep consistent imports if your build is bundle‑less.

---

## B) Data contracts (authoritative for v3)

```ts
// services/surveys.js
export type SurveyRecord = {
  id: string;
  label: string;            // for combobox display
  identifier?: string;      // account/user identifier, if provided
  backgroundUrl?: string;   // page to load in preview iframe
};

// services/themes.js
export type ThemeDescriptor = {
  id: string;
  label: string;
  origin: 'example'|'generated'|'manual';
  href?: string;            // curated theme <link>
  blobUrl?: string;         // generated CSS blob link
  tokens?: { brand?: string; radius?: number; density?: 'cozy'|'comfortable'|'compact' };
  meta?: { industry?: string; variant?: string };
};

// ui/log.js
export type LogEntry = {
  ts: number; // Date.now()
  level: 'info'|'warn'|'error'|'event';
  source: 'ui'|'tag'|'trigger'|'theme'|'net';
  message: string;
  data?: Record<string, unknown>;
};
```

---

## C) Store shape (v3.js)

```ts
export const store = {
  // Preview context
  url: 'https://example.com',
  device: 'Desktop',            // 'Desktop'|'Tablet'|'Mobile'
  placement: 'BR',              // 'BR'|'BL'|'TR'|'TL'
  safeArea: true,

  // Tag/Agent state
  tagReady: false,
  agentStatus: 'Idle',          // 'Idle'|'Presenting'
  lastPresentedId: undefined,
  pendingSurveyId: undefined,

  // Data
  agents: /** @type {SurveyRecord[]} */([]),
  selectedAgent: /** @type {SurveyRecord|undefined} */(undefined),

  // Themes
  stylesheetRegistry: new Map(),  // Map<string, ThemeDescriptor>
  generatedThemeAssets: [],       // string[] blob URLs

  // Log
  logs: /** @type {LogEntry[]} */([])
};
```

Minimal event bus from Step‑1 remains:

```js
export const bus = new EventTarget();
export function setState(patch){ Object.assign(store, patch); bus.dispatchEvent(new Event('state')); }
```

---

## D) Adapter: `adapter/pulse-adapter.js`

Bridge the v3 UI to your existing functions and `window.pi`.

```js
import { store, setState } from '../v3.js';
import { log } from '../ui/log.js';

/** Boot Pulse tag and mark readiness. */
export async function bootTag() {
  try {
    // Call your existing boot function if present, otherwise detect window.pi
    if (typeof window.bootPulseTag === 'function') await window.bootPulseTag();
    const ready = typeof window.pi === 'function';
    setState({ tagReady: ready });
    log('tag', 'event', ready ? 'Tag ready' : 'Tag not found');
    return ready;
  } catch (e) {
    setState({ tagReady: false });
    log('tag', 'error', 'Failed to boot tag', { error: String(e) });
    return false;
  }
}

/** Present survey with guard + optional force. */
export function presentSurvey(id, opts = { force:false }) {
  if (!store.tagReady) { setState({ pendingSurveyId: id }); log('tag', 'info', 'Queued survey until tagReady', { id }); return; }
  if (!opts.force && store.lastPresentedId === id) { log('tag','info','Skipping duplicate present',{ id }); return; }
  try {
    window.pi && window.pi('present', id);
    setState({ lastPresentedId: id, agentStatus: 'Presenting' });
    log('tag', 'event', 'Presented survey', { id, force: !!opts.force });
  } catch (e) {
    log('tag', 'error', 'Present failed', { id, error: String(e) });
  }
}

/** Optional: apply identifier before present if your stack requires it. */
export function applyIdentifier(identifier) {
  if (!identifier) return;
  try {
    if (typeof window.applyIdentifier === 'function') window.applyIdentifier(identifier);
    log('tag', 'info', 'Applied identifier', { identifier });
  } catch (e) {
    log('tag', 'warn', 'Failed to apply identifier', { error: String(e) });
  }
}

/** Send trigger/command down to tag. */
export function sendTrigger(...cmd) {
  try {
    window.pi && window.pi('command', cmd);
    log('trigger', 'event', 'Sent trigger', { cmd });
  } catch (e) {
    log('trigger', 'error', 'Trigger failed', { cmd, error: String(e) });
  }
}
```

---

## E) Services

### `services/surveys.js` — load agent list

```js
import { log } from '../ui/log.js';

/** Load surveys from your Sheet/CSV or fall back to inline list. */
export async function loadSurveys() {
  try {
    if (typeof window.populateSurveySelect === 'function') {
      const list = await window.populateSurveySelect(); // returns [{id,label,identifier,backgroundUrl}]
      log('net', 'event', 'Loaded surveys', { count: list?.length ?? 0 });
      return Array.isArray(list) ? list : [];
    }
  } catch(e) {
    log('net', 'error', 'Survey load failed; using fallback', { error: String(e) });
  }
  // Fallback
  return [{ id: 'demo-01', label: 'Demo Agent', backgroundUrl: 'https://example.com' }];
}
```

### `services/themes.js` — curated + generated

```js
import { store } from '../v3.js';
import { log } from '../ui/log.js';

/** Apply curated theme by id (injected <link>). */
export function applyThemeByHref(id, label, href) {
  const link = document.createElement('link');
  link.rel = 'stylesheet';
  link.href = href;
  link.dataset.themeId = id;
  document.head.appendChild(link);
  store.stylesheetRegistry.set(id, { id, label, origin: 'example', href });
  log('theme', 'event', 'Applied curated theme', { id, label });
}

/** Remove applied theme by id. */
export function removeTheme(id) {
  const link = document.head.querySelector(`link[data-theme-id="${id}"]`);
  if (link) link.remove();
  store.stylesheetRegistry.delete(id);
  log('theme', 'event', 'Removed theme', { id });
}

/** Generate themes from a URL using your existing generator, then build blob URLs. */
export async function generateFromUrl(url) {
  try {
    // Cleanup previous blobs
    for (const blobUrl of store.generatedThemeAssets) URL.revokeObjectURL(blobUrl);
    store.generatedThemeAssets.length = 0;

    if (typeof window.generateThemesFromUrl === 'function') {
      const cssList = await window.generateThemesFromUrl(url); // string[] CSS
      const descriptors = cssList.map((css, i) => {
        const blob = new Blob([css], { type: 'text/css' });
        const blobUrl = URL.createObjectURL(blob);
        store.generatedThemeAssets.push(blobUrl);
        return { id: `gen-${i+1}`, label: `Suggestion ${i+1}`, origin: 'generated', blobUrl };
      });
      log('theme','event','Generated themes',{ count: descriptors.length });
      return descriptors;
    }
  } catch(e) {
    log('theme','error','Generation failed',{ error: String(e) });
  }
  return [];
}

/** Apply a generated theme (blob link). */
export function applyGeneratedTheme(theme) {
  const id = theme.id;
  // Remove any prior link for this id
  const prior = document.head.querySelector(`link[data-theme-id="${id}"]`);
  if (prior) prior.remove();

  const link = document.createElement('link');
  link.rel = 'stylesheet';
  link.href = theme.blobUrl;
  link.dataset.themeId = id;
  document.head.appendChild(link);
  store.stylesheetRegistry.set(id, theme);
  log('theme','event','Applied generated theme',{ id });
}
```

---

## F) UI Log: `ui/log.js`

```js
import { store, bus } from '../v3.js';

/** Append a log entry and notify listeners. */
export function log(source, level, message, data) {
  store.logs.push({ ts: Date.now(), source, level, message, data });
  bus.dispatchEvent(new Event('log'));
}

/** Utility to render the log list into a container. */
export function renderLog(container) {
  container.innerHTML = store.logs.slice(-200).map(entry => {
    const time = new Date(entry.ts).toLocaleTimeString();
    return `<div class="pi-log-line" data-level="${entry.level}" data-source="${entry.source}">
      <span class="pi-log-time">${time}</span>
      <span class="pi-log-src">${entry.source}</span>
      <span class="pi-log-msg">${entry.message}</span>
    </div>`;
  }).join('');
}
```

---

## G) Component wiring (what changes from Step‑1)

### 1) Preview Toolbar
- **URL:** on change, set iframe `src`. Keep existing Step‑1 behavior.
- **Device:** set iframe width preset. Keep as Step‑1.
- **Placement (BR/BL/TR/TL):** still update local `store.placement`. If your tag supports placement via config, also write to that config (optional).
- **Safe area/Reload:** same as Step‑1.

### 2) Agent Section
- **Select agent (combobox):**
  1) On first render, populate options from `loadSurveys()`.
  2) On select, call `applyIdentifier(agent.identifier)` (if present).
  3) If `agent.backgroundUrl`, load it into the preview iframe.
  4) If `store.tagReady` → `presentSurvey(agent.id)`, else set `pendingSurveyId`.
- **Launch Agent (primary):** `presentSurvey(selected.id, { force:true })`.
- **Placement/Variant:** placement mirrors toolbar; variant is a UI toggle unless your tag supports it.

### 3) Appearance Section
- **Manual (curated):** applying preset calls `applyThemeByHref(id,label,href)` and updates “Applied styles” list. Removing calls `removeTheme(id)`.
- **Auto (from URL):**
  1) Click “Generate theme” → `generateFromUrl(themeSourceUrl)`
  2) Render returned suggestions (max 4) into the grid.
  3) Auto‑apply first suggestion via `applyGeneratedTheme(theme)`; clicking others switches the applied one.

### 4) Triggers Section
Map buttons to:
- **Present now:** `presentSurvey(selected.id, { force:true })`
- **Exit‑intent / 60% scroll / 10s idle / Rage click:** `sendTrigger(...cmd)` where `cmd` comes from your `TRIGGER_CONFIG` (e.g., `['simulateExitIntent']`).

### 5) Tools + Log Panel
- **Status badges:**
  - **Tag:** shows `Ready` after `bootTag()` sets `tagReady=true`; otherwise `Not found`.
  - **Agent:** set to `Presenting` immediately after `presentSurvey`; return to `Idle` on “Reset demo” or when your UI detects closure (if a close event exists).
- **Show event log:** renders `store.logs` via `renderLog(container)`.
- **Reset demo:** clears `pendingSurveyId`, `selectedAgent`, removes all theme links, empties `stylesheetRegistry`, sets `agentStatus='Idle'`, resets placement to default, and reloads the iframe URL.

---

## H) Boot sequence (init)

```js
import { setState, store, bus } from './v3.js';
import { log } from './ui/log.js';
import { loadSurveys } from './services/surveys.js';
import { bootTag, presentSurvey } from './adapter/pulse-adapter.js';

async function initV3() {
  log('ui','event','Initializing v3 preview');
  // 1) Load agents
  const agents = await loadSurveys();
  setState({ agents });

  // 2) Boot tag
  const ready = await bootTag();

  // 3) If there was a pending selection while tag booted, present it
  if (ready && store.pendingSurveyId) {
    presentSurvey(store.pendingSurveyId);
    setState({ pendingSurveyId: undefined });
  }
}
document.addEventListener('DOMContentLoaded', initV3);
```

Mermaid overview:

```mermaid
flowchart TD
  A[DOMContentLoaded] --> B[loadSurveys()]
  B --> C[bootTag()]
  C -->|tagReady| D{pendingSurveyId?}
  D -- yes --> E[presentSurvey(pendingSurveyId)]
  D -- no  --> F[Idle]
```

---

## I) DOM IDs (to make Cursor wiring deterministic)

Use these IDs from Step‑1:

- **Preview toolbar:** `#previewUrl` · `#deviceDesktop|#deviceTablet|#deviceMobile` · `#placementBR|#placementBL|#placementTR|#placementTL` · `#safeArea` · `#reload`
- **Preview iframe:** `#pi-v3-frame`
- **Agent section:** `#agentSelect` · `#launchAgent` · `#agentPlacement` · `#agentVariant` · `#codeSnippet`
- **Appearance:** `#themeMode` · `#themeSourceUrl` · `#generateTheme` · `#generatedThemes` · `#themePreset` · `#brandColor` · `#cornerRadius` · `#density`
- **Triggers:** `#triggerPresent` · `#triggerExit` · `#triggerScroll` · `#triggerTimer` · `#triggerRage`
- **Examples:** `#industry` · `#example`
- **Tools:** `#tagStatus` · `#agentStatus` · `#showLog` · `#resetDemo`
- **Log panel container:** `#logPanel`

> If your Step‑1 IDs differ, keep a one‑time mapping in v3.js rather than renaming HTML during Step‑2.

---

## J) Edge cases & error handling

- **CSV/Sheet offline:** show a non‑blocking inline message (“Using fallback demos.”) and populate a single demo agent.
- **Preview URL CORS:** if iframe refuses to load, keep controls enabled and show a banner: “Previewed site refused to load (CORS). Try another URL.”
- **Theme regeneration:** always revoke previous `blob:` URLs before creating new ones (avoid leaks). Log “Revoked N generated assets.”
- **Duplicate present:** guard by `lastPresentedId` unless `force:true`.
- **Missing `window.pi`:** `bootTag()` marks tag as not found; status badge shows “Not found” and “Present now” still updates UI state without hard‑failing.

---

## K) Acceptance criteria (Step‑2)

1. Selecting an agent **applies identifier**, **loads background URL** (when present), and **presents** as soon as `tagReady` is true.
2. **Generate theme** returns 1–4 suggestions, **auto‑applies the first**, and revokes any prior generated assets.
3. **Applied styles** list reflects the `stylesheetRegistry` and removing an item unloads its `<link>`.
4. **Trigger buttons** call real `window.pi('command', …)` via `sendTrigger(...)`.
5. **Badges** reflect live status: Tag = Ready/Not found, Agent = Presenting/Idle.
6. **Event log** records init, tag ready, present, theme apply/remove, trigger send, and errors.
7. No toasts or external telemetry yet (reserved for Step‑3).

---

## L) Recommended implementation order

1) Create `ui/log.js` and wire `log()` into Step‑1 buttons to confirm plumbing.  
2) Build `adapter/pulse-adapter.js` with `bootTag`, `presentSurvey`, `applyIdentifier`, `sendTrigger`.  
3) Implement `services/surveys.js`, render agents in `#agentSelect`, verify background URL loads.  
4) Hook Agent section events (select / launch) and verify `pending` → `present` flow.  
5) Implement curated theme apply/remove; verify applied list.  
6) Implement generation from URL; verify suggestions + revocation.  
7) Wire trigger buttons to `sendTrigger(...)`.  
8) Final pass: status badges, reset behavior, and log panel rendering.
