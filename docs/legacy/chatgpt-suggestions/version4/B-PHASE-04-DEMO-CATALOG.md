# Phase‑B Step‑3 — Demo Catalog (Sheets + Fallback)

**File:** `preview/basic/js/catalog/demoCatalog.js`

```js
const FALLBACK_URL = '/preview/basic/data/demo-catalog.json';
const SHEET_CSV_URL = window.__DEMO_SHEET_CSV__;

function parseCsv(text) {
  const [head, ...rows] = text.trim().split('\n').map(r => r.split(','));
  const cols = head.map(h => h.trim());
  return rows.map(r => Object.fromEntries(r.map((v,i)=>[cols[i], (v||'').trim()])));
}

function index(rows) {
  const map = new Map();
  for (const r of rows) {
    const d = r.demo_for;
    const entry = map.get(d) || { surveys: [], rules: [] };
    if (r.survey_id && !entry.surveys.includes(r.survey_id)) entry.surveys.push(r.survey_id);
    if (r.when && r.action) entry.rules.push({ when: r.when, do: r.action, arg: r.arg || r.survey_id });
    map.set(d, entry);
  }
  return (demoFor) => ({ demoFor, ...(map.get(demoFor) || { surveys: [], rules: [] }) });
}

async function fetchCsv(url) {
  const res = await fetch(url, { credentials:'omit' }); if (!res.ok) throw new Error(`sheet ${res.status}`); return res.text();
}

export async function loadDemoConfig(demoFor) {
  let rows = null;
  try { if (SHEET_CSV_URL) rows = parseCsv(await fetchCsv(SHEET_CSV_URL)); } catch (e) { console.warn('[catalog] sheet failed', e); }
  if (!rows) rows = await (await fetch(FALLBACK_URL)).json();
  const get = index(rows); const cfg = get(demoFor);
  if (!cfg.rules.length && cfg.surveys.length) cfg.rules.push({ when:'scroll>=30', do:'present', arg: cfg.surveys[0] });
  return cfg;
}
```

**Fallback JSON example:** `preview/basic/data/demo-catalog.json`
```json
[
  { "demo_for":"retail-exit", "survey_id":"SURVEY_ABC", "when":"scroll>=30", "action":"present", "arg":"SURVEY_ABC" }
]
```
