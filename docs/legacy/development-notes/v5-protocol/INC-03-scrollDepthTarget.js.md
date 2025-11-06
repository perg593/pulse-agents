# Module: `scrollDepthTarget.js` — Scroll‑Depth on a Target Element

```js
export function startScrollDepth({ target, logEvery = 10, bus = window.__PI_BEHAVIOR_BUS__, log = true } = {}) {
  const el = target || document.scrollingElement || document.documentElement;
  const fired = new Set(); let ticking = false;
  function percent(el) {
    const top = el.scrollTop;
    const denom = Math.max(1, el.scrollHeight - el.clientHeight);
    return Math.min(100, Math.max(0, Math.round((top / denom) * 100)));
  }
  function onScroll() {
    if (ticking) return; ticking = true;
    requestAnimationFrame(() => {
      ticking = false;
      const p = percent(el);
      const step = Math.floor(p / logEvery) * logEvery;
      if (step > 0 && step <= 100 && !fired.has(step)) {
        fired.add(step);
        if (log) console.log(`[behavior] scroll-depth ${step}%`);
        bus?.dispatchEvent(new CustomEvent('behavior:scroll-depth', { detail: { percent: step } }));
      }
    });
  }
  el.addEventListener('scroll', onScroll, { passive: true });
  window.addEventListener('resize', onScroll);
  onScroll();
  return () => { el.removeEventListener('scroll', onScroll); window.removeEventListener('resize', onScroll); };
}
