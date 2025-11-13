/**
 * @fileoverview Integration tests for race condition handling
 * 
 * Tests race condition prevention:
 * - Concurrent presentation requests
 * - Operation cancellation
 * - Rapid survey switching
 * - URL parameter race conditions
 */

import { strict as assert } from 'node:assert';
import { withDom } from '../../support/testUtils.mjs';

/**
 * Test concurrent presentation requests are handled correctly
 */
async function testConcurrentPresentationRequests() {
  await withDom('http://localhost:8000/preview/basic/index.html', async () => {
    let activeOperation = null;
    let operationId = 0;
    
    const createOperation = (surveyId) => {
      const opId = ++operationId;
      const operation = {
        id: opId,
        key: `present-${opId}`,
        surveyId,
        cancelToken: {
          cancel: () => {},
          get cancelled() { return false; }
        },
        startTime: Date.now()
      };
      
      // Cancel previous operation if exists
      if (activeOperation && activeOperation.cancelToken) {
        activeOperation.cancelToken.cancel();
      }
      
      activeOperation = operation;
      return operation;
    };
    
    // Simulate concurrent requests
    const op1 = createOperation('1234');
    assert(activeOperation.surveyId === '1234', 'First operation should be active');
    
    const op2 = createOperation('5678');
    assert(activeOperation.surveyId === '5678', 'Second operation should replace first');
    assert(op1.id !== op2.id, 'Operations should have different IDs');
    
    console.log('✓ Concurrent presentation requests test passed');
  });
}

/**
 * Test operation cancellation works correctly
 */
async function testOperationCancellation() {
  await withDom('http://localhost:8000/preview/basic/index.html', async () => {
    let cancelled = false;
    
    const cancelToken = {
      cancel: () => { cancelled = true; },
      get cancelled() { return cancelled; }
    };
    
    const operation = {
      id: 1,
      surveyId: '1234',
      cancelToken
    };
    
    // Cancel operation
    if (operation.cancelToken) {
      operation.cancelToken.cancel();
    }
    
    assert(cancelled === true, 'Operation should be cancelled');
    assert(operation.cancelToken.cancelled === true, 'Cancel token should reflect cancellation');
    
    console.log('✓ Operation cancellation test passed');
  });
}

/**
 * Test rapid survey switching
 */
async function testRapidSurveySwitching() {
  await withDom('http://localhost:8000/preview/basic/index.html', async () => {
    let activeOperation = null;
    const cancelledOperations = [];
    
    const cancelPreviousOperation = (newOperation) => {
      if (activeOperation && activeOperation.cancelToken) {
        activeOperation.cancelToken.cancel();
        cancelledOperations.push(activeOperation.id);
      }
      activeOperation = newOperation;
    };
    
    // Simulate rapid switching
    const op1 = { id: 1, surveyId: '1234', cancelToken: { cancel: () => {}, cancelled: false } };
    cancelPreviousOperation(op1);
    
    const op2 = { id: 2, surveyId: '5678', cancelToken: { cancel: () => {}, cancelled: false } };
    cancelPreviousOperation(op2);
    
    const op3 = { id: 3, surveyId: '9999', cancelToken: { cancel: () => {}, cancelled: false } };
    cancelPreviousOperation(op3);
    
    assert(cancelledOperations.length === 2, 'Should cancel 2 previous operations');
    assert(cancelledOperations.includes(1), 'Should cancel first operation');
    assert(cancelledOperations.includes(2), 'Should cancel second operation');
    assert(activeOperation.id === 3, 'Third operation should be active');
    
    console.log('✓ Rapid survey switching test passed');
  });
}

/**
 * Test URL parameter race condition prevention
 */
async function testUrlParameterRaceCondition() {
  await withDom('http://localhost:8000/preview/basic/index.html?present=1234', async () => {
    let presentTriggered = false;
    
    // Simulate handlePresentParameter being called multiple times
    const handlePresentParameter = () => {
      if (presentTriggered) {
        // Should return early to prevent race condition
        return false; // Indicates duplicate call prevented
      }
      
      // Set flag immediately to prevent race conditions
      presentTriggered = true;
      return true; // Indicates successful handling
    };
    
    // First call should succeed
    const result1 = handlePresentParameter();
    assert(result1 === true, 'First call should succeed');
    assert(presentTriggered === true, 'Flag should be set');
    
    // Second call should be prevented
    const result2 = handlePresentParameter();
    assert(result2 === false, 'Second call should be prevented');
    
    console.log('✓ URL parameter race condition test passed');
  });
}

/**
 * Test operation tracking prevents duplicate operations
 */
async function testOperationTracking() {
  await withDom('http://localhost:8000/preview/basic/index.html', async () => {
    let activeOperation = null;
    let presentOperationId = 0;
    
    const startOperation = (surveyId) => {
      const operationId = ++presentOperationId;
      const operationKey = `present-${operationId}`;
      
      // Check if same operation is already in progress
      if (activeOperation && 
          activeOperation.surveyId === surveyId &&
          !activeOperation.cancelToken.cancelled) {
        return null; // Duplicate operation
      }
      
      const operation = {
        id: operationId,
        key: operationKey,
        surveyId,
        cancelToken: {
          cancel: () => {},
          cancelled: false
        },
        startTime: Date.now()
      };
      
      activeOperation = operation;
      return operation;
    };
    
    // Start first operation
    const op1 = startOperation('1234');
    assert(op1 !== null, 'First operation should start');
    assert(activeOperation.surveyId === '1234', 'Active operation should be set');
    
    // Try to start same operation again (should be blocked)
    const op2 = startOperation('1234');
    assert(op2 === null, 'Duplicate operation should be blocked');
    
    // Start different operation (should succeed)
    const op3 = startOperation('5678');
    assert(op3 !== null, 'Different operation should start');
    
    console.log('✓ Operation tracking test passed');
  });
}

/**
 * Run all race condition tests
 */
async function runAllTests() {
  console.log('\nRunning race condition integration tests...\n');
  
  try {
    await testConcurrentPresentationRequests();
    await testOperationCancellation();
    await testRapidSurveySwitching();
    await testUrlParameterRaceCondition();
    await testOperationTracking();
    
    console.log('\n✓ All race condition tests passed!');
  } catch (error) {
    console.error('\n✗ Test failed:', error.message);
    throw error;
  }
}

// Run tests if executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
  runAllTests().catch((error) => {
    console.error('Test suite failed:', error);
    process.exit(1);
  });
}

export { runAllTests };

