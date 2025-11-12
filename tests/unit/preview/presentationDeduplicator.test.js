/**
 * @fileoverview Unit tests for PresentationDeduplicator
 */

const { PresentationDeduplicator, SOURCE } = require('../../../preview/basic/lib/presentationDeduplicator');

// Simple test framework
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

function assert(condition, message) {
  if (!condition) {
    throw new Error(message || 'Assertion failed');
  }
}

function assertEqual(actual, expected, message) {
  if (actual !== expected) {
    throw new Error(message || `Expected ${expected}, got ${actual}`);
  }
}

// Mock logger
jest.mock('../../../lib/logger', () => ({
  log: {
    debug: () => {},
    info: () => {},
    warn: () => {},
    error: () => {}
  }
}));

// Tests
test('PresentationDeduplicator creates instance', () => {
  const deduplicator = new PresentationDeduplicator({ persistState: false });
  assert(deduplicator instanceof PresentationDeduplicator);
});

test('PresentationDeduplicator detects duplicates within cooldown', () => {
  const deduplicator = new PresentationDeduplicator({
    cooldownMs: 1000,
    persistState: false
  });
  
  // Record first presentation
  deduplicator.recordPresentation('1234', SOURCE.MANUAL);
  
  // Check immediately (should be duplicate)
  const result = deduplicator.checkDuplicate('1234', { source: SOURCE.AUTO });
  assert(result.isDuplicate);
});

test('PresentationDeduplicator allows presentations after cooldown', (done) => {
  const deduplicator = new PresentationDeduplicator({
    cooldownMs: 100,
    persistState: false
  });
  
  // Record first presentation
  deduplicator.recordPresentation('1234', SOURCE.MANUAL);
  
  // Check after cooldown
  setTimeout(() => {
    const result = deduplicator.checkDuplicate('1234', { source: SOURCE.AUTO });
    assert(!result.isDuplicate);
    done();
  }, 150);
});

test('PresentationDeduplicator respects force flag', () => {
  const deduplicator = new PresentationDeduplicator({
    cooldownMs: 1000,
    persistState: false
  });
  
  deduplicator.recordPresentation('1234', SOURCE.MANUAL);
  
  const result = deduplicator.checkDuplicate('1234', {
    source: SOURCE.AUTO,
    force: true
  });
  
  assert(!result.isDuplicate);
});

test('PresentationDeduplicator allows manual to override auto', () => {
  const deduplicator = new PresentationDeduplicator({
    cooldownMs: 1000,
    persistState: false
  });
  
  deduplicator.recordPresentation('1234', SOURCE.AUTO);
  
  const result = deduplicator.checkDuplicate('1234', {
    source: SOURCE.MANUAL
  });
  
  assert(!result.isDuplicate);
});

test('PresentationDeduplicator clears survey history', () => {
  const deduplicator = new PresentationDeduplicator({ persistState: false });
  
  deduplicator.recordPresentation('1234', SOURCE.MANUAL);
  assert(deduplicator.getHistory('1234') !== null);
  
  deduplicator.clearSurvey('1234');
  assert(deduplicator.getHistory('1234') === null);
});

test('PresentationDeduplicator clears all history', () => {
  const deduplicator = new PresentationDeduplicator({ persistState: false });
  
  deduplicator.recordPresentation('1234', SOURCE.MANUAL);
  deduplicator.recordPresentation('5678', SOURCE.AUTO);
  
  deduplicator.clearAll();
  
  assert(deduplicator.getHistory('1234') === null);
  assert(deduplicator.getHistory('5678') === null);
});

test('PresentationDeduplicator respects allowDuplicate flag', () => {
  const deduplicator = new PresentationDeduplicator({
    cooldownMs: 1000,
    persistState: false
  });
  
  deduplicator.recordPresentation('1234', SOURCE.MANUAL);
  
  const result = deduplicator.checkDuplicate('1234', {
    source: SOURCE.AUTO,
    allowDuplicate: true
  });
  
  assert(!result.isDuplicate, 'allowDuplicate flag should bypass deduplication');
});

test('PresentationDeduplicator allows URL param to override auto', () => {
  const deduplicator = new PresentationDeduplicator({
    cooldownMs: 1000,
    persistState: false
  });
  
  deduplicator.recordPresentation('1234', SOURCE.AUTO);
  
  const result = deduplicator.checkDuplicate('1234', {
    source: SOURCE.URL_PARAM
  });
  
  assert(!result.isDuplicate, 'URL param should override auto');
});

test('PresentationDeduplicator allows URL param to override behavior', () => {
  const deduplicator = new PresentationDeduplicator({
    cooldownMs: 1000,
    persistState: false
  });
  
  deduplicator.recordPresentation('1234', SOURCE.BEHAVIOR);
  
  const result = deduplicator.checkDuplicate('1234', {
    source: SOURCE.URL_PARAM
  });
  
  assert(!result.isDuplicate, 'URL param should override behavior');
});

test('PresentationDeduplicator allows behavior to override auto', () => {
  const deduplicator = new PresentationDeduplicator({
    cooldownMs: 1000,
    persistState: false
  });
  
  deduplicator.recordPresentation('1234', SOURCE.AUTO);
  
  const result = deduplicator.checkDuplicate('1234', {
    source: SOURCE.BEHAVIOR
  });
  
  assert(!result.isDuplicate, 'Behavior should override auto');
});

test('PresentationDeduplicator does not allow auto to override manual', () => {
  const deduplicator = new PresentationDeduplicator({
    cooldownMs: 1000,
    persistState: false
  });
  
  deduplicator.recordPresentation('1234', SOURCE.MANUAL);
  
  const result = deduplicator.checkDuplicate('1234', {
    source: SOURCE.AUTO
  });
  
  assert(result.isDuplicate, 'Auto should not override manual');
});

test('PresentationDeduplicator does not allow auto to override URL param', () => {
  const deduplicator = new PresentationDeduplicator({
    cooldownMs: 1000,
    persistState: false
  });
  
  deduplicator.recordPresentation('1234', SOURCE.URL_PARAM);
  
  const result = deduplicator.checkDuplicate('1234', {
    source: SOURCE.AUTO
  });
  
  assert(result.isDuplicate, 'Auto should not override URL param');
});

test('PresentationDeduplicator returns history entry', () => {
  const deduplicator = new PresentationDeduplicator({ persistState: false });
  
  deduplicator.recordPresentation('1234', SOURCE.MANUAL);
  
  const history = deduplicator.getHistory('1234');
  assert(history !== null, 'Should return history entry');
  assert(history.source === SOURCE.MANUAL, 'History should have correct source');
  assert(typeof history.timestamp === 'number', 'History should have timestamp');
});

test('PresentationDeduplicator returns null for non-existent history', () => {
  const deduplicator = new PresentationDeduplicator({ persistState: false });
  
  const history = deduplicator.getHistory('nonexistent');
  assert(history === null, 'Should return null for non-existent history');
});

test('PresentationDeduplicator handles empty survey ID gracefully', () => {
  const deduplicator = new PresentationDeduplicator({ persistState: false });
  
  // Should not throw on empty string
  try {
    deduplicator.recordPresentation('', SOURCE.MANUAL);
    deduplicator.checkDuplicate('', { source: SOURCE.AUTO });
  } catch (error) {
    // Expected to throw validation error
    assert(error.message.includes('surveyId'), 'Should validate surveyId');
  }
});

console.log('\nAll PresentationDeduplicator tests passed!');

