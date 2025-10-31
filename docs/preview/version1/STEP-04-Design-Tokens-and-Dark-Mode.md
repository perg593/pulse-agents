# Pulse Insights — Demo Studio
## Step 4: Design Tokens, Theming & Dark Mode (v3)

**Goal:** unify the visual system across v3, enable light/dark themes, and wire the “Quick knobs” (brand color, radius, density) to live tokens. No IA changes. No business logic changes.

- ✅ Introduce a token layer (CSS custom properties) and component styles that consume tokens.
- ✅ Provide light/dark palettes and an API to switch modes or follow system.
- ✅ Map Quick‑knobs → tokens: `--pi-brand`, `--pi-radius`, `data-density`.
- ✅ Style core components (buttons, badges, inputs, chips, accordion, toasts) via tokens.
- 🚫 Do not alter adapter/services logic; only visual layer.

---

## A) Files (adds to v3)

```
preview/v3/
  theme/
    tokens.css       # NEW: the source of truth for variables
    theme-dark.css   # NEW: dark palette (default)
    theme-light.css  # NEW: light palette (overrides)
  ui/
    theme.js         # NEW: tiny theming API (mode + knobs)
# Include these after v3.css so tokens win.
```

In `index.html`, load in this order:
```html
<link rel="stylesheet" href="./v3.css">
<link rel="stylesheet" href="./theme/tokens.css">
<link rel="stylesheet" href="./theme/theme-dark.css">   <!-- default -->
<!-- theme-light.css is applied via a class; see section D -->
```

---

## B) Token set (authoritative)

### Core tokens (`theme/tokens.css`)
```css
/* Pulse v3 — token root */
.pi-v3 {
  /* Brand & semantic */
  --pi-brand: #7c5cff;            /* Quick knob */
  --pi-success: #22c55e;
  --pi-warning: #f59e0b;
  --pi-danger:  #ef4444;
  --pi-info:    #3b82f6;

  /* Neutrals (filled in by theme-light/dark) */
  --pi-color-bg:        #0f1115;
  --pi-color-surface:   #161a22;
  --pi-color-surface-2: #1c2230;
  --pi-color-border:    #2a2f3a;
  --pi-color-text:      #e7eaf0;
  --pi-color-muted:     #a7adbb;

  /* Typography */
  --pi-font: Inter, ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, "Apple Color Emoji", "Segoe UI Emoji";
  --pi-font-size: 16px;
  --pi-line: 1.5;

  /* Spacing scale */
  --pi-space-1: 4px;
  --pi-space-2: 8px;
  --pi-space-3: 12px;
  --pi-space-4: 16px;
  --pi-space-5: 24px;
  --pi-space-6: 32px;
  --pi-space-7: 48px;

  /* Shape & density (Quick knobs) */
  --pi-radius: 8px;              /* Quick knob: 0–16px */
  --pi-density: 0;               /* -1 compact, 0 comfortable, +1 cozy */

  /* Effects */
  --pi-ring: color-mix(in srgb, var(--pi-brand), white 22%);
  --pi-shadow-1: 0 1px 2px rgba(0,0,0,.2);
  --pi-shadow-2: 0 4px 12px rgba(0,0,0,.25);
  --pi-trans-fast: .12s ease;
  --pi-trans: .18s ease;

  /* Z stack */
  --pi-z-toast: 9999;
  --pi-z-overlay: 999;
}
```

### Dark palette (`theme/theme-dark.css`)
```css
/* Dark is default; these mirror tokens.css initial values */
.pi-v3 {
  --pi-color-bg:        #0f1115;
  --pi-color-surface:   #161a22;
  --pi-color-surface-2: #1c2230;
  --pi-color-border:    #2a2f3a;
  --pi-color-text:      #e7eaf0;
  --pi-color-muted:     #a7adbb;
}
```

### Light palette (`theme/theme-light.css`)
```css
/* Apply by adding .is-light on the .pi-v3 root */
.pi-v3.is-light {
  --pi-color-bg:        #ffffff;
  --pi-color-surface:   #f6f7f9;
  --pi-color-surface-2: #eef1f6;
  --pi-color-border:    #d9dee7;
  --pi-color-text:      #111827;
  --pi-color-muted:     #6b7280;
}
```

### Density mapping (global)
```css
/* Cozier spacing */
.pi-v3[data-density="1"] {
  --pi-space-2: 10px;
  --pi-space-3: 14px;
}
/* Tighter spacing */
.pi-v3[data-density="-1"] {
  --pi-space-2: 6px;
  --pi-space-3: 10px;
}
```

---

## C) Base element resets (append to v3.css)

```css
.pi-v3, .pi-v3 * { box-sizing: border-box; }
.pi-v3 {
  background: var(--pi-color-bg);
  color: var(--pi-color-text);
  font: var(--pi-font-size)/var(--pi-line) var(--pi-font);
}
.pi-v3 a { color: color-mix(in srgb, var(--pi-brand), var(--pi-color-text) 10%); text-decoration: none; }
.pi-v3 a:hover { text-decoration: underline; }
.pi-v3 .pi-input, .pi-v3 .pi-select, .pi-v3 .pi-textarea {
  background: var(--pi-color-surface);
  color: var(--pi-color-text);
  border: 1px solid var(--pi-color-border);
  border-radius: var(--pi-radius);
  padding: 10px 12px;
}
.pi-v3 .pi-input:focus, .pi-v3 .pi-select:focus, .pi-v3 .pi-textarea:focus {
  outline: 2px solid var(--pi-ring);
  outline-offset: 2px;
}
```

---

## D) Component styling via tokens (append to v3.css)

### Buttons
```css
.pi-v3 .pi-btn {
  border: 1px solid var(--pi-color-border);
  border-radius: var(--pi-radius);
  padding: calc(var(--pi-space-2) + 2px) var(--pi-space-4);
  background: var(--pi-color-surface);
  color: var(--pi-color-text);
  box-shadow: var(--pi-shadow-1);
  cursor: pointer;
  transition: transform var(--pi-trans), background var(--pi-trans);
}
.pi-v3 .pi-btn:hover { transform: translateY(-1px); }
.pi-v3 .pi-btn:active { transform: translateY(0); }
.pi-v3 .pi-btn:focus-visible { outline: 2px solid var(--pi-ring); outline-offset: 2px; }

.pi-v3 .pi-btn--primary {
  background: var(--pi-brand);
  color: white;
  border-color: transparent;
}
.pi-v3 .pi-btn--danger {
  background: color-mix(in srgb, var(--pi-danger), transparent 15%);
  color: white;
  border-color: transparent;
}
.pi-v3 .pi-btn--ghost {
  background: transparent;
}
```

### Badges
```css
.pi-v3 .pi-badge {
  display: inline-flex; align-items: center; gap: 6px;
  border: 1px solid var(--pi-color-border);
  border-radius: 999px;
  padding: 2px 8px;
  font-size: 12px;
}
.pi-v3 .pi-badge--green { background: color-mix(in srgb, var(--pi-success), transparent 85%); color: var(--pi-success); }
.pi-v3 .pi-badge--red   { background: color-mix(in srgb, var(--pi-danger),  transparent 85%); color: var(--pi-danger); }
.pi-v3 .pi-badge--indigo{ background: color-mix(in srgb, var(--pi-brand),   transparent 85%); color: var(--pi-brand); }
```

### Chips (e.g., Applied styles)
```css
.pi-v3 .pi-chip {
  display:inline-flex; align-items:center; gap:8px;
  background: var(--pi-color-surface);
  border: 1px solid var(--pi-color-border);
  border-radius: var(--pi-radius);
  padding: 6px 10px;
}
.pi-v3 .pi-chip button { border: 0; background: transparent; color: inherit; cursor: pointer; }
```

### Accordion (left rail)
```css
.pi-v3 .pi-accordion__section { border-bottom: 1px solid var(--pi-color-border); }
.pi-v3 .pi-accordion__header {
  display:flex; align-items:center; justify-content:space-between;
  padding: var(--pi-space-3) var(--pi-space-4);
  background: var(--pi-color-surface);
  cursor: pointer;
}
.pi-v3 .pi-accordion__content { padding: var(--pi-space-4); background: var(--pi-color-surface-2); }
```

### Toasts (use tokens; Step‑3 already added structure)
```css
.pi-v3 #pi-v3-toasts { z-index: var(--pi-z-toast); }
.pi-v3 .pi-toast {
  background: var(--pi-color-surface);
  color: var(--pi-color-text);
  border: 1px solid var(--pi-color-border);
  border-radius: var(--pi-radius);
  box-shadow: var(--pi-shadow-2);
}
.pi-v3 .pi-toast--success { border-color: color-mix(in srgb, var(--pi-success), transparent 70%); }
.pi-v3 .pi-toast--warn    { border-color: color-mix(in srgb, var(--pi-warning), transparent 70%); }
.pi-v3 .pi-toast--error   { border-color: color-mix(in srgb, var(--pi-danger),  transparent 70%); }
```

---

## E) Theme API (ui/theme.js)

```js
// v3 theming API
export const Theme = {
  setMode(mode /* 'dark'|'light'|'auto' */) {
    const root = document.querySelector('.pi-v3');
    if (!root) return;
    root.classList.remove('is-light', 'force-dark');
    if (mode === 'light') root.classList.add('is-light');
    if (mode === 'dark') root.classList.add('force-dark');
    if (mode === 'auto') {
      // remove both; rely on prefers-color-scheme
      const mql = window.matchMedia('(prefers-color-scheme: light)');
      root.classList.toggle('is-light', mql.matches);
    }
    try { localStorage.setItem('pi-v3-theme-mode', mode); } catch {}
  },

  applyQuickKnobs({ brand, radius, density } = {}) {
    const root = document.querySelector('.pi-v3');
    if (!root) return;
    if (brand)  root.style.setProperty('--pi-brand', brand);
    if (radius != null) root.style.setProperty('--pi-radius', `${radius}px`);
    if (density != null) root.setAttribute('data-density', String(density));
  },

  initFromStorage() {
    const root = document.querySelector('.pi-v3');
    if (!root) return;
    try {
      const mode = localStorage.getItem('pi-v3-theme-mode');
      if (mode) this.setMode(mode);
    } catch {}
  }
};
```

**Hook Quick‑knobs (Step‑1 controls)**
- Brand color picker → `Theme.applyQuickKnobs({ brand: value })`
- Corner radius range → `Theme.applyQuickKnobs({ radius: value })`
- Density select → map Cozy/Comfortable/Compact → `1 / 0 / -1`

**Optional auto mode at boot**
```js
import { Theme } from './ui/theme.js';
document.addEventListener('DOMContentLoaded', () => Theme.initFromStorage());
```

---

## F) Accessibility & motion

```css
/* Focus visibility — unify across controls */
.pi-v3 :is(button, [role="button"], input, select, textarea):focus-visible {
  outline: 2px solid var(--pi-ring);
  outline-offset: 2px;
}

/* Reduced motion */
@media (prefers-reduced-motion: reduce) {
  .pi-v3 * { transition: none !important; animation: none !important; }
}
```

- Maintain **AA contrast** for text and interactive elements (brand on dark surfaces can use `color-mix` on hover/focus to ensure visibility).
- Primary click targets ≥ 40×40 px.

---

## G) Light/dark usage patterns

- Default **dark**: only `tokens.css` + `theme-dark.css` are required.
- **Light** mode: add `.is-light` on `.pi-v3` (manual switch) or call `Theme.setMode('light')`.
- **Auto**: call `Theme.setMode('auto')`; it follows system on load.

Fallbacks:
- Old browsers without `color-mix` will still see correct base colors; only subtle border shades differ.

---

## H) “No hard‑coded color” audit (quick checklist)

- Buttons, inputs, accordion, chips, toasts must not declare raw `#hex` other than in tokens.
- Borders use `--pi-color-border`.
- Backgrounds use `--pi-color-surface` / `--pi-color-surface-2`.
- Brand accents reference `--pi-brand` only.
- Shadows use `--pi-shadow-*` tokens.

---

## I) Acceptance criteria (Step‑4)

1. All v3 components consume **token variables**; removing `theme/*.css` visibly breaks colors (by design).
2. **Quick‑knobs** update live: brand color, corner radius, density.
3. **Light/dark** can be toggled via `Theme.setMode('light'|'dark'|'auto')` and persisted.
4. **Toasts, buttons, badges, inputs, chips, accordion** render correctly in both light and dark.
5. Focus ring is visible and consistent; reduced‑motion preference respected.
6. No console errors; CSS validates (no unknown custom properties).

---

## J) Suggested PR order

1) Add `tokens.css`, `theme-dark.css`, `theme-light.css`; wire imports in `index.html`.  
2) Port buttons, inputs, badges, chips, accordion, toasts to tokens.  
3) Implement `ui/theme.js` and connect Quick‑knobs to `Theme.applyQuickKnobs(...)`.  
4) Add a small theme toggle in Tools (optional): “Appearance: Dark | Light | Auto”.  
5) QA in both themes + densities; verify Step‑1 acceptance still passes.
