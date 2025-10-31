# Phase‑B Step‑5 — Tests & QA

## A) Unit — Controller behavior
`preview/tests/presentationController.test.mjs`
```js
import { strict as assert } from 'node:assert';
import { PresentationController } from '../../basic/js/presentationController.js';

function mockBridge(){ const calls=[]; return { calls, present:(id)=>{ calls.push(id); return Promise.resolve({ok:true}); } }; }

test('manual locks out auto', async () => {
  const b=mockBridge(); let t=1000; const pc=new PresentationController(b,{manualLockMs:4000,autoCooldownMs:10000,now:()=>t});
  await pc.presentManual('M1'); t+=1000; const res=await pc.presentAuto('A1');
  assert.equal(res.suppressed,'manual-lock'); assert.deepEqual(b.calls,['M1']);
});

test('auto cooldown', async () => {
  const b=mockBridge(); let t=1000; const pc=new PresentationController(b,{manualLockMs:0,autoCooldownMs:10000,now:()=>t});
  await pc.presentAuto('A1'); t+=2000; const res=await pc.presentAuto('A1');
  assert.equal(res.suppressed,'cooldown'); assert.deepEqual(b.calls,['A1']);
});
```

## B) Unit — Responses uses controller when present
```js
import { strict as assert } from 'node:assert';
import { attachResponses } from '../../basic/js/responses.js';
import { emit } from '../../basic/js/events.js';

test('responses -> presenter.presentAuto', async () => {
  const lab=document.createElement('div'); lab.id='overlay-behavior-lab';
  lab.dataset.rules=JSON.stringify([{ when:'scroll>=30', do:'present', arg:'S-1' }]); document.body.appendChild(lab);
  let called=null; const presenter={ presentAuto:(id)=>{ called=id; return Promise.resolve({ok:true}); } };
  attachResponses({ bridge:{ present:()=>{} }, presenter });
  emit('behavior:scroll-depth', { percent:30 }); await new Promise(r=>setTimeout(r,0)); assert.equal(called,'S-1');
});
```

## C) Manual QA
1) Load `/preview/basic/` → **Agents** loads; **Demo Library** visible.  
2) Pick a demo → URL shows `?demo_for=…`; Behavior Lab stays hidden.  
3) Scroll → Console prints `[behavior] scroll-depth …`.  
4) At threshold (e.g., 30%) → `[response] present(auto) …` and wrapper prints `present-called`.  
5) Click a rail button repeatedly → manual fires immediately; auto triggers **do not** preempt during the lock window.  
6) Reload → URL is clean (no `demo_for`).  
