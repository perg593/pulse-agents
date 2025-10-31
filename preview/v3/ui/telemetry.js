import { telemetrySafe } from './logging/sanitize.js';

export const sinks = [
  (event) => {
    try {
      const safe = telemetrySafe(event);
      const { type, ts, ...rest } = safe;
      // eslint-disable-next-line no-console
      console.log('[PulseDemo]', type, { ts, ...rest });
    } catch {
      // ignore telemetry sink errors
    }
  }
];
