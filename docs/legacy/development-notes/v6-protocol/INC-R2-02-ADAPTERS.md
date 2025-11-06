# Adapters — Bus + Logger Proxy (No Duplicate Systems)

We won’t introduce a competing event system. Instead, we **wrap your existing functions** so they also emit to the shared bus.

## `preview/basic/lib/behaviorBus.js`
```js
export const bus = new EventTarget();
export const emit = (type, detail) => bus.dispatchEvent(new CustomEvent(type, { detail }));
export const on = (type, fn) => (bus.addEventListener(type, fn), () => bus.removeEventListener(type, fn));

/** Optional: pipe your existing logBehavior into both console + bus */
export function installBehaviorLogProxy({ logBehavior }) {
  if (typeof logBehavior !== 'function') return () => {};
  const proxied = (kind, payload) => {
    try { console.debug('[behavior]', kind, payload || ''); } catch {}
    emit(`behavior:log`, { kind, payload });
    return logBehavior(kind, payload);
  };
  return proxied;
}
```

## Wiring (in `preview.js`)
```js
import { bus, emit, on, installBehaviorLogProxy } from './lib/behaviorBus.js';

// If you already had function logBehavior(kind, payload) { ... }
const logBehavior = window.logBehavior || ((k,p) => console.debug('[behavior]', k, p));
const logBehaviorProxied = installBehaviorLogProxy({ logBehavior });

// Option A: replace your references to logBehavior with logBehaviorProxied.
// Option B: keep logBehavior, but from now on call both:
function logB(kind, payload) { logBehaviorProxied(kind, payload); } // convenience
```
