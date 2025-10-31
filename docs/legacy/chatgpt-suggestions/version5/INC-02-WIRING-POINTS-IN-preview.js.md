# Phase‑B (Incremental) — Wiring Points in `preview/basic/preview.js`

This is a **surgical** integration. We add a few imports and call tiny hooks at the points you already have.

## 1) Imports (top of `preview.js`)
```js
import { bus, on, emit } from './lib/behaviorBus.js';
import { startScrollDepth } from './lib/scrollDepthTarget.js';
import { RulesStore } from './lib/rulesStore.js';
import { PresentationController } from './lib/presentationController.js';
import { attachResponses } from './lib/responsesDriver.js';
```

## 2) After Bridge/rail init
```js
const presenter = new PresentationController({
  present: (id, meta) => {
    if (typeof presentSurvey === 'function') {
      return presentSurvey({ id, force: !!meta?.force, allowDuplicate: !!meta?.allowDuplicate, source: meta?.source || 'auto' });
    }
    return bridge.present(id);
  }
}, { manualLockMs: 4000, autoCooldownMs: 10000 });

window.__PI_PRESENTER__ = presenter; // optional
```

## 3) After ingesting demo data
```js
const rulesStore = RulesStore.shared();
rulesStore.replaceWith(normalizeToRules(existingRowsOrModel));
emit('catalog:loaded', { demoFor, rules: rulesStore.all() });

if (window.EPHEMERAL_DEMO_FOR) {
  const p = new URLSearchParams(location.search); p.delete('demo_for');
  history.replaceState({}, '', location.pathname + (p.toString()? '?' + p : '') + location.hash);
}
```

## 4) Start scroll engine on your internal stage
```js
const stage = document.querySelector('#behavior-stage, .lab-scroll, [data-role="stage"]') || document.scrollingElement;
const stopScroll = startScrollDepth({ target: stage, logEvery: 10, bus });
```

## 5) Drive responses
```js
attachResponses({ presenter, rules: () => RulesStore.shared().all(), bus });
```

## 6) Manual rail
No change required; to unify logs, optionally:
```js
__PI_PRESENTER__.presentManual(id, { source: 'manual-rail' });
```
