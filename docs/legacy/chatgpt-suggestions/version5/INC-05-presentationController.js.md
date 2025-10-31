# Module: `presentationController.js` — Manual‑Wins / Cooldown / Single‑Flight

```js
export class PresentationController {
  constructor(delegate, { manualLockMs = 4000, autoCooldownMs = 10000, now = () => Date.now(), log = console } = {}) {
    this.presentImpl = (id, meta) => delegate.present(id, meta);
    this.manualLockMs = manualLockMs;
    this.autoCooldownMs = autoCooldownMs;
    this.now = now;
    this.log = log;
    this.inFlightSource = null;
    this.inFlightSurveyId = null;
    this.lockUntil = 0;
    this.recent = new Map();
  }
  presentManual(id, meta = {}) {
    const ts = this.now();
    this.lockUntil = ts + this.manualLockMs;
    this.log.info('[present] manual start', { id, meta, lockUntil: this.lockUntil });
    return this.#fire('manual', id, { ...meta, source: meta.source || 'manual' });
  }
  presentAuto(id, meta = {}) {
    const ts = this.now();
    if (ts < this.lockUntil || this.inFlightSource === 'manual') {
      this.log.info('[present] auto suppressed:manual-lock', { id, until: this.lockUntil });
      return Promise.resolve({ suppressed: 'manual-lock', id, until: this.lockUntil });
    }
    const last = this.recent.get(id) || 0;
    if (ts - last < this.autoCooldownMs) {
      this.log.info('[present] auto suppressed:cooldown', { id, until: last + this.autoCooldownMs });
      return Promise.resolve({ suppressed: 'cooldown', id, until: last + this.autoCooldownMs });
    }
    return this.#fire('auto', id, { ...meta, source: meta.source || 'auto' });
  }
  async #fire(source, id, meta) {
    const ts = this.now();
    this.inFlightSource = source; this.inFlightSurveyId = id;
    try {
      const payload = await this.presentImpl(id, meta);
      this.recent.set(id, ts);
      this.log.info('[present] fired', { source, id, meta, payload });
      return payload;
    } catch (error) {
      this.log.warn('[present] failed', { source, id, meta, error });
      throw error;
    } finally {
      this.inFlightSource = null; this.inFlightSurveyId = null;
    }
  }
}
