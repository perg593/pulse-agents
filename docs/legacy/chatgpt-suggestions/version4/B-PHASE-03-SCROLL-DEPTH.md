# Phase‑B Step‑2 — Scroll‑Depth Engine

**File:** `preview/basic/js/behaviors/scrollDepth.js`

```js
import { emit } from '../events.js';

function percent() {
  const d = document.documentElement, b = document.body;
  const top = window.pageYOffset || d.scrollTop || b.scrollTop || 0;
  const vh = window.innerHeight || d.clientHeight;
  const h  = Math.max(b.scrollHeight, d.scrollHeight, b.offsetHeight, d.offsetHeight, b.clientHeight, d.clientHeight);
  const denom = Math.max(1, h - vh);
  return Math.min(100, Math.max(0, Math.round((top / denom) * 100)));
}

export function startScrollDepth({ logEvery = 10 } = {}) {
  const fired = new Set(); let ticking = false;
  function onScroll() {
    if (ticking) return; ticking = true;
    requestAnimationFrame(() => { ticking = false;
      const p = percent(); const step = Math.floor(p / logEvery) * logEvery;
      if (step > 0 && step <= 100 && !fired.has(step)) {
        fired.add(step);
        console.log(`[behavior] scroll-depth ${step}%`);
        emit('behavior:scroll-depth', { percent: step });
      }
    });
  }
  window.addEventListener('scroll', onScroll, { passive: true });
  window.addEventListener('resize', onScroll);
  onScroll();
  return () => { window.removeEventListener('scroll', onScroll); window.removeEventListener('resize', onScroll); };
}
```

**Spec adherence**
- Only scroll influences auto presentation right now.  
- Logs at 10% increments with a `[behavior]` prefix for easy filtering.
