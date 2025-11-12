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

console.log('\nAll PresentationDeduplicator tests passed!');

