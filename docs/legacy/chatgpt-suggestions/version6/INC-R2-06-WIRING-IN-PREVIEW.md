# Minimal Wiring — Drop‑in to `preview/basic/preview.js`

**Imports (top)**
```js
import { bus, emit, on, installBehaviorLogProxy } from './lib/behaviorBus.js';
import { createScrollDepthEngine } from './lib/scrollDepthTarget.js';
import { RulesStore } from './lib/rulesStore.js';
import { PresentationController } from './lib/presentationController.js';
import { attachResponses } from './lib/responsesDriver.js';
```

**Logger proxy (replace your logBehavior usage or wrap)**
```js
const logBehavior = window.logBehavior || ((k,p)=>console.debug('[behavior]',k,p));
const logB = installBehaviorLogProxy({ logBehavior });
```

**After bridge + presentSurvey are ready**
```js
const presenter = new PresentationController({
  present: (id, meta) => (typeof presentSurvey === 'function'
    ? presentSurvey(id, { force: !!meta?.force, allowDuplicate: !!meta?.allowDuplicate, source: meta?.source || 'auto' })
    : bridge.present(id))
}, { manualLockMs: 4000, autoCooldownMs: 10000 });
window.__PI_PRESENTER__ = presenter;
```

**After sheet ingestion (reuse your existing code)**
```js
const store = RulesStore.shared();
store.replaceWith(RulesStore.fromIngestion(existingRows));
bus.dispatchEvent(new CustomEvent('catalog:loaded', { detail: { /* optional */ } }));
```

**Start the scroll engine bound to your stage**
```js
const stage = document.querySelector('#behavior-stage') || document.scrollingElement;
const engine = createScrollDepthEngine({ target: stage, logEvery: 10, bus, log: (s) => logB('scroll', s) });
engine.start();

// When behavior lab overlay is shown (use your existing event/callback):
onBehaviorLabShown?.(() => {
  const fresh = document.querySelector('#behavior-stage');
  if (fresh) engine.retarget(fresh);
});
```

**Attach responses with catch‑up**
```js
attachResponses({ presenter, rules: () => store.all(), bus, getPercent: engine.getPercent });
```

**Manual rail (unchanged)**  
Your rail can continue calling `presentSurvey(id)` as today. Optional: switch to `__PI_PRESENTER__.presentManual(id)` if you want lock/cooldown logs to appear consistently.
