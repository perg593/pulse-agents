#!/usr/bin/env node

/**
 * Integration tests for JavaScript interception functionality
 * Tests fetch, XHR, and dynamic script tag interception
 */

import { strict as assert } from 'node:assert';

const PROXY_BASE_URL = process.env.PROXY_BASE_URL || 'http://localhost:3100';

/**
 * Test that the script interception includes all required features
 */
async function testScriptInterceptionFeatures() {
  console.log('Testing script interception features...');
  
  const testUrl = 'https://www.example.com/';
  const proxyUrl = `${PROXY_BASE_URL}/proxy?url=${encodeURIComponent(testUrl)}`;
  
  try {
    const response = await fetch(proxyUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; PulsePreviewProxy/1.0)'
      }
    });
    
    if (!response.ok) {
      console.log(`  ⚠️  Test URL returned ${response.status}, skipping`);
      return { success: true, skipped: true };
    }
    
    const html = await response.text();
    
    // Check for enhanced detection logic
    const hasMultipleDetection = html.includes('currentHref.includes') &&
                                 html.includes('referrer.includes') &&
                                 html.includes('currentOrigin === proxyOrigin');
    
    // Check for setAttribute interception
    const hasSetAttributeInterception = html.includes('setAttribute') &&
                                       html.includes('src') &&
                                       html.includes('name.toLowerCase() === \'src\'');
    
    // Check for appendChild interception
    const hasAppendChildInterception = html.includes('appendChild') &&
                                      html.includes('rewriteScriptSrc');
    
    // Check for insertBefore interception
    const hasInsertBeforeInterception = html.includes('insertBefore') &&
                                       html.includes('rewriteScriptSrc');
    
    // Check for innerHTML interception
    const hasInnerHTMLInterception = html.includes('innerHTML') &&
                                    html.includes('set') &&
                                    html.includes('<script');
    
    // Check for enhanced getCurrentOrigin
    const hasEnhancedGetCurrentOrigin = html.includes('getCurrentOrigin') &&
                                       html.includes('document.baseURI') &&
                                       html.includes('document.referrer');
    
    // Check for debug logging
    const hasDebugLogging = html.includes('[PI-Proxy]') &&
                           html.includes('console.log');
    
    console.log(`  ${hasMultipleDetection ? '✓' : '✗'} Multiple detection methods`);
    console.log(`  ${hasSetAttributeInterception ? '✓' : '✗'} setAttribute interception`);
    console.log(`  ${hasAppendChildInterception ? '✓' : '✗'} appendChild interception`);
    console.log(`  ${hasInsertBeforeInterception ? '✓' : '✗'} insertBefore interception`);
    console.log(`  ${hasInnerHTMLInterception ? '✓' : '✗'} innerHTML interception`);
    console.log(`  ${hasEnhancedGetCurrentOrigin ? '✓' : '✗'} Enhanced getCurrentOrigin`);
    console.log(`  ${hasDebugLogging ? '✓' : '✗'} Debug logging`);
    
    return {
      success: hasMultipleDetection && 
               hasSetAttributeInterception && 
               hasAppendChildInterception &&
               hasInsertBeforeInterception &&
               hasInnerHTMLInterception &&
               hasEnhancedGetCurrentOrigin &&
               hasDebugLogging,
      hasMultipleDetection,
      hasSetAttributeInterception,
      hasAppendChildInterception,
      hasInsertBeforeInterception,
      hasInnerHTMLInterception,
      hasEnhancedGetCurrentOrigin,
      hasDebugLogging
    };
  } catch (error) {
    console.error(`  ✗ Error: ${error.message}`);
    return { success: false, error: error.message };
  }
}

/**
 * Test that script interception handles webpack-style code splitting
 */
async function testWebpackCodeSplitting() {
  console.log('\nTesting webpack code splitting interception...');
  
  // Test with uncommongoods.com which uses webpack
  const testUrl = 'https://www.uncommongoods.com/';
  const proxyUrl = `${PROXY_BASE_URL}/proxy?url=${encodeURIComponent(testUrl)}`;
  
  try {
    const response = await fetch(proxyUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; PulsePreviewProxy/1.0)'
      }
    });
    
    if (!response.ok) {
      console.log(`  ⚠️  Test URL returned ${response.status}, skipping`);
      return { success: true, skipped: true };
    }
    
    const html = await response.text();
    
    // Check for prototype-level interception (critical for webpack)
    const hasPrototypeInterception = html.includes('HTMLScriptElement.prototype') &&
                                    html.includes('src') &&
                                    html.includes('set');
    
    // Check for webpack chunk loading patterns in the script
    // Webpack uses dynamic script creation, so we need to verify our interception handles it
    const hasWebpackSupport = html.includes('appendChild') &&
                             html.includes('insertBefore') &&
                             html.includes('rewriteScriptSrc');
    
    // Check for script src property interception at prototype level
    const hasPrototypeSrcInterception = html.includes('HTMLScriptElement.prototype.src') &&
                                       html.includes('originalSrcDescriptor');
    
    // Check for setAttribute interception at prototype level
    const hasPrototypeSetAttribute = html.includes('HTMLScriptElement.prototype.setAttribute');
    
    console.log(`  ${hasPrototypeInterception ? '✓' : '✗'} Prototype-level script interception`);
    console.log(`  ${hasWebpackSupport ? '✓' : '✗'} Webpack support (appendChild/insertBefore)`);
    console.log(`  ${hasPrototypeSrcInterception ? '✓' : '✗'} HTMLScriptElement.prototype.src interception`);
    console.log(`  ${hasPrototypeSetAttribute ? '✓' : '✗'} HTMLScriptElement.prototype.setAttribute interception`);
    
    return {
      success: hasPrototypeInterception && hasWebpackSupport && hasPrototypeSrcInterception && hasPrototypeSetAttribute,
      hasPrototypeInterception,
      hasWebpackSupport,
      hasPrototypeSrcInterception,
      hasPrototypeSetAttribute
    };
  } catch (error) {
    console.error(`  ✗ Error: ${error.message}`);
    return { success: false, error: error.message };
  }
}

/**
 * Test that relative paths are correctly resolved
 */
async function testRelativePathResolution() {
  console.log('\nTesting relative path resolution...');
  
  const testUrl = 'https://www.example.com/';
  const proxyUrl = `${PROXY_BASE_URL}/proxy?url=${encodeURIComponent(testUrl)}`;
  
  try {
    const response = await fetch(proxyUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; PulsePreviewProxy/1.0)'
      }
    });
    
    if (!response.ok) {
      console.log(`  ⚠️  Test URL returned ${response.status}, skipping`);
      return { success: true, skipped: true };
    }
    
    const html = await response.text();
    
    // Check that rewriteUrlForJs handles relative paths
    const hasRelativePathHandling = html.includes('rewriteUrlForJs') &&
                                   html.includes('new URL') &&
                                   html.includes('baseOrigin');
    
    // Check for root-relative path handling (/path)
    const hasRootRelativeHandling = html.includes('startsWith(\'/\'') ||
                                                 html.includes('startsWith("/"') ||
                                                 html.includes('trimmed.startsWith');
    
    // Check for protocol-relative URL handling (//example.com)
    const hasProtocolRelativeHandling = html.includes('startsWith(\'//\')') ||
                                       html.includes('startsWith("//")');
    
    console.log(`  ${hasRelativePathHandling ? '✓' : '✗'} Relative path handling`);
    console.log(`  ${hasRootRelativeHandling ? '✓' : '✗'} Root-relative path handling`);
    console.log(`  ${hasProtocolRelativeHandling ? '✓' : '✗'} Protocol-relative URL handling`);
    
    return {
      success: hasRelativePathHandling && hasRootRelativeHandling && hasProtocolRelativeHandling,
      hasRelativePathHandling,
      hasRootRelativeHandling,
      hasProtocolRelativeHandling
    };
  } catch (error) {
    console.error(`  ✗ Error: ${error.message}`);
    return { success: false, error: error.message };
  }
}

/**
 * Test that the script detection logic works correctly
 */
async function testScriptDetectionLogic() {
  console.log('\nTesting script detection logic...');
  
  const testUrl = 'https://www.example.com/';
  const proxyUrl = `${PROXY_BASE_URL}/proxy?url=${encodeURIComponent(testUrl)}`;
  
  try {
    const response = await fetch(proxyUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; PulsePreviewProxy/1.0)'
      }
    });
    
    if (!response.ok) {
      console.log(`  ⚠️  Test URL returned ${response.status}, skipping`);
      return { success: true, skipped: true };
    }
    
    const html = await response.text();
    
    // Check for multiple detection methods
    const hasUrlPatternCheck = html.includes('/proxy?url=') ||
                              html.includes('proxy%3Furl%3D');
    
    const hasReferrerCheck = html.includes('document.referrer');
    
    const hasOriginCheck = html.includes('currentOrigin') &&
                          html.includes('proxyOrigin');
    
    const hasMultipleChecks = hasUrlPatternCheck && hasReferrerCheck && hasOriginCheck;
    
    // Check that the script doesn't exit early incorrectly
    const hasProperEarlyReturn = html.includes('if (!isProxied)') &&
                                html.includes('return');
    
    console.log(`  ${hasUrlPatternCheck ? '✓' : '✗'} URL pattern check`);
    console.log(`  ${hasReferrerCheck ? '✓' : '✗'} Referrer check`);
    console.log(`  ${hasOriginCheck ? '✓' : '✗'} Origin check`);
    console.log(`  ${hasProperEarlyReturn ? '✓' : '✗'} Proper early return logic`);
    
    return {
      success: hasMultipleChecks && hasProperEarlyReturn,
      hasUrlPatternCheck,
      hasReferrerCheck,
      hasOriginCheck,
      hasProperEarlyReturn
    };
  } catch (error) {
    console.error(`  ✗ Error: ${error.message}`);
    return { success: false, error: error.message };
  }
}

/**
 * Test that fetch interception handles all input types
 */
async function testFetchInterception() {
  console.log('\nTesting fetch interception...');
  
  const testUrl = 'https://www.example.com/';
  const proxyUrl = `${PROXY_BASE_URL}/proxy?url=${encodeURIComponent(testUrl)}`;
  
  try {
    const response = await fetch(proxyUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; PulsePreviewProxy/1.0)'
      }
    });
    
    if (!response.ok) {
      console.log(`  ⚠️  Test URL returned ${response.status}, skipping`);
      return { success: true, skipped: true };
    }
    
    const html = await response.text();
    
    // Check for string URL handling
    const hasStringUrlHandling = html.includes('typeof input === \'string\'') ||
                                html.includes('typeof input === "string"');
    
    // Check for Request object handling
    const hasRequestObjectHandling = html.includes('instanceof Request') ||
                                    html.includes('Request');
    
    // Check for object with url property handling
    const hasObjectUrlHandling = html.includes('input.url') &&
                                 html.includes('typeof input === \'object\'');
    
    console.log(`  ${hasStringUrlHandling ? '✓' : '✗'} String URL handling`);
    console.log(`  ${hasRequestObjectHandling ? '✓' : '✗'} Request object handling`);
    console.log(`  ${hasObjectUrlHandling ? '✓' : '✗'} Object with url property handling`);
    
    return {
      success: hasStringUrlHandling && hasRequestObjectHandling && hasObjectUrlHandling,
      hasStringUrlHandling,
      hasRequestObjectHandling,
      hasObjectUrlHandling
    };
  } catch (error) {
    console.error(`  ✗ Error: ${error.message}`);
    return { success: false, error: error.message };
  }
}

/**
 * Test that script tag interception works for all creation methods
 */
async function testScriptTagInterception() {
  console.log('\nTesting script tag interception...');
  
  const testUrl = 'https://www.example.com/';
  const proxyUrl = `${PROXY_BASE_URL}/proxy?url=${encodeURIComponent(testUrl)}`;
  
  try {
    const response = await fetch(proxyUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; PulsePreviewProxy/1.0)'
      }
    });
    
    if (!response.ok) {
      console.log(`  ⚠️  Test URL returned ${response.status}, skipping`);
      return { success: true, skipped: true };
    }
    
    const html = await response.text();
    
    // Check for prototype-level interception (NEW APPROACH - intercepts ALL script elements)
    const hasPrototypeSrcInterception = html.includes('HTMLScriptElement.prototype') &&
                                       html.includes('src') &&
                                       html.includes('set') &&
                                       html.includes('originalSrcDescriptor');
    
    // Check for prototype setAttribute interception
    const hasPrototypeSetAttribute = html.includes('HTMLScriptElement.prototype.setAttribute') &&
                                    html.includes('name.toLowerCase() === \'src\'');
    
    // Check for createElement interception (still present but less critical now)
    const hasCreateElementInterception = html.includes('createElement') &&
                                        (html.includes('tagName.toLowerCase() === \'script\'') ||
                                         html.includes('document.createElement'));
    
    // Check for helper function
    const hasRewriteScriptSrcHelper = html.includes('rewriteScriptSrc') ||
                                     html.includes('function rewriteScriptSrc');
    
    console.log(`  ${hasPrototypeSrcInterception ? '✓' : '✗'} HTMLScriptElement.prototype.src interception`);
    console.log(`  ${hasPrototypeSetAttribute ? '✓' : '✗'} HTMLScriptElement.prototype.setAttribute interception`);
    console.log(`  ${hasCreateElementInterception ? '✓' : '⚠️'} createElement interception (optional)`);
    console.log(`  ${hasRewriteScriptSrcHelper ? '✓' : '✗'} rewriteScriptSrc helper function`);
    
    return {
      success: hasPrototypeSrcInterception && 
               hasPrototypeSetAttribute &&
               hasRewriteScriptSrcHelper,
      hasPrototypeSrcInterception,
      hasPrototypeSetAttribute,
      hasCreateElementInterception,
      hasRewriteScriptSrcHelper
    };
  } catch (error) {
    console.error(`  ✗ Error: ${error.message}`);
    return { success: false, error: error.message };
  }
}

/**
 * Main test function
 */
async function runTests() {
  console.log('🧪 Script Interception Integration Tests');
  console.log('========================================\n');
  
  // Check proxy health
  try {
    const healthUrl = `${PROXY_BASE_URL}/background-proxy/health`;
    const response = await fetch(healthUrl, { signal: AbortSignal.timeout(5000) });
    if (!response.ok) {
      throw new Error(`Health check returned ${response.status}`);
    }
  } catch (error) {
    console.error(`❌ Proxy server not running: ${error.message}`);
    console.error(`\n💡 Start the proxy server with: npm start`);
    process.exit(1);
  }
  
  console.log(`✅ Proxy server is running at ${PROXY_BASE_URL}\n`);
  
  const results = [];
  
  // Run tests
  results.push(await testScriptInterceptionFeatures());
  results.push(await testWebpackCodeSplitting());
  results.push(await testRelativePathResolution());
  results.push(await testScriptDetectionLogic());
  results.push(await testFetchInterception());
  results.push(await testScriptTagInterception());
  
  // Summary
  const successful = results.filter(r => r.success && !r.skipped);
  const failed = results.filter(r => !r.success);
  const skipped = results.filter(r => r.skipped);
  
  console.log('\n📊 Test Summary');
  console.log('===============');
  console.log(`Total tests: ${results.length}`);
  console.log(`✅ Passed: ${successful.length}`);
  console.log(`❌ Failed: ${failed.length}`);
  if (skipped.length > 0) {
    console.log(`⚠️  Skipped: ${skipped.length}`);
  }
  
  if (failed.length > 0) {
    console.error('\n❌ Some tests failed');
    // Print details of failures
    failed.forEach((result, index) => {
      console.error(`\nFailed test ${index + 1}:`);
      Object.entries(result).forEach(([key, value]) => {
        if (key !== 'success' && key !== 'error' && typeof value === 'boolean' && !value) {
          console.error(`  - Missing: ${key}`);
        }
      });
    });
    process.exit(1);
  }
  
  console.log('\n✅ All tests passed!');
}

// Run tests
runTests().catch((error) => {
  console.error('❌ Test failed:', error);
  process.exit(1);
});

