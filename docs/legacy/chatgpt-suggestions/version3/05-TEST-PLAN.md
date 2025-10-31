# Test Plan — Protocol v1

We test in **three layers** so failures point to the right place quickly.

---

## Layer A — Contract/unit (no browser)

Runner: Jest/Vitest in Node/JSDOM.

**Cases**
1) Handshake: Player sends `hello`; Bridge `init` → `ready` within 2s.
2) Present acks: Bridge sends `present`; receives `status` with same id; Bridge **emits** a `status` event and resolves the Promise.
3) Ack timeout: no reply → Promise rejects with `ack_timeout` in ~1s.
4) Origin rejection: forged message from wrong origin ignored.
5) Heartbeat: one pong OK; two misses → “inactive” event.

**Helpers**
- Fake `postMessage` bus (two EventTargets) to simulate origin separation.
- Message tap to log each v1 message (helps when hangs occur).

---

## Layer B — Tiny browser integration (real iframe, tiny Player)

Runner: Playwright (Chromium). Serve a minimal `player-test.html` that implements v1 superficially.

**Specs**
- `handshake.spec.ts`: mount iframe → `bridge.init` → expect `ready`.
- `present.spec.ts`: `bridge.present` → expect `status.event === 'present-called'`.
- `apply-theme.spec.ts`: apply curated CSS (`href`) and expect ack.
- `trigger.spec.ts`: `exit-intent` trigger acks.

**Config**
```ts
export default {
  timeout: 20000,
  retries: 1,
  use: { headless: true, trace: 'on-first-retry' },
  webServer: { command: 'npx http-server preview/v3 -p 5173 -c-1', port: 5173, timeout: 10000, reuseExistingServer: true }
}
```

---

## Layer C — Full E2E (real Player + Tag)

Few, focused specs:
- `present-happy`: handshake + present + geometry
- `apply-theme-happy`
- `trigger-exit-intent`
- `present-failure`: force Tag error → expect red toast, Bridge `error` event

**Policies**
- Bail after first failing spec.
- Save Playwright trace/screenshot on failure.
- Keep timeouts modest (handshake 5s, ack 3s).

---

## Test utilities (drop-in)

```ts
export async function withWatch<T>(p: Promise<T>, label: string, ms = 1500) {
  const t = setTimeout(() => console.warn('[HANG?]', label), ms);
  try { return await p; } finally { clearTimeout(t); }
}

export function tapV1Messages(label='v1') {
  const seen = new WeakSet();
  window.addEventListener('message', ev => {
    const m = ev.data; if (!m || m.v !== 1 || seen.has(m)) return;
    seen.add(m);
    console.log(`[${label}]`, m.type, m.id, m.payload?.event ?? '');
  });
}
```

---

## CI expectations
- Run Layer A + B on every PR.
- Run Layer C nightly or on protected branches.
- Fail the build if ack rate < 100% or any origin check fails.
