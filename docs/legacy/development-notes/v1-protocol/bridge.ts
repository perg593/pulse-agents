/* eslint-disable @typescript-eslint/no-explicit-any */
/**
 * Bridge.ts — v1 protocol helper for Bridge ⇄ Player messaging.
 * Works in plain TS/JS; no framework required.
 *
 * Usage:
 *   const bridge = new Bridge({ iframe, playerOrigin: 'https://agent-demo.pages.dev' });
 *   await bridge.init({ placement: 'BR', density: 0, tokens:{ brand:'#7c5cff', radius:8 } });
 *   await bridge.present('survey-123');
 *   await bridge.applyTheme({ href:'/theme/example.css' });
 *   await bridge.trigger('simulateExitIntent');
 *
 * Events:
 *   bridge.on('status', (s) => { ... });
 *   bridge.on('error',  (e) => { ... });
 *   bridge.on('ready',  ()  => { ... });
 *   bridge.on('close',  ()  => { ... });
 */

export type Placement = 'BR'|'BL'|'TR'|'TL';

export type MessageType =
  | 'hello' | 'init' | 'ready'
  | 'present' | 'dismiss' | 'applyTheme' | 'trigger' | 'setPlacement' | 'setTokens'
  | 'status' | 'error' | 'ping' | 'pong';

export interface Envelope<T=any> {
  v: 1;
  id: string;
  type: MessageType;
  payload?: T;
  origin?: 'bridge'|'player';
}

export interface InitConfig {
  placement?: Placement;
  density?: -1|0|1;
  tokens?: { brand?: string; radius?: number; density?: -1|0|1 };
}

export interface BridgeOptions {
  iframe: HTMLIFrameElement;
  playerOrigin: string;                 // exact origin of Player (targetOrigin for postMessage)
  handshakeTimeoutMs?: number;          // default 5000
  ackTimeoutMs?: number;                // default 3000
  heartbeatMs?: number;                 // default 30000
  debug?: boolean;
}

type AckResolver = { resolve:(v:any)=>void; reject:(e:any)=>void };

type BridgeState = 'UNMOUNTED'|'MOUNTING'|'BOOTING'|'IDLE'|'PRESENTING'|'DISMISSING'|'ERROR';

export class Bridge {
  private iframe: HTMLIFrameElement;
  private origin: string;
  private acks = new Map<string, AckResolver>();
  private listeners = new Map<string, Set<(p:any)=>void>>();
  private state: BridgeState = 'UNMOUNTED';
  private hbTimer: number | null = null;
  private ackTimeoutMs: number;
  private handshakeTimeoutMs: number;
  private heartbeatMs: number;
  private debug: boolean;
  private readyOnce = false;

  constructor(opts: BridgeOptions) {
    this.iframe = opts.iframe;
    this.origin = opts.playerOrigin;
    this.ackTimeoutMs = opts.ackTimeoutMs ?? 3000;
    this.handshakeTimeoutMs = opts.handshakeTimeoutMs ?? 5000;
    this.heartbeatMs = opts.heartbeatMs ?? 30000;
    this.debug = !!opts.debug;
  }

  // -- Public API ------------------------------------------------------------

  /** Start handshake with the Player. Resolves when Player sends `ready`. */
  init(config: InitConfig = {}): Promise<void> {
    if (!this.iframe?.contentWindow) throw new Error('Bridge: iframe has no contentWindow');
    this.state = 'BOOTING';
    window.addEventListener('message', this.onMessage, false);

    return new Promise<void>((resolve, reject) => {
      const t = window.setTimeout(() => {
        this.state = 'ERROR';
        this.offAll();
        reject(new Error('player_timeout'));
      }, this.handshakeTimeoutMs);

      // Wait for "hello"
      const onHello = (ev: MessageEvent<any>) => {
        if (!this.isFromPlayer(ev)) return;
        const m = ev.data as Envelope<any>;
        if (!m || m.v !== 1 || m.type !== 'hello') return;
        window.removeEventListener('message', onHello);
        // Send init and wait for ready (ack with same id or a "ready" without id)
        this.post('init', config).then(() => {
          // Some players ack "init" with status, then send a separate "ready". Handle both.
        }).catch((e) => {
          window.clearTimeout(t);
          this.state = 'ERROR';
          reject(e);
        });
      };
      window.addEventListener('message', onHello, false);

      // Also accept a direct "ready" (some Players might eager-send hello+ready)
      const onReady = (ev: MessageEvent<any>) => {
        if (!this.isFromPlayer(ev)) return;
        const m = ev.data as Envelope<any>;
        if (!m || m.v !== 1 || m.type !== 'ready') return;
        window.removeEventListener('message', onReady);
        window.clearTimeout(t);
        this.markReady();
        resolve();
      };
      window.addEventListener('message', onReady, false);
    });
  }

  /** Present an agent by surveyId. */
  present(surveyId: string, opts: { force?: boolean } = {}) {
    return this.post('present', { surveyId, force: !!opts.force });
  }

  /** Dismiss the widget. */
  dismiss() { return this.post('dismiss', {}); }

  /** Apply curated or generated theme. */
  applyTheme(input: { href?: string; css?: string; tokens?: { brand?: string; radius?: number; density?: -1|0|1 } }) {
    return this.post('applyTheme', input);
  }

  /** Send a simulated trigger. */
  trigger(command: string, ...args: any[]) {
    return this.post('trigger', { command, args });
  }

  /** Update placement. */
  setPlacement(placement: Placement) {
    return this.post('setPlacement', { placement });
  }

  /** Update tokens (brand / radius / density). */
  setTokens(tokens: { brand?: string; radius?: number; density?: -1|0|1 }) {
    return this.post('setTokens', tokens);
  }

  /** Subscribe to Bridge events: 'status' | 'error' | 'ready' | 'close'. */
  on(eventName: 'status'|'error'|'ready'|'close', cb: (payload:any)=>void) {
    if (!this.listeners.has(eventName)) this.listeners.set(eventName, new Set());
    this.listeners.get(eventName)!.add(cb);
  }

  off(eventName: 'status'|'error'|'ready'|'close', cb: (payload:any)=>void) {
    this.listeners.get(eventName)?.delete(cb);
  }

  /** Destroy listeners and timers. */
  destroy() {
    window.removeEventListener('message', this.onMessage);
    if (this.hbTimer != null) window.clearInterval(this.hbTimer);
    this.hbTimer = null;
    this.acks.forEach(({ reject }, id) => reject(new Error('bridge_destroyed:' + id)));
    this.acks.clear();
    this.offAll();
    this.state = 'UNMOUNTED';
  }

  // -- Internals -------------------------------------------------------------

  private offAll() {
    this.listeners.clear();
    window.removeEventListener('message', this.onMessage);
  }

  private emit(eventName: 'status'|'error'|'ready'|'close', payload?: any) {
    if (eventName === 'ready' && this.readyOnce) return;
    if (eventName === 'ready') this.readyOnce = true;
    const set = this.listeners.get(eventName);
    set?.forEach(fn => { try { fn(payload); } catch {} });
  }

  private markReady() {
    this.state = 'IDLE';
    this.emit('ready');
    // Heartbeat
    if (this.hbTimer != null) window.clearInterval(this.hbTimer);
    this.hbTimer = window.setInterval(() => {
      this.post('ping', {}, true).catch(() => {
        // two consecutive failures → mark idle and surface soft error
      });
    }, this.heartbeatMs);
  }

  private isFromPlayer(ev: MessageEvent<any>): boolean {
    return ev.origin === this.origin && ev.source === this.iframe.contentWindow;
  }

  private onMessage = (ev: MessageEvent<any>) => {
    if (!this.isFromPlayer(ev)) return;
    const m = ev.data as Envelope<any>;
    if (!m || m.v !== 1) return;
    if (this.debug) console.debug('[Bridge <-]', m);

    // Handshake "ready" can arrive independently
    if (m.type === 'ready') {
      this.markReady();
      return;
    }

    // Ack handling
    if (m.id && (m.type === 'status' || m.type === 'error')) {
      const entry = this.acks.get(m.id);
      if (entry) {
        this.acks.delete(m.id);
        if (m.type === 'error') entry.reject(m.payload ?? new Error('error'));
        else entry.resolve(m.payload);
        return;
      }
    }

    // Streaming events
    if (m.type === 'status') this.emit('status', m.payload);
    if (m.type === 'error')  this.emit('error',  m.payload);
  };

  private post<TReq=any, TRes=any>(type: MessageType, payload?: TReq, awaitAck = true): Promise<TRes> {
    const id = randomId();
    const msg: Envelope = { v: 1, id, type, payload, origin: 'bridge' };
    if (this.debug) console.debug('[Bridge ->]', msg);
    this.iframe.contentWindow!.postMessage(msg, this.origin);

    if (!awaitAck) return Promise.resolve({} as TRes);

    return new Promise<TRes>((resolve, reject) => {
      const timeout = window.setTimeout(() => {
        this.acks.delete(id);
        reject(new Error('ack_timeout'));
      }, this.ackTimeoutMs);
      this.acks.set(id, {
        resolve: (v:any) => { window.clearTimeout(timeout); resolve(v as TRes); },
        reject:  (e:any) => { window.clearTimeout(timeout); reject(e); }
      });
    });
  }
}

function randomId(): string {
  // 5–6 char base36 id
  return Math.random().toString(36).slice(2, 8);
}
