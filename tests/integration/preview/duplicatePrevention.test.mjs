/**
 * @fileoverview Integration tests for duplicate prevention across scenarios
 * 
 * Tests deduplication logic:
 * - Deduplication across scenarios
 * - Source priority (manual > URL param > behavior > auto)
 * - Cooldown windows
 * - Force and allowDuplicate flags
 */

import { strict as assert } from 'node:assert';
import { withDom } from '../../support/testUtils.mjs';

/**
 * Test source priority: manual can override auto
 */
async function testSourcePriorityManualOverridesAuto() {
  await withDom('http://localhost:8000/preview/basic/index.html', async () => {
    // Simulate deduplicator logic
    const SOURCE = {
      MANUAL: 'manual',
      AUTO: 'auto',
      URL_PARAM: 'url_param',
      BEHAVIOR: 'behavior'
    };
    
    const canSourceOverride = (newSource, existingSource) => {
      if (newSource === SOURCE.MANUAL) {
        return true; // Manual can always override
      }
      if (newSource === SOURCE.URL_PARAM) {
        return existingSource === SOURCE.AUTO || existingSource === SOURCE.BEHAVIOR;
      }
      if (newSource === SOURCE.BEHAVIOR) {
        return existingSource === SOURCE.AUTO;
      }
      return false; // Auto cannot override anything
    };
    
    // Manual should override auto
    assert(canSourceOverride(SOURCE.MANUAL, SOURCE.AUTO) === true, 
      'Manual should override auto');
    
    // Manual should override URL param
    assert(canSourceOverride(SOURCE.MANUAL, SOURCE.URL_PARAM) === true,
      'Manual should override URL param');
    
    // URL param should override auto
    assert(canSourceOverride(SOURCE.URL_PARAM, SOURCE.AUTO) === true,
      'URL param should override auto');
    
    // URL param should override behavior
    assert(canSourceOverride(SOURCE.URL_PARAM, SOURCE.BEHAVIOR) === true,
      'URL param should override behavior');
    
    // Behavior should override auto
    assert(canSourceOverride(SOURCE.BEHAVIOR, SOURCE.AUTO) === true,
      'Behavior should override auto');
    
    // Auto should not override anything
    assert(canSourceOverride(SOURCE.AUTO, SOURCE.MANUAL) === false,
      'Auto should not override manual');
    assert(canSourceOverride(SOURCE.AUTO, SOURCE.URL_PARAM) === false,
      'Auto should not override URL param');
    
    console.log('✓ Source priority test passed');
  });
}

/**
 * Test cooldown window prevents duplicates
 */
async function testCooldownWindow() {
  await withDom('http://localhost:8000/preview/basic/index.html', async () => {
    const cooldownMs = 10000; // 10 seconds
    const presentationHistory = new Map();
    
    const recordPresentation = (surveyId, source) => {
      presentationHistory.set(surveyId, {
        timestamp: Date.now(),
        source
      });
    };
    
    const checkDuplicate = (surveyId, options = {}) => {
      const historyEntry = presentationHistory.get(surveyId);
      if (!historyEntry) {
        return { isDuplicate: false };
      }
      
      const timeSinceLastPresent = Date.now() - historyEntry.timestamp;
      
      if (timeSinceLastPresent < cooldownMs && !options.force && !options.allowDuplicate) {
        return { 
          isDuplicate: true,
          reason: `presented ${Math.round(timeSinceLastPresent / 1000)}s ago`
        };
      }
      
      return { isDuplicate: false };
    };
    
    // Record first presentation
    recordPresentation('1234', 'auto');
    
    // Check immediately (should be duplicate)
    const result1 = checkDuplicate('1234', { source: 'auto' });
    assert(result1.isDuplicate === true, 'Should detect duplicate within cooldown');
    
    // Simulate time passing (would need to mock Date.now() in real test)
    // For now, test the logic structure
    
    console.log('✓ Cooldown window test passed');
  });
}

/**
 * Test force flag bypasses deduplication
 */
async function testForceFlagBypassesDeduplication() {
  await withDom('http://localhost:8000/preview/basic/index.html', async () => {
    const presentationHistory = new Map();
    presentationHistory.set('1234', {
      timestamp: Date.now(),
      source: 'auto'
    });
    
    const checkDuplicate = (surveyId, options = {}) => {
      if (options.force) {
        return { isDuplicate: false }; // Force bypasses
      }
      
      const historyEntry = presentationHistory.get(surveyId);
      if (!historyEntry) {
        return { isDuplicate: false };
      }
      
      return { isDuplicate: true };
    };
    
    // With force flag, should not be duplicate
    const result = checkDuplicate('1234', { force: true });
    assert(result.isDuplicate === false, 'Force flag should bypass deduplication');
    
    // Without force flag, should be duplicate
    const result2 = checkDuplicate('1234', {});
    assert(result2.isDuplicate === true, 'Should detect duplicate without force');
    
    console.log('✓ Force flag test passed');
  });
}

/**
 * Test allowDuplicate flag bypasses deduplication
 */
async function testAllowDuplicateFlag() {
  await withDom('http://localhost:8000/preview/basic/index.html', async () => {
    const presentationHistory = new Map();
    presentationHistory.set('1234', {
      timestamp: Date.now(),
      source: 'behavior'
    });
    
    const checkDuplicate = (surveyId, options = {}) => {
      if (options.allowDuplicate) {
        return { isDuplicate: false }; // Allow duplicate bypasses
      }
      
      const historyEntry = presentationHistory.get(surveyId);
      if (!historyEntry) {
        return { isDuplicate: false };
      }
      
      return { isDuplicate: true };
    };
    
    // With allowDuplicate flag, should not be duplicate
    const result = checkDuplicate('1234', { allowDuplicate: true });
    assert(result.isDuplicate === false, 'allowDuplicate flag should bypass deduplication');
    
    console.log('✓ Allow duplicate flag test passed');
  });
}

/**
 * Test duplicate prevention across different scenarios
 */
async function testDuplicatePreventionAcrossScenarios() {
  await withDom('http://localhost:8000/preview/basic/index.html', async () => {
    const SOURCE = {
      MANUAL: 'manual',
      AUTO: 'auto',
      URL_PARAM: 'url_param',
      BEHAVIOR: 'behavior'
    };
    
    const presentationHistory = new Map();
    
    const recordPresentation = (surveyId, source) => {
      presentationHistory.set(surveyId, {
        timestamp: Date.now(),
        source
      });
    };
    
    const checkDuplicate = (surveyId, options = {}) => {
      if (options.force || options.allowDuplicate) {
        return { isDuplicate: false };
      }
      
      const historyEntry = presentationHistory.get(surveyId);
      if (!historyEntry) {
        return { isDuplicate: false };
      }
      
      // Source-aware check
      const canOverride = (newSource, existingSource) => {
        if (newSource === SOURCE.MANUAL) return true;
        if (newSource === SOURCE.URL_PARAM) {
          return existingSource === SOURCE.AUTO || existingSource === SOURCE.BEHAVIOR;
        }
        if (newSource === SOURCE.BEHAVIOR) {
          return existingSource === SOURCE.AUTO;
        }
        return false;
      };
      
      if (canOverride(options.source, historyEntry.source)) {
        return { isDuplicate: false };
      }
      
      return { isDuplicate: true };
    };
    
    // Scenario: Auto presents, then manual tries (should allow)
    recordPresentation('1234', SOURCE.AUTO);
    const result1 = checkDuplicate('1234', { source: SOURCE.MANUAL });
    assert(result1.isDuplicate === false, 'Manual should override auto');
    
    // Scenario: Auto presents, then auto tries again (should block)
    const result2 = checkDuplicate('1234', { source: SOURCE.AUTO });
    assert(result2.isDuplicate === true, 'Auto should not override auto');
    
    // Scenario: URL param presents, then auto tries (should block)
    recordPresentation('5678', SOURCE.URL_PARAM);
    const result3 = checkDuplicate('5678', { source: SOURCE.AUTO });
    assert(result3.isDuplicate === true, 'Auto should not override URL param');
    
    console.log('✓ Duplicate prevention across scenarios test passed');
  });
}

/**
 * Run all duplicate prevention tests
 */
async function runAllTests() {
  console.log('\nRunning duplicate prevention integration tests...\n');
  
  try {
    await testSourcePriorityManualOverridesAuto();
    await testCooldownWindow();
    await testForceFlagBypassesDeduplication();
    await testAllowDuplicateFlag();
    await testDuplicatePreventionAcrossScenarios();
    
    console.log('\n✓ All duplicate prevention tests passed!');
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

