# Module: `behaviorBus.js` — Simple EventTarget Bus

```js
export const bus = new EventTarget();
export const emit = (type, detail) => bus.dispatchEvent(new CustomEvent(type, { detail }));
export const on = (type, fn) => (bus.addEventListener(type, fn), () => bus.removeEventListener(type, fn));
window.__PI_BEHAVIOR_BUS__ = bus; // optional
```
