# Step 1 — Build Scope Addendum (v3 Scaffold)

This addendum narrows Step‑1 to layout + safe, self‑contained interactions only. No business logic, no calls to `window.pi`, and no theme generation yet.

---

## 1) Project location

Create a parallel scaffold:

```
preview/
  basic/               # existing
  v3/
    index.html
    v3.css
    v3.js
    /assets
    /icons
```

The v3 HTML should mount a root container with a namespace class:

```html
<body class="pi-v3">
  <!-- Left rail + preview toolbar + iframe -->
</body>
```

---

## 2) What to wire vs. what to stub

### Wire now (scaffold-only)
- **Preview URL** → loads the preview iframe (`<iframe id="pi-v3-frame">`) with `src` set to the typed URL (fallback to a friendly default).
- **Device toggle** → sets iframe width via CSS classes:
  - Desktop: 1280px, Tablet: 834px, Mobile: 390px.
- **Safe‑area toggle** → toggles a green outline overlay inside the iframe container.
- **Placement (toolbar ↔ Agent section)** → keep a local `store.placement` and move a **ghost agent** box to BR/BL/TR/TL. No real agent calls.

### Stub now (UI only; no external effects)
- **Status badges** → read from a local `store` (default: Tag = “Ready”, Agent = “Idle”). No auto‑detection yet.
- **Triggers** → buttons render and can log to an internal log panel, but do nothing functional.
- **Appearance (Generate theme / Apply preset)** → buttons update UI state (e.g., show a “Suggestions” grid with placeholder chips), but don’t inject CSS.
- **Examples** → selecting options updates a chip (“Applied example: {name}”), no survey/theme swap yet.

---

## 3) Minimal store & events (scaffold only)

```js
// v3.js
const store = {
  url: 'https://example.com',
  device: 'Desktop',       // 'Desktop'|'Tablet'|'Mobile'
  placement: 'BR',         // 'BR'|'BL'|'TR'|'TL'
  safeArea: true,
  tagStatus: 'Ready',      // 'Ready'|'Not found' (stub)
  agentStatus: 'Idle',     // 'Idle'|'Presenting' (stub)
  logs: []
};

const bus = new EventTarget(); // simple pub/sub

function setState(patch) {
  Object.assign(store, patch);
  bus.dispatchEvent(new Event('state'));
}
```

Hook inputs/buttons to `setState(...)`, re-render the small number of things that depend on state:
- iframe `src`
- container classes for device width
- safe‑area overlay visibility
- ghost agent position
- badges text

---

## 4) Ghost agent spec (visual placeholder)

- A simple absolutely‑positioned box inside the preview container:
  - Size: 320×220 on Desktop, 320×200 on Tablet, 320×180 on Mobile.
  - Border: 2px dashed currentColor; color uses `--pi-brand` at 60% opacity.
  - Label: “Agent (ghost)” in the corner.
- Position maps to `store.placement`: Bottom‑right, Bottom‑left, Top‑right, Top‑left.
- Toggling placement in either the toolbar (BR/BL/TR/TL) or Agent section (full names) updates the **same** state.

---

## 5) CSS namespacing & tokens

- Wrap all styles in `.pi-v3`.
- Expose a few tokens now to keep Step‑4 easy later:

```css
.pi-v3 {
  --pi-brand: #7c5cff;
  --pi-radius: 8px;
  --pi-space-2: 8px;
  --pi-space-4: 16px;
}
```

- Primary buttons, badges, chips use these tokens. Avoid hard‑coded colors elsewhere.

---

## 6) Acceptance criteria (Step‑1, Scaffold)

1. v3 renders the new **accordion left rail** and **preview toolbar** exactly per Step‑1 labels.
2. URL field loads the iframe; invalid URLs show a gentle inline message and do not crash.
3. Device toggle resizes the iframe to Desktop/Tablet/Mobile presets.
4. Safe‑area toggle shows/hides a green border overlay around the iframe content area.
5. Placement controls are **bidirectionally synced** and move a visible **ghost agent** box to BR/BL/TR/TL.
6. Status badges display stubbed values from the local store.
7. Triggers/Appearance/Examples render and update UI‑only state (no external effects).
8. All copy matches Step‑1 microcopy.

---

## 7) Later wiring (reserved for Step‑2)

- Replace ghost agent with real `window.pi('present', id)` wiring.
- Replace stub badges with live tag/agent status.
- Connect theme generation and curated theme application.
- Connect trigger buttons to real `window.pi('command', ...)`.
