let getStore = null;
let notify = () => {};

/**
 * Configure the logging module with access to the v3 store and a notifier.
 * @param {() => any} getter
 * @param {(entry: any) => void} onWrite
 */
export function configureLog(getter, onWrite) {
  getStore = getter;
  notify = typeof onWrite === 'function' ? onWrite : () => {};
}

/**
 * Append a structured log entry and notify listeners.
 * @param {'ui'|'tag'|'theme'|'trigger'|'net'} source
 * @param {'info'|'warn'|'error'|'event'} level
 * @param {string} message
 * @param {Record<string, unknown>} [data]
 */
export function log(source, level, message, data) {
  if (!getStore) return;
  const store = getStore();
  const entry = {
    ts: Date.now(),
    source,
    level,
    message,
    data: data || null
  };
  const next = [...(store.logs || []), entry].slice(-200);
  store.logs = next;
  notify(entry);
}
