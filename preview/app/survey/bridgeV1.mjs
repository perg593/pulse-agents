const DEFAULT_ACK_TIMEOUT = 3000;
const DEFAULT_HANDSHAKE_TIMEOUT = 5000;
const DEFAULT_HEARTBEAT_INTERVAL = 30000;

const PRESENTATION_TYPES = new Set(['present', 'dismiss']);

function createStateChange(prev, next, reason, data) {
  return {
    prev,
    next,
    reason,
    data,
    ts: now()
  };
}

export function derivePlayerOrigin(iframe) {
  const src = iframe?.getAttribute('src') || '';
  const url = new URL(src, window.location.href);
  return url.origin;
}

function randomId() {
  return Math.random().toString(36).slice(2, 8);
}

function now() {
  return Date.now();
}

export class Bridge {
  constructor(opts) {
    this.iframe = opts.iframe;
    this.origin = opts.playerOrigin;
    this.ackTimeoutMs = opts.ackTimeoutMs ?? DEFAULT_ACK_TIMEOUT;
    this.handshakeTimeoutMs = opts.handshakeTimeoutMs ?? DEFAULT_HANDSHAKE_TIMEOUT;
    this.heartbeatMs = opts.heartbeatMs ?? DEFAULT_HEARTBEAT_INTERVAL;
    this.debug = Boolean(opts.debug);
    this.compatImplicitAck = opts.compatImplicitAck !== false;

    this._state = 'UNMOUNTED';
    this.listeners = new Map();
    this.acks = new Map();
    this.presentationInFlight = null;
    this.hbTimer = null;
    this.missedHeartbeats = 0;
    this.readyOnce = false;
    this.lastStatusPayload = null;

    this.onMessage = this.onMessage.bind(this);
  }

  get state() {
    return this._state;
  }

  setState(next, reason, data) {
    const prev = this._state;
    if (prev === next) {
      if (reason) {
        const payload = createStateChange(prev, next, reason, data);
        this.emit('statechange', payload);
      }
      return;
    }
    this._state = next;
    const payload = createStateChange(prev, next, reason, data);
    this.emit('statechange', payload);
    if (next === 'IDLE' && reason === 'ready') {
      this.emit('ready', data);
    }
  }

  init(config = {}) {
    this.setState('BOOTING', 'init-start');
    if (!this.iframe || !this.iframe.contentWindow) {
      throw new Error('bridge:init_missing_iframe');
    }
    window.addEventListener('message', this.onMessage, false);

    return new Promise((resolve, reject) => {
      const handshakeStart = now();
      const timeoutId = window.setTimeout(() => {
        this.setState('ERROR', 'player-timeout');
        this.offAll();
        reject(new Error('player_timeout'));
      }, this.handshakeTimeoutMs);

      const handleHello = (event) => {
        if (!this.isFromPlayer(event)) return;
        const data = event.data;
        if (!data || data.v !== 1 || data.type !== 'hello') return;
        window.removeEventListener('message', handleHello, false);
        if (this.debug) {
          console.debug('[Bridge] hello', data);
        }
        this.post('init', config, false).catch((err) => {
          window.clearTimeout(timeoutId);
          this.setState('ERROR', 'player-timeout');
          reject(err);
        });
      };

      const handleReady = (event) => {
        if (!this.isFromPlayer(event)) return;
        const data = event.data;
        if (!data || data.v !== 1 || data.type !== 'ready') return;
        window.removeEventListener('message', handleReady, false);
        window.clearTimeout(timeoutId);
        this.markReady();
        if (this.debug) {
          console.debug('[Bridge] ready in', now() - handshakeStart, 'ms');
        }
        resolve();
      };

      window.addEventListener('message', handleHello, false);
      window.addEventListener('message', handleReady, false);
    });
  }

  present(surveyId, opts = {}) {
    if (!surveyId) return Promise.reject(new Error('bad_payload'));

    if (this.presentationInFlight) {
      const previous = this.presentationInFlight;
      this.presentationInFlight = null;
      const cancelError = new Error('cancelled');
      cancelError.code = 'cancelled';
      cancelError.event = 'present-cancelled';
      this.setState('IDLE', 'present-cancelled', previous.meta || {});
      previous.reject(cancelError);
    }

    const commandEntry = this.post('present', { surveyId, force: !!opts.force });
    commandEntry.meta = { surveyId: String(surveyId) };
    this.presentationInFlight = commandEntry;
    this.setState('PRESENTING', 'present-start', { surveyId: String(surveyId) });
    return commandEntry.promise
      .then((payload) => {
        const reason = commandEntry.wasImplicitAck ? 'implicit-ack' : 'present-complete';
        this.setState('IDLE', reason, { surveyId: String(surveyId), payload });
        return payload;
      })
      .catch((error) => {
        if (error?.code === 'cancelled') {
          this.setState('IDLE', 'present-cancelled', { surveyId: String(surveyId) });
        } else if (error?.code === 'implicit_ack') {
          this.setState('IDLE', 'implicit-ack', { surveyId: String(surveyId) });
        } else if (error?.code === 'ack_timeout') {
          this.setState('ERROR', 'ack-timeout', { command: 'present', surveyId: String(surveyId) });
        } else {
          this.setState('ERROR', 'present-failed', { surveyId: String(surveyId), error });
        }
        throw error;
      })
      .finally(() => {
        if (this.presentationInFlight === commandEntry) {
          this.presentationInFlight = null;
        }
      });
  }

  dismiss() {
    this.setState('DISMISSING', 'dismiss-start');
    const entry = this.post('dismiss', {});
    return entry.promise
      .then((payload) => {
        this.setState('IDLE', 'dismiss-complete');
        return payload;
      })
      .catch((error) => {
        if (error?.code === 'ack_timeout') {
          this.setState('ERROR', 'ack-timeout', { command: 'dismiss' });
        } else {
          this.setState('ERROR', 'dismiss-failed', { error });
        }
        throw error;
      });
  }

  applyTheme(input) {
    return this.post('applyTheme', input || {}).promise;
  }

  trigger(command, ...args) {
    return this.post('trigger', { command, args }).promise;
  }

  setPlacement(placement) {
    return this.post('setPlacement', { placement }).promise;
  }

  setTokens(tokens) {
    return this.post('setTokens', tokens || {}).promise;
  }

  on(eventName, callback) {
    if (!this.listeners.has(eventName)) {
      this.listeners.set(eventName, new Set());
    }
    this.listeners.get(eventName).add(callback);
  }

  off(eventName, callback) {
    this.listeners.get(eventName)?.delete(callback);
  }

  destroy() {
    window.removeEventListener('message', this.onMessage, false);
    if (this.hbTimer != null) {
      window.clearInterval(this.hbTimer);
    }
    this.hbTimer = null;
    this.missedHeartbeats = 0;

    this.acks.forEach((entry) => {
      entry.reject(new Error('bridge_destroyed'));
    });
    this.acks.clear();
    this.setState('UNMOUNTED', 'destroy');
    this.emit('close');
    this.listeners.clear();
  }

  emit(eventName, payload) {
    if (eventName === 'ready') {
      if (this.readyOnce) return;
      this.readyOnce = true;
    }
    const set = this.listeners.get(eventName);
    if (set) {
      set.forEach((fn) => {
        try {
          fn(payload);
        } catch (_error) {
          // swallow listener errors
        }
      });
    }
  }

  markReady() {
    this.setState('IDLE', 'ready');
    this.emit('status', { ok: true, event: 'player-ready' });
    this.missedHeartbeats = 0;
    if (this.hbTimer != null) {
      window.clearInterval(this.hbTimer);
    }
    this.hbTimer = window.setInterval(() => {
      const heartbeat = this.post('ping', {}, true);
      heartbeat.promise
        .then(() => {
          this.missedHeartbeats = 0;
        })
        .catch((error) => {
          this.missedHeartbeats += 1;
          if (this.missedHeartbeats >= 2) {
            this.emit('error', { code: 'heartbeat_timeout', message: error?.message });
            this.emit('status', { ok: false, event: 'player-inactive', heartbeat: false });
            this.setState('IDLE', 'heartbeat-missed-2');
          }
        });
    }, this.heartbeatMs);
  }

  isFromPlayer(event) {
    return event.origin === this.origin && event.source === this.iframe.contentWindow;
  }

  onMessage(event) {
    if (!this.isFromPlayer(event)) return;
    const data = event.data;
    if (!data || data.v !== 1) return;

    if (this.debug) {
      console.debug('[Bridge <-]', data);
    }

    if (data.type === 'ready') {
      this.markReady();
      if (data.id && this.acks.has(data.id)) {
        const entry = this.acks.get(data.id);
        this.acks.delete(data.id);
        entry.resolve(data.payload);
      }
      return;
    }

    if (data.type === 'status' && data.payload) {
      this.lastStatusPayload = data.payload;
    }

    if (data.id && (data.type === 'status' || data.type === 'error' || data.type === 'pong')) {
      const entry = this.acks.get(data.id);
      if (entry) {
        this.acks.delete(data.id);
        if (data.type === 'error') {
          this.emit('error', data.payload);
          entry.reject(data.payload || new Error('error'));
        } else {
          if (data.type === 'status') {
            this.emit('status', data.payload);
          }
          entry.resolve(data.payload);
        }
        return;
      }
    }

    if (data.type === 'status') {
      this.emit('status', data.payload);
      return;
    }

    if (data.type === 'error') {
      this.emit('error', data.payload);
      return;
    }
  }

  post(type, payload, awaitAck = true) {
    if (!this.iframe?.contentWindow) {
      return Promise.reject(new Error('bridge_post_missing_iframe'));
    }
    const id = randomId();
    const message = { v: 1, id, type, payload, origin: 'bridge' };
    if (this.debug) {
      console.debug('[Bridge ->]', message);
    }
    this.iframe.contentWindow.postMessage(message, this.origin);

    if (!awaitAck) {
      return Promise.resolve({ ok: true });
    }

    const entry = {};
    const promise = new Promise((resolve, reject) => {
      const timer = window.setTimeout(() => {
        this.acks.delete(id);
        if (this.compatImplicitAck && this.lastStatusPayload) {
          const warning = {
            code: 'implicit_ack',
            command: type,
            message: 'Ack missing; resolved via status payload'
          };
          // Log warning for telemetry (per plan requirement)
          try {
            console.warn('[Bridge] implicit_ack:', warning);
          } catch (_error) {
            /* ignore console issues */
          }
          this.emit('error', warning);
          entry.wasImplicitAck = true;
          resolve(this.lastStatusPayload);
        } else {
          const timeoutError = new Error('ack_timeout');
          timeoutError.code = 'ack_timeout';
          reject(timeoutError);
        }
      }, this.ackTimeoutMs);
      entry.resolve = (value) => {
        window.clearTimeout(timer);
        resolve(value);
      };
      entry.reject = (error) => {
        window.clearTimeout(timer);
        reject(error);
      };
    });

    entry.promise = promise;
    entry.type = type;
    entry.meta = entry.meta || {};
    entry.wasImplicitAck = false;

    this.acks.set(id, entry);
    return entry;
  }

  offAll() {
    this.listeners.clear();
    window.removeEventListener('message', this.onMessage, false);
  }
}
