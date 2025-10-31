import { strict as assert } from 'node:assert';
import { JSDOM } from 'jsdom';
import { Bridge as BridgeV1 } from '../../preview/app/survey/bridgeV1.mjs';

export function tapV1Messages(label = 'v1') {
  if (typeof window === 'undefined' || !window.addEventListener) {
    return () => {};
  }
  const seen = new WeakSet();
  const handler = (event) => {
    const message = event?.data;
    if (!message || message.v !== 1 || typeof message.type !== 'string') return;
    if (seen.has(message)) return;
    seen.add(message);
    try {
      console.log(`[${label}]`, message.type, message.id || '-', message.payload?.event || '');
    } catch (_error) {
      /* ignore logging issues */
    }
  };
  window.addEventListener('message', handler);
  return () => window.removeEventListener('message', handler);
}

export async function withWatch(promise, label, ms = 1500) {
  let finished = false;
  const timer = setTimeout(() => {
    if (!finished) {
      try {
        console.warn('[HANG?]', label);
      } catch (_error) {
        /* ignore */
      }
    }
  }, ms);
  try {
    const result = await promise;
    finished = true;
    return result;
  } finally {
    clearTimeout(timer);
  }
}

export async function withDom(url, fn) {
  const dom = new JSDOM('<!doctype html><body><div id="container"></div></body>', { url });
  global.window = dom.window;
  global.document = dom.window.document;
  global.Node = dom.window.Node;
  global.HTMLElement = dom.window.HTMLElement;
  global.CustomEvent = dom.window.CustomEvent;
  const stopTap = tapV1Messages('test');
  try {
    await fn();
  } finally {
    stopTap();
    delete global.window;
    delete global.document;
    delete global.Node;
    delete global.HTMLElement;
    delete global.CustomEvent;
  }
}

export async function withBridgeContext(options = {}, fn) {
  const {
    ackTimeoutMs = 30,
    handshakeTimeoutMs = 50,
    heartbeatMs = 120,
    compatImplicitAck = true,
    debug = false
  } = options;

  await withDom('http://localhost:8000/preview/basic/index.html', async () => {
    const playerOrigin = 'https://player.test';
    const iframe = document.createElement('iframe');
    iframe.src = `${playerOrigin}/player.html`;
    document.body.appendChild(iframe);

    const postMessages = [];
    const frameWindow = {
      postMessage(message, targetOrigin) {
        postMessages.push({ message, targetOrigin });
      }
    };

    Object.defineProperty(iframe, 'contentWindow', {
      value: frameWindow,
      configurable: true
    });

    const bridge = new BridgeV1({
      iframe,
      playerOrigin,
      ackTimeoutMs,
      handshakeTimeoutMs,
      heartbeatMs,
      compatImplicitAck,
      debug
    });

    const handshakeStart = Date.now();
    const initPromise = bridge.init();
    window.dispatchEvent(
      new window.MessageEvent('message', {
        origin: playerOrigin,
        source: frameWindow,
        data: { v: 1, type: 'hello', payload: { playerVersion: 'test', supports: [] } }
      })
    );

    const initEnvelope = postMessages.find((entry) => entry.message.type === 'init');
    assert.ok(initEnvelope, 'init message should be posted during handshake');

    window.dispatchEvent(
      new window.MessageEvent('message', {
        origin: playerOrigin,
        source: frameWindow,
        data: { v: 1, type: 'ready', id: initEnvelope.message.id, payload: { ok: true } }
      })
    );

    await withWatch(initPromise, 'bridge.init()', handshakeTimeoutMs + 50);
    const handshakeDuration = Date.now() - handshakeStart;
    postMessages.length = 0;

    try {
      await fn({ bridge, frameWindow, playerOrigin, postMessages, handshakeDuration });
    } finally {
      bridge.destroy();
    }
  });
}

export function waitForState(bridge, next, { reason, timeout = 2000 } = {}) {
  if (!bridge || typeof bridge.on !== 'function') {
    return Promise.reject(new Error('bridge does not support state listeners'));
  }
  if (bridge.state === next && (!reason || reason === undefined)) {
    return Promise.resolve({ prev: bridge.state, next: bridge.state, reason, ts: Date.now() });
  }
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      bridge.off?.('statechange', handler);
      reject(new Error(`timeout waiting for state=${next}${reason ? `/${reason}` : ''}`));
    }, timeout);

    const handler = (payload) => {
      const matchesState = payload?.next === next;
      const matchesReason = reason ? payload?.reason === reason : true;
      if (matchesState && matchesReason) {
        clearTimeout(timer);
        bridge.off?.('statechange', handler);
        resolve(payload);
      }
    };

    bridge.on('statechange', handler);
  });
}
