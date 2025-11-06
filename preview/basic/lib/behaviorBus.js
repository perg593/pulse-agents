export const bus = new EventTarget();

export const emit = (type, detail) => bus.dispatchEvent(new CustomEvent(type, { detail }));

export const on = (type, fn) => {
  bus.addEventListener(type, fn);
  return () => bus.removeEventListener(type, fn);
};

/**
 * Wrap the existing logBehavior function so we have a single pipe for logs.
 * Returns a proxied logger that continues to call the original implementation.
 */
export function installBehaviorLogProxy({ logBehavior } = {}) {
  if (typeof logBehavior !== 'function') {
    return (message, level = 'info') => {
      try {
        console.debug('[behavior]', message);
      } catch (_error) {
        /* ignore */
      }
      emit('behavior:log', { message, level });
    };
  }
  return (message, level = 'info') => {
    try {
      console.debug('[behavior]', message);
    } catch (_error) {
      /* ignore console issues */
    }
    emit('behavior:log', { message, level });
    return logBehavior(message, level);
  };
}

// Expose for debugging if desired.
if (typeof window !== 'undefined') {
  window.__PI_BEHAVIOR_BUS__ = bus;
}
