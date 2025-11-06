# Module: `responsesDriver.js` — Behavior → Rule Eval → Presentation

```js
function parseWhen(when) {
  const m = /^scroll\s*(>=)\s*(\d{1,3})$/.exec(when || '');
  if (!m) return null;
  const val = Math.max(0, Math.min(100, parseInt(m[2], 10)));
  return { op: m[1], val };
}
export function attachResponses({ presenter, rules, bus = window.__PI_BEHAVIOR_BUS__ } = {}) {
  const fired = new Set();
  bus.addEventListener('catalog:loaded', () => fired.clear());
  bus.addEventListener('behavior:scroll-depth', async (ev) => {
    const percent = ev.detail?.percent ?? 0;
    const list = (typeof rules === 'function' ? rules() : []) || [];
    for (const r of list) {
      const key = `${r.when}|${r.do}|${r.arg}`;
      if (fired.has(key)) continue;
      const c = parseWhen(r.when); if (!c) continue;
      if (c.op === '>=' && percent >= c.val && r.do === 'present' && r.arg) {
        try { await presenter.presentAuto(r.arg, { when: r.when, percent }); fired.add(key); }
        catch (e) {}
      }
    }
  });
}
