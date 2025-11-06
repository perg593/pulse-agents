# Rules — Single Store + Load Catch‑up

Normalize your existing ingestion into a stable list the driver can consume, and **catch‑up** if thresholds already passed.

## `preview/basic/lib/rulesStore.js`
```js
export class RulesStore {
  static #inst;
  static shared() { return this.#inst || (this.#inst = new RulesStore()); }
  #rules = [];
  replaceWith(arr = []) { this.#rules = Array.isArray(arr) ? arr.slice() : []; }
  all() { return this.#rules.slice(); }
  static fromIngestion(rows=[]) {
    const out = [];
    for (const r of rows) {
      const when = r.when || r.rule || '';
      const action = r.action || r.do || 'present';
      const arg = r.arg || r.survey_id;
      if (when && action === 'present' && arg) out.push({ when, do: 'present', arg });
    }
    return out;
  }
}
```

## `preview/basic/lib/responsesDriver.js` (catch‑up aware)
```js
function parseWhen(when) {
  const m = /^scroll\\s*(>=)\\s*(\\d{1,3})$/.exec(when || '');
  if (!m) return null;
  const val = Math.max(0, Math.min(100, parseInt(m[2], 10)));
  return { op: m[1], val };
}

export function attachResponses({ presenter, rules, bus, getPercent }) {
  const fired = new Set();

  function evalAll(reason = 'event', percent = 0) {
    const list = (typeof rules === 'function' ? rules() : []) || [];
    for (const r of list) {
      const key = `${r.when}|${r.do}|${r.arg}`;
      if (fired.has(key)) continue;
      const c = parseWhen(r.when); if (!c) continue;
      if (c.op === '>=' && percent >= c.val && r.do === 'present' && r.arg) {
        presenter.presentAuto(r.arg, { when: r.when, percent, reason }).then(() => fired.add(key)).catch(() => {});
      }
    }
  }

  bus.addEventListener('catalog:loaded', () => {
    fired.clear();
    const p = typeof getPercent === 'function' ? getPercent() : 0;
    evalAll('catalog-loaded', p); // 🔁 catch‑up at load
  });

  bus.addEventListener('behavior:scroll-depth', (ev) => {
    const p = ev.detail?.percent ?? 0;
    evalAll('scroll', p);
  });
}
```

## Wiring (in `preview.js`)
```js
import { RulesStore } from './lib/rulesStore.js';
import { attachResponses } from './lib/responsesDriver.js';

const store = RulesStore.shared();
store.replaceWith(RulesStore.fromIngestion(yourExistingIngestionRows));
attachResponses({ presenter, rules: () => store.all(), bus, getPercent: engine.getPercent });
```
