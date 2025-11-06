# Phase‑B Step‑1 — Routing & Overlays (Ephemeral `demo_for`)

**HTML (no breaking changes)**
```html
<div id="canvas">
  <iframe id="hostFrame" title="Host Page" src="https://pulseinsights.com/agents" referrerpolicy="no-referrer"></iframe>
  <div id="playerLayer"></div> <!-- the bridge mounts its iframe here -->
</div>

<div id="overlay-demo-library" hidden></div>
<div id="overlay-behavior-lab" hidden></div>
```

**Router utilities — `preview/basic/js/router.js`**
```js
export const params = () => new URLSearchParams(location.search);
export const has = (k) => params().has(k);
export const get = (k) => params().get(k);
export function push(k, v) { const p = params(); p.set(k, v); history.pushState({}, '', location.pathname + '?' + p + location.hash); }
export function replaceWithout(k) { const p = params(); p.delete(k); const q = p.toString(); history.replaceState({}, '', location.pathname + (q ? '?' + q : '') + location.hash); }
```

**Demo Library overlay — `preview/basic/js/overlays/demoLibrary.js`**
```js
import { push } from '../router.js';
import { emit } from '../events.js';

export function showDemoLibrary() {
  const el = document.getElementById('overlay-demo-library');
  el.hidden = false;
  el.innerHTML = `<div class="panel"><h3>Select a demo</h3><ul id="demoList"></ul></div>`;
  const demos = ['retail-exit','saas-trial','publisher-engagement']; // replace with dynamic later
  const ul = el.querySelector('#demoList');
  for (const d of demos) {
    const li = document.createElement('li');
    const btn = document.createElement('button'); btn.textContent = d;
    btn.addEventListener('click', () => { push('demo_for', d); emit('ui:demo-selected', { demoFor: d }); el.hidden = true; });
    li.appendChild(btn); ul.appendChild(li);
  }
}
```

**Behavior Lab overlay (hidden by default) — `preview/basic/js/overlays/behaviorLab.js`**
```js
export function preloadBehaviorLab(config) {
  const el = document.getElementById('overlay-behavior-lab');
  el.dataset.demoFor = config.demoFor || '';
  el.dataset.surveys = JSON.stringify(config.surveys || []);
  el.dataset.rules = JSON.stringify(config.rules || []);
  // stays hidden (spec); add a dev hotkey toggle later if needed
}
```

**App bootstrap — `preview/basic/js/app.js`**
```js
import { has, get, replaceWithout } from './router.js';
import { on, emit } from './events.js';
import { showDemoLibrary } from './overlays/demoLibrary.js';
import { preloadBehaviorLab } from './overlays/behaviorLab.js';
import { loadDemoConfig } from './catalog/demoCatalog.js';
import { startScrollDepth } from './behaviors/scrollDepth.js';
import { attachResponses } from './responses.js';
import { createSurveyBridge } from '../../app/survey/bridge.js';

function ensureHost() {
  const host = document.getElementById('hostFrame');
  if (host) host.src = 'https://pulseinsights.com/agents';
}

function ensureBridge() {
  const container = document.getElementById('playerLayer');
  const bridge = createSurveyBridge({ container }, { useProtocolV1: true, compatImplicitAck: false });
  bridge.load({ account: 'PI-TEST', host: 'survey.pulseinsights.com' });
  return bridge;
}

export async function boot() {
  ensureHost();
  const bridge = ensureBridge();

  on('ui:demo-selected', async ({ detail:{ demoFor } }) => {
    const config = await loadDemoConfig(demoFor);
    preloadBehaviorLab({ demoFor, ...config });
    emit('catalog:loaded', { demoFor, config });
  });

  if (!has('demo_for')) {
    showDemoLibrary();
  } else {
    const demoFor = get('demo_for');
    const config = await loadDemoConfig(demoFor);
    preloadBehaviorLab({ demoFor, ...config });
    emit('catalog:loaded', { demoFor, config });
    replaceWithout('demo_for'); // ephemeral
  }

  startScrollDepth({ logEvery: 10 });
  attachResponses({ bridge }); // non‑breaking; controller added in a later step
}
```

**Result:** First load shows Demo Library if `demo_for` absent; selecting a demo adds the param, preloads data, and removes the param on next load. Behavior Lab remains hidden.
