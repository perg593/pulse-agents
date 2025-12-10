const fs = require('fs');
const path = require('path');

function assert(condition, message) {
  if (!condition) {
    throw new Error(message || 'Assertion failed');
  }
}

function test(name, fn) {
  try {
    fn();
    console.log(`✓ ${name}`);
  } catch (error) {
    console.error(`✗ ${name}`);
    console.error(error.message);
    throw error;
  }
}

const bridgePath = path.resolve(__dirname, '../../../preview/app/survey/bridge.js');
const bridgeSource = fs.readFileSync(bridgePath, 'utf8');

console.log('Testing iframe sandbox configuration in bridge.js');

test('Iframe sandbox enforces restricted navigation', () => {
  assert(
    bridgeSource.includes('allow-scripts allow-same-origin allow-forms allow-downloads'),
    'Expected sandbox to include scripts, same-origin, forms, downloads',
  );
  ['allow-top-navigation', 'allow-top-navigation-by-user-activation', 'allow-popups', 'allow-popups-to-escape-sandbox'].forEach(
    (token) => {
      assert(!bridgeSource.includes(token), `Sandbox must not include ${token}`);
    },
  );
});

test('Iframe uses no-referrer policy', () => {
  assert(
    bridgeSource.includes('referrerpolicy') && bridgeSource.includes('no-referrer'),
    'Expected referrerpolicy no-referrer',
  );
});
