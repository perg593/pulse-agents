# Phase‑B Step‑4 — Presentation Controller & Responses (Coexistence)

This adds **priority & cooldown** for behavior‑driven calls **without changing** manual rail flow.

## A) Controller — `preview/basic/js/presentationController.js`
```js
export class PresentationController {
  constructor(bridge, { manualLockMs=4000, autoCooldownMs=10000, now=()=>Date.now(), log=console }={}) {
    this.bridge=bridge; this.manualLockMs=manualLockMs; this.autoCooldownMs=autoCooldownMs; this.now=now; this.log=log;
    this.inFlightSource=null; this.inFlightSurveyId=null; this.lockUntil=0; this.recent=new Map();
  }
  async presentManual(id, meta={}) { const ts=this.now(); this.lockUntil=ts+this.manualLockMs; this.log.info('[present] manual', {id,meta}); return this.#fire('manual', id, meta); }
  async presentAuto(id, meta={}) {
    const ts=this.now();
    if (ts<this.lockUntil || this.inFlightSource==='manual') { this.log.info('[present] auto suppressed:manual-lock',{id,until:this.lockUntil}); return {suppressed:'manual-lock',id,until:this.lockUntil}; }
    const last=this.recent.get(id)||0; if (ts-last<this.autoCooldownMs) { this.log.info('[present] auto suppressed:cooldown',{id,until:last+this.autoCooldownMs}); return {suppressed:'cooldown',id,until:last+this.autoCooldownMs}; }
    return this.#fire('auto', id, meta);
  }
  async #fire(source,id,meta){ const ts=this.now(); this.inFlightSource=source; this.inFlightSurveyId=id;
    try{ const payload=await this.bridge.present(id); this.recent.set(id,ts); this.log.info('[present] fired',{source,id,meta,payload}); return payload; }
    catch(e){ this.log.warn('[present] failed',{source,id,meta,error:e}); throw e; }
    finally{ this.inFlightSource=null; this.inFlightSurveyId=null; }
  }
}
```

## B) Responses — `preview/basic/js/responses.js` (non‑breaking delta)
```js
import { on, emit } from './events.js';

function parseWhen(when) {
  const m=/^scroll\s*(>=)\s*(\d{1,3})$/.exec(when||''); if(!m) return null;
  const val=Math.max(0,Math.min(100,parseInt(m[2],10))); return { op:m[1], val };
}

export function attachResponses({ bridge, presenter }={}) {
  const fired=new Set();
  on('catalog:loaded', ({ detail:{ config } }) => { console.log('[catalog] loaded',config); fired.clear(); });
  on('behavior:scroll-depth', async ({ detail:{ percent } }) => {
    const lab=document.getElementById('overlay-behavior-lab');
    const rules=JSON.parse(lab.dataset.rules||'[]');
    for(const r of rules){
      const key=`${r.when}|${r.do}|${r.arg}`; if(fired.has(key)) continue;
      const c=parseWhen(r.when); if(!c) continue;
      if(c.op==='>=' && percent>=c.val && r.do==='present' && r.arg){
        console.log('[response] present(auto)', r.arg, `@ ${percent}%`);
        try {
          const run = presenter?.presentAuto ? () => presenter.presentAuto(r.arg, { when:r.when, percent }) : () => bridge.present(r.arg);
          await run(); fired.add(key); emit('response:present-fired', { surveyId:r.arg, rule:r, source: presenter?.presentAuto ? 'auto' : 'direct' });
        } catch(e) { console.warn('[response] present failed', r.arg, e); }
      }
    }
  });
}
```

## C) App wiring delta — `preview/basic/js/app.js`
```js
import { PresentationController } from './presentationController.js';
// after ensureBridge():
const presenter = new PresentationController(bridge, { manualLockMs: 4000, autoCooldownMs: 10000 });
window.__PI_PRESENTER__ = presenter; // optional convenience
attachResponses({ bridge, presenter });
```

**Manual rail unchanged:** it can keep calling `bridge.present(id)`. If you later change it to `window.__PI_PRESENTER__.presentManual(id)`, you’ll get consistent logs + lock timing, but it’s optional.
