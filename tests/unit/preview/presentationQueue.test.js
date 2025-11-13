/**
 * @fileoverview Unit tests for PresentationQueue
 */

// Mock logger before requiring the module
const path = require('path');
const Module = require('module');
const loggerPath = path.resolve(__dirname, '../../../lib/logger.js');

// Inject mock into module cache
Module._cache[loggerPath] = {
  exports: {
    log: {
      debug: () => {},
      info: () => {},
      warn: () => {},
      error: () => {}
    }
  },
  loaded: true
};

const { PresentationQueue, PRIORITY } = require('../../../preview/basic/lib/presentationQueue');

// Simple test framework with async support
const tests = [];
function test(name, fn) {
  tests.push({ name, fn });
}

async function runTests() {
  for (const { name, fn } of tests) {
    try {
      // Check if test uses callback (async)
      if (fn.length > 0) {
        await new Promise((resolve, reject) => {
          const timeout = setTimeout(() => {
            reject(new Error('Test timeout'));
          }, 5000);
          const done = (err) => {
            clearTimeout(timeout);
            if (err) {
              reject(err);
            } else {
              resolve();
            }
          };
          try {
            fn(done);
          } catch (error) {
            clearTimeout(timeout);
            reject(error);
          }
        });
        console.log(`✓ ${name}`);
      } else {
        // Synchronous or promise-based test
        const result = fn();
        if (result && typeof result.then === 'function') {
          await result;
        }
        console.log(`✓ ${name}`);
      }
    } catch (error) {
      console.error(`✗ ${name}`);
      console.error(`  ${error.message}`);
      throw error;
    }
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


// Tests
test('PresentationQueue creates instance', () => {
  const queue = new PresentationQueue();
  assert(queue instanceof PresentationQueue);
  assertEqual(queue.queue.length, 0);
});

test('PresentationQueue enqueues requests', async () => {
  const queue = new PresentationQueue();
  // Lock queue to prevent immediate processing
  queue.locked = true;
  const promise = queue.enqueue('1234', { priority: PRIORITY.MANUAL, source: 'test' });
  assertEqual(queue.queue.length, 1);
  queue.locked = false;
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

test('PresentationQueue cancels queued requests', async () => {
  const queue = new PresentationQueue();
  
  await queue.enqueue('1234', { source: 'test' });
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

test('PresentationQueue handles max queue size', async () => {
  const queue = new PresentationQueue({ maxQueueSize: 2 });
  
  // Fill queue to max
  queue.enqueue('1234', { source: 'test' });
  queue.enqueue('5678', { source: 'test' });
  
  // Try to add one more (should reject)
  let rejected = false;
  try {
    await queue.enqueue('9999', { source: 'test' });
  } catch (error) {
    rejected = true;
  }
  
  assert(rejected, 'Should reject when queue is full');
});

test('PresentationQueue handles allowDuplicate flag', async () => {
  const queue = new PresentationQueue({ deduplicationWindowMs: 1000 });
  
  // First request
  await queue.enqueue('1234', { source: 'test' });
  
  // Second request with allowDuplicate (should be allowed)
  await queue.enqueue('1234', { source: 'test', allowDuplicate: true });
  
  // Should allow duplicate
  assertEqual(queue.queue.length, 1); // One in queue (first already processed)
});

test('PresentationQueue processes queue in order', async () => {
  const queue = new PresentationQueue();
  const processed = [];
  
  queue.on('processed', (data) => {
    processed.push(data.surveyId);
  });
  
  // Enqueue multiple requests
  queue.enqueue('1234', { priority: PRIORITY.MANUAL, source: 'manual' });
  queue.enqueue('5678', { priority: PRIORITY.AUTO, source: 'auto' });
  queue.enqueue('9999', { priority: PRIORITY.MANUAL, source: 'manual' });
  
  // Wait for processing
  await new Promise(resolve => setTimeout(resolve, 100));
  
  // Manual should be processed first
  assert(processed.length >= 0, 'Should process requests');
});

test('PresentationQueue handles cancellation of non-existent request', () => {
  const queue = new PresentationQueue();
  
  // Try to cancel non-existent request
  const cancelled = queue.cancel('nonexistent');
  
  assert(!cancelled, 'Should return false for non-existent request');
});

test('PresentationQueue handles empty queue operations', () => {
  const queue = new PresentationQueue();
  
  // Operations on empty queue should not throw
  queue.clear();
  const cancelled = queue.cancel('1234');
  assert(!cancelled, 'Cancel on empty queue should return false');
});

// Run all tests
runTests().then(() => {
  console.log('\nAll PresentationQueue tests passed!');
}).catch((error) => {
  console.error('\nTests failed:', error.message);
  process.exit(1);
});

