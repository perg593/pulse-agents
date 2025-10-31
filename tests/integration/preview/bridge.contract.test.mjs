import { strict as assert } from 'node:assert';
import { withBridgeContext, withWatch, waitForState } from '../../support/testUtils.mjs';

async function testHandshakeCompletesQuickly() {
  await withBridgeContext({}, async ({ handshakeDuration, bridge }) => {
    await waitForState(bridge, 'IDLE');
    assert.ok(handshakeDuration < 2000, `handshake took too long: ${handshakeDuration}ms`);
  });
}

async function testPresentAckResolvesAndEmitsStatus() {
  await withBridgeContext({}, async ({ bridge, frameWindow, playerOrigin, postMessages }) => {
    const statusEvents = [];
    bridge.on('status', (payload) => statusEvents.push(payload));

    const startStatePromise = waitForState(bridge, 'PRESENTING', { reason: 'present-start' });
    const promise = withWatch(bridge.present('unit-present'), 'present ack');
    const envelope = postMessages.find((entry) => entry.message.type === 'present');
    assert.ok(envelope, 'present message posted');
    await startStatePromise;
    const completionStatePromise = waitForState(bridge, 'IDLE', { reason: 'present-complete' });

    const ackPayload = { ok: true, event: 'present-called' };
    window.dispatchEvent(
      new window.MessageEvent('message', {
        origin: playerOrigin,
        source: frameWindow,
        data: { v: 1, id: envelope.message.id, type: 'status', payload: ackPayload }
      })
    );

    const result = await promise;
    assert.deepEqual(result, ackPayload, 'present promise resolves with ack payload');
    assert.ok(statusEvents.some((entry) => entry?.event === 'present-called'), 'status emitted to observers');
    await completionStatePromise;
  });
}

async function testAckTimeoutRejects() {
  await withBridgeContext({ ackTimeoutMs: 40 }, async ({ bridge }) => {
    const statePromise = waitForState(bridge, 'ERROR', { reason: 'ack-timeout', timeout: 500 });
    await assert.rejects(
      withWatch(bridge.present('never-acks'), 'ack timeout', 120),
      (error) => error?.message === 'ack_timeout' && error?.code === 'ack_timeout'
    );
    await statePromise;
  });
}

async function testForgedOriginIgnored() {
  await withBridgeContext({}, async ({ bridge, frameWindow, playerOrigin }) => {
    let statusCount = 0;
    bridge.on('status', () => statusCount += 1);

    window.dispatchEvent(
      new window.MessageEvent('message', {
        origin: 'https://malicious.example',
        source: frameWindow,
        data: { v: 1, type: 'status', payload: { ok: true, event: 'fake' } }
      })
    );
    await new Promise((resolve) => setTimeout(resolve, 10));
    assert.equal(statusCount, 0, 'forged origin ignored');

    window.dispatchEvent(
      new window.MessageEvent('message', {
        origin: playerOrigin,
        source: frameWindow,
        data: { v: 1, type: 'status', payload: { ok: true, event: 'legit' } }
      })
    );
    await new Promise((resolve) => setTimeout(resolve, 10));
    assert.equal(statusCount, 1, 'legitimate origin processed');
  });
}

async function testIgnoresWrongOriginMessages() {
  await withBridgeContext({}, async ({ bridge, frameWindow }) => {
    let statusCount = 0;
    bridge.on('status', () => {
      statusCount += 1;
    });

    window.dispatchEvent(
      new window.MessageEvent('message', {
        origin: 'https://evil.example',
        source: frameWindow,
        data: { v: 1, type: 'status', payload: { ok: true } }
      })
    );

    await new Promise((resolve) => setTimeout(resolve, 10));
    assert.equal(statusCount, 0, 'status ignored from unexpected origin');
    assert.equal(bridge.state, 'IDLE', 'bridge state unchanged');
  });
}

async function testPresentFailureTransitions() {
  await withBridgeContext({}, async ({ bridge, frameWindow, playerOrigin, postMessages }) => {
    const states = [];
    bridge.on('statechange', (payload) => states.push(payload));

    const presentPromise = bridge.present('should-fail');
    const envelope = postMessages.find((entry) => entry.message.type === 'present');
    assert.ok(envelope, 'present envelope posted');

    window.dispatchEvent(
      new window.MessageEvent('message', {
        origin: playerOrigin,
        source: frameWindow,
        data: {
          v: 1,
          id: envelope.message.id,
          type: 'error',
          payload: { code: 'present_fail', message: 'boom' }
        }
      })
    );

    await assert.rejects(presentPromise, (error) => error?.code === 'present_fail');
    const lastState = states.at(-1);
    assert.ok(lastState, 'state change recorded');
    assert.equal(lastState.next, 'ERROR');
    assert.equal(lastState.reason, 'present-failed');
  });
}

async function testCloseEventEmitted() {
  await withBridgeContext({}, async ({ bridge }) => {
    let closed = false;
    bridge.on('close', () => {
      closed = true;
    });
    bridge.destroy();
    assert.ok(closed, 'close event fired on destroy');
  });
}

async function testHeartbeatEmitsInactiveAfterMisses() {
  await withBridgeContext(
    { ackTimeoutMs: 30, heartbeatMs: 35, compatImplicitAck: false },
    async ({ bridge, frameWindow, playerOrigin, postMessages }) => {
      const errors = [];
      const statuses = [];
      bridge.on('error', (payload) => errors.push(payload));
      bridge.on('status', (payload) => statuses.push(payload));

      const inactiveStatePromise = waitForState(bridge, 'IDLE', { reason: 'heartbeat-missed-2', timeout: 800 });
      await new Promise((resolve) => setTimeout(resolve, 160));
      await inactiveStatePromise;

      assert.ok(errors.some((err) => err?.code === 'heartbeat_timeout'), 'heartbeat timeout error fired');
      assert.ok(
        statuses.some((status) => status?.event === 'player-inactive'),
        'player-inactive status emitted'
      );

      const pingEnvelope = [...postMessages].reverse().find((entry) => entry.message.type === 'ping');
      assert.ok(pingEnvelope, 'ping was posted');

      window.dispatchEvent(
        new window.MessageEvent('message', {
          origin: playerOrigin,
          source: frameWindow,
          data: { v: 1, id: pingEnvelope.message.id, type: 'status', payload: { ok: true, event: 'pong-ack' } }
        })
      );
      window.dispatchEvent(
        new window.MessageEvent('message', {
          origin: playerOrigin,
          source: frameWindow,
          data: { v: 1, type: 'pong', id: pingEnvelope.message.id }
        })
      );
    }
  );
}

async function testIgnoresWrongVersionMessages() {
  await withBridgeContext({}, async ({ bridge, frameWindow, playerOrigin }) => {
    let statusCount = 0;
    bridge.on('status', () => {
      statusCount += 1;
    });

    // Send message with wrong version
    window.dispatchEvent(
      new window.MessageEvent('message', {
        origin: playerOrigin,
        source: frameWindow,
        data: { v: 2, type: 'status', payload: { ok: true, event: 'wrong-version' } }
      })
    );
    await new Promise((resolve) => setTimeout(resolve, 10));
    assert.equal(statusCount, 0, 'message with wrong version ignored');

    // Send message with no version
    window.dispatchEvent(
      new window.MessageEvent('message', {
        origin: playerOrigin,
        source: frameWindow,
        data: { type: 'status', payload: { ok: true, event: 'no-version' } }
      })
    );
    await new Promise((resolve) => setTimeout(resolve, 10));
    assert.equal(statusCount, 0, 'message without version ignored');

    // Send valid v1 message
    window.dispatchEvent(
      new window.MessageEvent('message', {
        origin: playerOrigin,
        source: frameWindow,
        data: { v: 1, type: 'status', payload: { ok: true, event: 'legit' } }
      })
    );
    await new Promise((resolve) => setTimeout(resolve, 10));
    assert.equal(statusCount, 1, 'valid v1 message processed');
  });
}

async function testDerivePlayerOrigin() {
  const { derivePlayerOrigin } = await import('../../../preview/app/survey/bridgeV1.mjs');
  await withBridgeContext({}, async ({ bridge }) => {
    // Use the iframe from the bridge context
    const iframe = bridge.iframe;
    if (!iframe) {
      throw new Error('iframe not available in bridge context');
    }

    // Test relative src
    iframe.setAttribute('src', '/preview/app/survey/player.html');
    const origin1 = derivePlayerOrigin(iframe);
    assert.equal(origin1, 'http://localhost:8000', 'relative src derives correct origin');

    // Test absolute src
    iframe.setAttribute('src', 'https://preview.pages.dev/preview/app/survey/player.html');
    const origin2 = derivePlayerOrigin(iframe);
    assert.equal(origin2, 'https://preview.pages.dev', 'absolute src derives correct origin');

    // Test proxy URL
    iframe.setAttribute('src', 'https://proxy.example.com/proxy?url=https://target.com');
    const origin3 = derivePlayerOrigin(iframe);
    assert.equal(origin3, 'https://proxy.example.com', 'proxy URL derives proxy origin');
  });
}

async function run() {
  await testHandshakeCompletesQuickly();
  await testPresentAckResolvesAndEmitsStatus();
  await testAckTimeoutRejects();
  await testForgedOriginIgnored();
  await testIgnoresWrongOriginMessages();
  await testPresentFailureTransitions();
  await testCloseEventEmitted();
  await testHeartbeatEmitsInactiveAfterMisses();
  await testIgnoresWrongVersionMessages();
  await testDerivePlayerOrigin();
  console.log('bridge.contract tests passed');
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
