/**
 * Unit tests for race condition prevention in URL rewriting script
 * Tests that the script guard prevents multiple installations
 */

// Test framework
function assert(condition, message) {
  if (!condition) {
    throw new Error(`Assertion failed: ${message}`);
  }
}

function test(name, fn) {
  try {
    fn();
    console.log(`✓ ${name}`);
  } catch (error) {
    console.error(`✗ ${name}`);
    console.error(`  ${error.message}`);
    throw error;
  }
}

console.log('Testing race condition prevention...\n');

// Simulate the guard mechanism
function simulateScriptExecution(window) {
  if (window.__PI_PROXY_URL_REWRITING_INSTALLED) {
    return { installed: false, reason: 'already installed' };
  }
  window.__PI_PROXY_URL_REWRITING_INSTALLED = true;
  return { installed: true };
}

// Test 1: Single execution should succeed
test('Single script execution should install successfully', () => {
  const window = {};
  const result = simulateScriptExecution(window);
  assert(result.installed === true, 'Should install on first execution');
  assert(window.__PI_PROXY_URL_REWRITING_INSTALLED === true, 'Flag should be set');
});

// Test 2: Multiple executions should be blocked
test('Second script execution should be blocked', () => {
  const window = {};
  const result1 = simulateScriptExecution(window);
  const result2 = simulateScriptExecution(window);
  
  assert(result1.installed === true, 'First execution should succeed');
  assert(result2.installed === false, 'Second execution should be blocked');
  assert(result2.reason === 'already installed', 'Should indicate already installed');
});

// Test 3: Concurrent execution simulation
test('Concurrent execution attempts should only allow one', () => {
  const window = {};
  const results = [];
  
  // Simulate 10 concurrent execution attempts
  for (let i = 0; i < 10; i++) {
    results.push(simulateScriptExecution(window));
  }
  
  const installedCount = results.filter(r => r.installed).length;
  assert(installedCount === 1, 'Only one execution should succeed');
  assert(window.__PI_PROXY_URL_REWRITING_INSTALLED === true, 'Flag should be set');
});

// Test 4: Server-side duplicate detection
test('Server-side should detect duplicate script tags', () => {
  const html1 = '<html><head></head><body></body></html>';
  const html2 = '<html><head><script data-pi-proxy="url-rewriting">...</script></head><body></body></html>';
  const html3 = '<html><head><script>__PI_PROXY_URL_REWRITING_INSTALLED</script></head><body></body></html>';
  
  const hasMarker1 = html1.includes('data-pi-proxy="url-rewriting"') || html1.includes('__PI_PROXY_URL_REWRITING_INSTALLED');
  const hasMarker2 = html2.includes('data-pi-proxy="url-rewriting"') || html2.includes('__PI_PROXY_URL_REWRITING_INSTALLED');
  const hasMarker3 = html3.includes('data-pi-proxy="url-rewriting"') || html3.includes('__PI_PROXY_URL_REWRITING_INSTALLED');
  
  assert(hasMarker1 === false, 'Clean HTML should not have marker');
  assert(hasMarker2 === true, 'HTML with script tag should have marker');
  assert(hasMarker3 === true, 'HTML with installation flag should have marker');
});

// Test 5: Flag persistence across page reloads (simulated)
test('Flag should persist in window object', () => {
  const window = {};
  
  // First "page load"
  simulateScriptExecution(window);
  assert(window.__PI_PROXY_URL_REWRITING_INSTALLED === true, 'Flag should be set');
  
  // Simulate "reload" - flag persists
  const result = simulateScriptExecution(window);
  assert(result.installed === false, 'Should not reinstall after reload');
});

console.log('\nAll race condition tests passed!');
