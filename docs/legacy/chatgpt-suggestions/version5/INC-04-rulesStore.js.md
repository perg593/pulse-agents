# Module: `rulesStore.js` — Single Source of Truth for Rules

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
