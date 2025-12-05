#!/usr/bin/env node

/**
 * Test to verify JavaScript interception script is injected into HTML
 */

import { strict as assert } from 'node:assert';

const PROXY_BASE_URL = process.env.PROXY_BASE_URL || 'http://localhost:3100';

/**
 * Test that script injection is present in HTML response
 */
async function testScriptInjection() {
  console.log('Testing script injection...');
  
  const testUrl = 'https://www.example.com/';
  const proxyUrl = `${PROXY_BASE_URL}/proxy?url=${encodeURIComponent(testUrl)}`;
  
  try {
    const response = await fetch(proxyUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; PulsePreviewProxy/1.0)'
      }
    });
    
    if (!response.ok) {
      console.log(`  ⚠️  Test URL returned ${response.status}, skipping script injection test`);
      return { success: true, skipped: true };
    }
    
    const html = await response.text();
    
    // Check for script tag with data-pi-proxy="url-rewriting"
    const hasScriptTag = html.includes('data-pi-proxy="url-rewriting"') ||
                        html.includes("data-pi-proxy='url-rewriting'");
    
    // Check for key functions in the script
    const hasRewriteFunction = html.includes('rewriteUrlForJs');
    const hasFetchInterception = html.includes('window.fetch') && html.includes('originalFetch');
    const hasXHRInterception = html.includes('XMLHttpRequest') && html.includes('prototype.open');
    const hasScriptInterception = html.includes('createElement') && html.includes('SCRIPT');
    const hasDebugLogging = html.includes('[PI-Proxy]');
    
    // Check script placement (should be early in head)
    const headMatch = html.match(/<head[^>]*>([\s\S]{0,2000})/i);
    const scriptInHead = headMatch && headMatch[1].includes('data-pi-proxy="url-rewriting"');
    
    console.log(`  ${hasScriptTag ? '✓' : '✗'} Script tag present`);
    console.log(`  ${hasRewriteFunction ? '✓' : '✗'} rewriteUrlForJs function present`);
    console.log(`  ${hasFetchInterception ? '✓' : '✗'} Fetch interception code present`);
    console.log(`  ${hasXHRInterception ? '✓' : '✗'} XHR interception code present`);
    console.log(`  ${hasScriptInterception ? '✓' : '✗'} Script tag interception code present`);
    console.log(`  ${hasDebugLogging ? '✓' : '✗'} Debug logging present`);
    console.log(`  ${scriptInHead ? '✓' : '✗'} Script placed in <head>`);
    
    if (!hasScriptTag) {
      console.log('\n  ⚠️  Script tag not found. Checking HTML structure...');
      const headStart = html.indexOf('<head');
      const headEnd = html.indexOf('</head>');
      if (headStart >= 0 && headEnd >= 0) {
        const headContent = html.substring(headStart, headEnd);
        console.log(`  Head content length: ${headContent.length}`);
        console.log(`  First 500 chars of head:`, headContent.substring(0, 500));
      }
    }
    
    return {
      success: hasScriptTag && hasRewriteFunction && hasFetchInterception,
      hasScriptTag,
      hasRewriteFunction,
      hasFetchInterception,
      hasXHRInterception,
      hasScriptInterception,
      hasDebugLogging,
      scriptInHead
    };
  } catch (error) {
    console.error(`  ✗ Error testing script injection: ${error.message}`);
    return { success: false, error: error.message };
  }
}

/**
 * Test with uncommongoods.com specifically
 */
async function testUncommongoodsScriptInjection() {
  console.log('\nTesting script injection with uncommongoods.com...');
  
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
    
    const hasScriptTag = html.includes('data-pi-proxy="url-rewriting"');
    const hasRewriteFunction = html.includes('rewriteUrlForJs');
    
    console.log(`  ${hasScriptTag ? '✓' : '✗'} Script tag present`);
    console.log(`  ${hasRewriteFunction ? '✓' : '✗'} rewriteUrlForJs function present`);
    
    return {
      success: hasScriptTag && hasRewriteFunction,
      hasScriptTag,
      hasRewriteFunction
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
  console.log('🧪 Script Injection Test');
  console.log('========================\n');
  
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
  results.push(await testScriptInjection());
  results.push(await testUncommongoodsScriptInjection());
  
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
    process.exit(1);
  }
  
  console.log('\n✅ All tests passed!');
}

// Run tests
runTests().catch((error) => {
  console.error('❌ Test failed:', error);
  process.exit(1);
});

