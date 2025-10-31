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

async function run() {
  await withDom('http://localhost:8000/preview/basic/index.html?useProtocolV1=1', async () => {
    const container = document.getElementById('container');
    const postMessages = [];
    const frameWindow = {
      postMessage(message, targetOrigin) {
        postMessages.push({ message, targetOrigin });
      }
    };

    const { createSurveyBridge } = await importBridgeModule();
    const bridge = createSurveyBridge(
      { container },
      {
        useProtocolV1: true,
        compatImplicitAck: false,
        bridgeOptions: { handshakeTimeoutMs: 40, ackTimeoutMs: 20 }
      }
    );

    const iframe = bridge.load({
      account: 'PI-TIMEOUT',
      host: 'survey.pulseinsights.com'
    });

    Object.defineProperty(iframe, 'contentWindow', {
      value: frameWindow,
      configurable: true
    });

    const iframeSrc = iframe.getAttribute('src');
    const playerOrigin = new URL(iframeSrc, window.location.href).origin;

    const pendingErrorPromise = bridge.present('queued-survey').catch((error) => error);

    window.dispatchEvent(
      new window.MessageEvent('message', {
        origin: playerOrigin,
        source: frameWindow,
        data: { v: 1, type: 'hello', payload: { playerVersion: 'test', supports: [] } }
      })
    );

    const initEnvelope = postMessages.find((entry) => entry.message.type === 'init');
    assert.ok(initEnvelope, 'bridge should attempt init handshake');

    const err = await withWatch(pendingErrorPromise, 'queued present rejects on timeout', 1500);
    assert.equal(err?.code, 'player_timeout', 'pending action rejects with timeout error');
  });

  console.log('handshake failure integration test passed');
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
