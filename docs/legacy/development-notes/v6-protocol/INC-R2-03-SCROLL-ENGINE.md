# Scroll Engine — Targeted, Retargetable, Catch‑up

Bind to **your internal scroll stage** and support **retarget** after overlays toggle.

## `preview/basic/lib/scrollDepthTarget.js`
```js
export function createScrollDepthEngine({
  target = null,
  logEvery = 10,
  bus = window.__PI_BEHAVIOR_BUS__,
  log = (msg) => console.debug(msg)
} = {}) {
  let el = target || document.querySelector('#behavior-stage') || document.scrollingElement;
  const fired = new Set();
  let ticking = false;

  function computePercent(node) {
    const top = node ? node.scrollTop : (document.scrollingElement || document.documentElement).scrollTop;
    const denom = Math.max(1, (node?.scrollHeight || 1) - (node?.clientHeight || 1));
    return Math.min(100, Math.max(0, Math.round((top / denom) * 100)));
  }

  function getPercent() { return computePercent(el); }

  function onScroll() {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(() => {
      ticking = false;
      const p = getPercent();
      const step = Math.floor(p / logEvery) * logEvery;
      if (step > 0 && step <= 100 && !fired.has(step)) {
        fired.add(step);
        log(`[behavior] scroll-depth ${step}%`);
        bus?.dispatchEvent(new CustomEvent('behavior:scroll-depth', { detail: { percent: step } }));
      }
    });
  }

  function start() {
    if (!el) return;
    el.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll);
    onScroll(); // prime once
  }

  function stop() {
    if (!el) return;
    el.removeEventListener('scroll', onScroll);
    window.removeEventListener('resize', onScroll);
  }

  function retarget(nextEl) {
    if (nextEl === el || !nextEl) return;
    stop();
    el = nextEl;
    fired.clear(); // treat as new context
    start();
  }

  return { start, stop, retarget, getPercent };
}
```

## Wiring (in `preview.js`)
```js
import { createScrollDepthEngine } from './lib/scrollDepthTarget.js';
const stage = document.querySelector('#behavior-stage') || document.scrollingElement;
const engine = createScrollDepthEngine({ target: stage, logEvery: 10, bus, log: (s) => logB('scroll', s) });
engine.start();

// When Behavior Lab is shown later or stage node attaches, call:
function onBehaviorLabShown() {
  const freshStage = document.querySelector('#behavior-stage');
  if (freshStage) engine.retarget(freshStage);
}
```

**Notes**
- Retarget clears milestone memory so a newly opened stage can re‑emit from 10% upward.
- `getPercent()` is used by the rules driver to **catch‑up** thresholds when rules load after scrolling.
