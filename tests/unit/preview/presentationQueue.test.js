/**
 * @fileoverview Unit tests for PresentationQueue
 */

const { PresentationQueue, PRIORITY } = require('../../../preview/basic/lib/presentationQueue');

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
test('PresentationQueue creates instance', () => {
  const queue = new PresentationQueue();
  assert(queue instanceof PresentationQueue);
  assertEqual(queue.queue.length, 0);
});

test('PresentationQueue enqueues requests', async () => {
  const queue = new PresentationQueue();
  const promise = queue.enqueue('1234', { priority: PRIORITY.MANUAL, source: 'test' });
  assertEqual(queue.queue.length, 1);
  await promise;
});

test('PresentationQueue respects priority (manual before auto)', async () => {
  const queue = new PresentationQueue();
  
  // Enqueue auto first
  queue.enqueue('auto1', { priority: PRIORITY.AUTO, source: 'auto' });
  
  // Enqueue manual
  queue.enqueue('manual1', { priority: PRIORITY.MANUAL, source: 'manual' });
  
  // Enqueue another auto
  queue.enqueue('auto2', { priority: PRIORITY.AUTO, source: 'auto' });
  
  // Manual should be first
  assertEqual(queue.queue[0].surveyId, 'manual1');
  assertEqual(queue.queue[1].surveyId, 'auto1');
  assertEqual(queue.queue[2].surveyId, 'auto2');
});

test('PresentationQueue deduplicates requests', async () => {
  const queue = new PresentationQueue({ deduplicationWindowMs: 1000 });
  
  // First request
  await queue.enqueue('1234', { source: 'test' });
  
  // Second request within window (should be rejected)
  let rejected = false;
  try {
    await queue.enqueue('1234', { source: 'test' });
  } catch (error) {
    rejected = true;
  }
  
  // Should be deduplicated
  assert(queue.isDuplicate('1234'));
});

test('PresentationQueue allows duplicates with force flag', async () => {
  const queue = new PresentationQueue({ deduplicationWindowMs: 1000 });
  
  // First request
  await queue.enqueue('1234', { source: 'test' });
  
  // Second request with force (should be allowed)
  await queue.enqueue('1234', { source: 'test', force: true });
  
  assertEqual(queue.queue.length, 1); // One in queue (first already processed)
});

test('PresentationQueue cancels queued requests', () => {
  const queue = new PresentationQueue();
  
  queue.enqueue('1234', { source: 'test' });
  assertEqual(queue.queue.length, 1);
  
  const cancelled = queue.cancel('1234');
  assert(cancelled);
  assertEqual(queue.queue.length, 0);
});

test('PresentationQueue clears all requests', () => {
  const queue = new PresentationQueue();
  
  queue.enqueue('1234', { source: 'test' });
  queue.enqueue('5678', { source: 'test' });
  assertEqual(queue.queue.length, 2);
  
  queue.clear();
  assertEqual(queue.queue.length, 0);
});

test('PresentationQueue emits events', (done) => {
  const queue = new PresentationQueue();
  let queuedEvent = false;
  
  queue.on('queued', (data) => {
    queuedEvent = true;
    assertEqual(data.surveyId, '1234');
    done();
  });
  
  queue.enqueue('1234', { source: 'test' });
});

console.log('\nAll PresentationQueue tests passed!');

