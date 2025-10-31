import { strict as assert } from 'node:assert';
import { pathToFileURL } from 'node:url';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { withDom, withWatch } from '../../support/testUtils.mjs';

async function importBridgeModule() {
  const modulePath = path.resolve(
    path.dirname(fileURLToPath(import.meta.url)),
    '../../../preview/app/survey/bridge.js'
  );
  return import(pathToFileURL(modulePath));
}

async function runLegacySuite() {
  await withDom('http://localhost:8000/preview/basic/index.html', async () => {
    const container = document.getElementById('container');
    const postMessages = [];
    const frameWindow = {
      postMessage(message, targetOrigin) {
        postMessages.push({ message, targetOrigin });
      }
    };

    let readyPayload = null;
    const { createSurveyBridge } = await importBridgeModule();
    const bridge = createSurveyBridge({
      container,
      onReady(payload) {
        readyPayload = payload;
      }
    });

    const iframe = bridge.load({
      account: 'PI-TEST',
      host: 'survey.pulseinsights.com',
      present: ['preset-1'],
      themeCss: '/test/theme.css',
      manualCss: '/manual.css',
      proxyOrigin: 'http://localhost:3100'
    });

    Object.defineProperty(iframe, 'contentWindow', {
      value: frameWindow,
      configurable: true
    });

    assert.equal(container.querySelectorAll('iframe').length, 1, 'legacy iframe rendered');
    const iframeSrc = iframe.getAttribute('src');
    assert(
      iframeSrc.includes('account=PI-TEST') &&
        iframeSrc.includes('present=preset-1') &&
        iframeSrc.includes('proxyOrigin=http%3A%2F%2Flocalhost%3A3100'),
      `legacy iframe src should include config params. Got: ${iframeSrc}`
    );

    const queuedPresentPromise = withWatch(bridge.present('queued-survey'), 'integration queued present', 5000);
    assert.equal(
      postMessages.length,
      0,
      'legacy bridge queues present until player-ready arrives'
    );

    window.dispatchEvent(
      new window.MessageEvent('message', {
        data: { type: 'player-ready', account: 'PI-TEST', host: 'survey.pulseinsights.com' },
        source: frameWindow
      })
    );

    assert.equal(readyPayload?.account, 'PI-TEST', 'legacy onReady received payload');
    assert.equal(postMessages.length, 1, 'legacy queued message flushed after ready');
    assert.deepEqual(postMessages[0].message, { type: 'present', surveyId: 'queued-survey' });

    bridge.applyTheme('/new-theme.css');
    bridge.sendTrigger('exit-intent');

    assert.equal(postMessages.length, 3, 'legacy helper commands forwarded');
    assert.deepEqual(postMessages[1].message, {
      type: 'apply-theme',
      themeCss: '/new-theme.css'
    });
    assert.deepEqual(postMessages[2].message, { type: 'trigger', triggerId: 'exit-intent' });

    bridge.destroy?.();
  });
}

async function runProtocolSuite() {
  await withDom('http://localhost:8000/preview/basic/index.html?useProtocolV1=1', async () => {
    const container = document.getElementById('container');
    const postMessages = [];
    const frameWindow = {
      postMessage(message, targetOrigin) {
        postMessages.push({ message, targetOrigin });
      }
    };

    const statusEvents = [];
    let ready = false;

    const { createSurveyBridge } = await importBridgeModule();
    const bridge = createSurveyBridge(
      {
        container,
        onReady(payload) {
          ready = true;
          statusEvents.push({ type: 'ready', payload });
        },
        onStatus(payload) {
          statusEvents.push({ type: 'status', payload });
        }
      },
      { useProtocolV1: true, debug: false, compatImplicitAck: false }
    );

    const iframe = bridge.load({
      account: 'PI-TEST',
      host: 'survey.pulseinsights.com',
      present: ['preset-1'],
      proxyOrigin: 'http://localhost:3100'
    });

    Object.defineProperty(iframe, 'contentWindow', {
      value: frameWindow,
      configurable: true
    });

    const iframeSrc = iframe.getAttribute('src');
    const playerOrigin = new URL(iframeSrc, window.location.href).origin;

    // Command is queued prior to handshake.
    const queuedPresentPromise = withWatch(
      bridge.present('queued-survey'),
      'integration queued present',
      5000
    );
    assert.equal(postMessages.length, 0, 'present queued until handshake completes');

    // Send hello -> expect init.
    window.dispatchEvent(
      new window.MessageEvent('message', {
        origin: playerOrigin,
        source: frameWindow,
        data: { v: 1, type: 'hello', payload: { playerVersion: '1.0.0', supports: [] } }
      })
    );
    assert.equal(postMessages.length, 1, 'init message posted after hello');
    assert.equal(postMessages[0].message.type, 'init');

    // Complete handshake with ready.
    window.dispatchEvent(
      new window.MessageEvent('message', {
        origin: playerOrigin,
        source: frameWindow,
        data: { v: 1, type: 'ready' }
      })
    );

    assert.ok(ready, 'protocol bridge reported ready');
    assert.equal(
      postMessages.filter((m) => m.message.type === 'present').length,
      1,
      'queued present flushed on ready'
    );

    const presentMessage = postMessages.find((m) => m.message.type === 'present');
    const presentId = presentMessage.message.id;
    window.dispatchEvent(
      new window.MessageEvent('message', {
        origin: playerOrigin,
        source: frameWindow,
        data: { v: 1, id: presentId, type: 'status', payload: { ok: true, event: 'present-called' } }
      })
    );

    await withWatch(queuedPresentPromise, 'integration queued present resolve', 1000);

    const presentCalledEvent = statusEvents.find(
      (event) => event?.payload?.status === 'present-called' && event.payload?.surveyId === 'queued-survey'
    );
    assert.ok(presentCalledEvent, 'status event emitted when present acked');

    const dismissPromise = withWatch(bridge.dismiss(), 'dismiss ack', 1000);
    const dismissEnvelope = [...postMessages]
      .reverse()
      .find((entry) => entry.message.type === 'dismiss');
    assert.ok(dismissEnvelope, 'dismiss envelope posted');
    window.dispatchEvent(
      new window.MessageEvent('message', {
        origin: playerOrigin,
        source: frameWindow,
        data: {
          v: 1,
          id: dismissEnvelope.message.id,
          type: 'status',
          payload: { ok: true, event: 'dismiss-called' }
        }
      })
    );
    await withWatch(dismissPromise, 'dismiss resolved', 1000);
    const dismissCalledEvent = statusEvents.find(
      (event) => event?.payload?.status === 'dismiss-called'
    );
    assert.ok(dismissCalledEvent, 'dismiss status forwarded');

    // Apply theme (href) and trigger.
    const applyThemePromise = withWatch(bridge.applyTheme('/new-theme.css'), 'applyTheme ack');
    const applyThemeMessage = postMessages.find((m) => m.message.type === 'applyTheme');
    assert.ok(applyThemeMessage, 'applyTheme envelope posted');
    window.dispatchEvent(
      new window.MessageEvent('message', {
        origin: playerOrigin,
        source: frameWindow,
        data: {
          v: 1,
          id: applyThemeMessage.message.id,
          type: 'status',
          payload: { ok: true, event: 'apply-theme-applied' }
        }
      })
    );
    await withWatch(applyThemePromise, 'applyTheme resolution');

    // Apply theme (css) - inline CSS injection
    const applyThemeCssPromise = withWatch(
      bridge.applyManualCss('.test { color: red; }'),
      'applyTheme css ack'
    );
    const applyThemeCssMessage = postMessages.find(
      (m) => m.message.type === 'applyTheme' && m.message.payload?.css
    );
    assert.ok(applyThemeCssMessage, 'applyTheme css envelope posted');
    assert.ok(
      applyThemeCssMessage.message.payload.css.includes('.test'),
      'css payload includes inline CSS'
    );
    window.dispatchEvent(
      new window.MessageEvent('message', {
        origin: playerOrigin,
        source: frameWindow,
        data: {
          v: 1,
          id: applyThemeCssMessage.message.id,
          type: 'status',
          payload: { ok: true, event: 'apply-theme-applied' }
        }
      })
    );
    await withWatch(applyThemeCssPromise, 'applyTheme css resolution');

    const triggerPromise = withWatch(bridge.sendTrigger('exit-intent'), 'trigger ack');
    const triggerMessage = postMessages.find((m) => m.message.type === 'trigger');
    assert.ok(triggerMessage, 'trigger envelope posted');
    window.dispatchEvent(
      new window.MessageEvent('message', {
        origin: playerOrigin,
        source: frameWindow,
        data: {
          v: 1,
          id: triggerMessage.message.id,
          type: 'status',
          payload: { ok: true, event: 'trigger-exit-intent' }
        }
      })
    );
    await withWatch(triggerPromise, 'trigger resolution');

    // Concurrency: ensure older present is cancelled with code when superseded.
    const cancelEventStart = statusEvents.length;
    const cancelPromise = bridge.present('cancel-me');
    const cancelResult = cancelPromise.catch((error) => error);
    const keepPromise = withWatch(bridge.present('keep-me'), 'keep present promise');
    await new Promise((resolve) => setTimeout(resolve, 10));

    const cancellationEvent = statusEvents
      .slice(cancelEventStart)
      .find(
        (event) =>
          event?.payload?.status === 'present-error' && event.payload?.code === 'cancelled'
      );
    assert.ok(cancellationEvent, 'superseded present rejects with cancelled code');

    const keepPresentMessage = [...postMessages]
      .reverse()
      .find(
        (entry) =>
          entry.message.type === 'present' && entry.message.payload?.surveyId === 'keep-me'
      );
    assert.ok(keepPresentMessage?.message?.id, 'second present captured');

    window.dispatchEvent(
      new window.MessageEvent('message', {
        origin: playerOrigin,
        source: frameWindow,
        data: {
          v: 1,
          id: keepPresentMessage.message.id,
          type: 'status',
          payload: { ok: true, event: 'present-called' }
        }
      })
    );

    const cancelError = await withWatch(cancelResult, 'cancelled present resolution');
    assert.equal(cancelError?.code, 'cancelled', 'cancelled promise rejected with code');
    await withWatch(keepPromise, 'keep present resolution');
    const keepPresentCalled = statusEvents.find(
      (event) =>
        event?.payload?.status === 'present-called' && event.payload?.surveyId === 'keep-me'
    );
    assert.ok(keepPresentCalled, 'latest present resolves successfully after cancellation');

    // Compat implicit-ack path: timeout with geometry resolves via status payload
    const implicitAckBridge = createSurveyBridge(
      {
        container,
        onReady() {},
        onStatus() {},
        onError(payload) {
          if (payload?.code === 'implicit_ack') {
            statusEvents.push({ type: 'warning', payload });
          }
        }
      },
      {
        useProtocolV1: true,
        compatImplicitAck: true,
        bridgeOptions: { ackTimeoutMs: 50 }
      }
    );

    const implicitAckIframe = implicitAckBridge.load({
      account: 'PI-TEST',
      host: 'survey.pulseinsights.com'
    });

    Object.defineProperty(implicitAckIframe, 'contentWindow', {
      value: frameWindow,
      configurable: true
    });

    const implicitAckSrc = implicitAckIframe.getAttribute('src');
    const implicitAckOrigin = new URL(implicitAckSrc, window.location.href).origin;

    // Complete handshake
    window.dispatchEvent(
      new window.MessageEvent('message', {
        origin: implicitAckOrigin,
        source: frameWindow,
        data: { v: 1, type: 'hello', payload: { playerVersion: 'test', supports: [] } }
      })
    );
    await new Promise((resolve) => setTimeout(resolve, 10));
    window.dispatchEvent(
      new window.MessageEvent('message', {
        origin: implicitAckOrigin,
        source: frameWindow,
        data: { v: 1, type: 'ready' }
      })
    );
    await new Promise((resolve) => setTimeout(resolve, 10));

    // Send present command
    const implicitAckPresentPromise = implicitAckBridge.present('implicit-ack-test');
    const implicitAckPresentMsg = postMessages.find(
      (m) => m.message.type === 'present' && m.message.payload?.surveyId === 'implicit-ack-test'
    );
    assert.ok(implicitAckPresentMsg, 'implicit ack present message posted');

    // Don't ack, but send geometry status
    window.dispatchEvent(
      new window.MessageEvent('message', {
        origin: implicitAckOrigin,
        source: frameWindow,
        data: {
          v: 1,
          type: 'status',
          payload: {
            ok: true,
            widget: { visible: true, bounds: { x: 100, y: 200, w: 300, h: 400 } }
          }
        }
      })
    );

    // Wait for timeout to trigger implicit ack
    await new Promise((resolve) => setTimeout(resolve, 60));

    const implicitAckWarning = statusEvents.find(
      (event) => event?.type === 'warning' && event?.payload?.code === 'implicit_ack'
    );
    assert.ok(implicitAckWarning, 'implicit_ack warning logged');
    const implicitAckResult = await implicitAckPresentPromise;
    assert.ok(implicitAckResult?.widget?.visible, 'implicit ack resolved via geometry');

    implicitAckBridge.destroy?.();

    // Heartbeat recovery: pause pongs, downgrade, resume, next command succeeds
    const recoveryBridge = createSurveyBridge(
      {
        container,
        onReady() {},
        onStatus() {}
      },
      {
        useProtocolV1: true,
        compatImplicitAck: false,
        bridgeOptions: { ackTimeoutMs: 50, heartbeatMs: 60 }
      }
    );

    const recoveryIframe = recoveryBridge.load({
      account: 'PI-TEST',
      host: 'survey.pulseinsights.com'
    });

    Object.defineProperty(recoveryIframe, 'contentWindow', {
      value: frameWindow,
      configurable: true
    });

    const recoverySrc = recoveryIframe.getAttribute('src');
    const recoveryOrigin = new URL(recoverySrc, window.location.href).origin;

    // Complete handshake
    window.dispatchEvent(
      new window.MessageEvent('message', {
        origin: recoveryOrigin,
        source: frameWindow,
        data: { v: 1, type: 'hello', payload: { playerVersion: 'test', supports: [] } }
      })
    );
    await new Promise((resolve) => setTimeout(resolve, 10));
    window.dispatchEvent(
      new window.MessageEvent('message', {
        origin: recoveryOrigin,
        source: frameWindow,
        data: { v: 1, type: 'ready' }
      })
    );
    await new Promise((resolve) => setTimeout(resolve, 100));

    // Let heartbeat miss twice (don't respond to pings)
    await new Promise((resolve) => setTimeout(resolve, 140));

    // Bridge should be in IDLE state after missed heartbeats
    assert.equal(recoveryBridge.state, 'IDLE', 'bridge downgraded after missed heartbeats');

    // Resume pongs - respond to next ping
    const recoveryPings = postMessages.filter((m) => m.message.type === 'ping');
    const lastPing = recoveryPings[recoveryPings.length - 1];
    if (lastPing) {
      window.dispatchEvent(
        new window.MessageEvent('message', {
          origin: recoveryOrigin,
          source: frameWindow,
          data: {
            v: 1,
            id: lastPing.message.id,
            type: 'status',
            payload: { ok: true, event: 'pong-ack' }
          }
        })
      );
      window.dispatchEvent(
        new window.MessageEvent('message', {
          origin: recoveryOrigin,
          source: frameWindow,
          data: { v: 1, type: 'pong', id: lastPing.message.id }
        })
      );
    }

    await new Promise((resolve) => setTimeout(resolve, 20));

    // Next command should succeed
    const recoveryPresentPromise = recoveryBridge.present('recovery-test');
    const recoveryPresentMsg = postMessages.find(
      (m) => m.message.type === 'present' && m.message.payload?.surveyId === 'recovery-test'
    );
    assert.ok(recoveryPresentMsg, 'recovery present message posted');
    window.dispatchEvent(
      new window.MessageEvent('message', {
        origin: recoveryOrigin,
        source: frameWindow,
        data: {
          v: 1,
          id: recoveryPresentMsg.message.id,
          type: 'status',
          payload: { ok: true, event: 'present-called' }
        }
      })
    );
    await withWatch(recoveryPresentPromise, 'recovery present succeeds', 1000);

    recoveryBridge.destroy?.();

    bridge.destroy?.();
  });
}

async function run() {
  await runLegacySuite();
  await runProtocolSuite();
  console.log('surveyBridge integration test passed');
}

run()
  .then(() => {
    if (typeof process !== 'undefined' && typeof process.exit === 'function') {
      process.exit(0);
    }
  })
  .catch((error) => {
    console.error(error);
    if (typeof process !== 'undefined' && typeof process.exit === 'function') {
      process.exit(1);
    }
  });
