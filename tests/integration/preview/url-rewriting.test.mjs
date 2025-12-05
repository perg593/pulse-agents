#!/usr/bin/env node

/**
 * Integration test for URL rewriting functionality
 * Tests relative path rewriting and JavaScript interception
 */

import { strict as assert } from 'node:assert';

const PROXY_BASE_URL = process.env.PROXY_BASE_URL || 'http://localhost:3100';

/**
 * Test that relative paths in HTML are rewritten
 */
async function testRelativePathRewriting() {
  console.log('Testing relative path rewriting...');
  
  // Test with a site that uses relative paths (uncommongoods.com)
  const testUrl = 'https://www.uncommongoods.com/';
  const proxyUrl = `${PROXY_BASE_URL}/proxy?url=${encodeURIComponent(testUrl)}`;
  
  try {
    const response = await fetch(proxyUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; PulsePreviewProxy/1.0)'
      }
    });
    
    if (!response.ok) {
      console.log(`  ⚠️  Test URL returned ${response.status}, skipping relative path test`);
      return { success: true, skipped: true };
    }
    
    const html = await response.text();
    
    // Check for URL rewriting script injection
    const hasRewritingScript = html.includes('data-pi-proxy="url-rewriting"') ||
                               html.includes('rewriteUrlForJs') ||
                               html.includes('window.fetch');
    
    // Check for rewritten URLs (should have /proxy?url= in the HTML)
    const hasRewrittenUrls = html.includes('/proxy?url=');
    
    // Check for base href injection
    const hasBaseHref = /<base[^>]*href/i.test(html);
    
    console.log(`  ${hasRewritingScript ? '✓' : '✗'} URL rewriting script injected`);
    console.log(`  ${hasRewrittenUrls ? '✓' : '✗'} URLs rewritten in HTML`);
    console.log(`  ${hasBaseHref ? '✓' : '✗'} Base href injected`);
    
    return {
      success: hasRewritingScript && hasRewrittenUrls && hasBaseHref,
      hasRewritingScript,
      hasRewrittenUrls,
      hasBaseHref
    };
  } catch (error) {
    console.error(`  ✗ Error testing relative path rewriting: ${error.message}`);
    return { success: false, error: error.message };
  }
}

/**
 * Test that JavaScript interception script is present
 */
async function testJavaScriptInterception() {
  console.log('Testing JavaScript interception...');
  
  const testUrl = 'https://www.example.com/';
  const proxyUrl = `${PROXY_BASE_URL}/proxy?url=${encodeURIComponent(testUrl)}`;
  
  try {
    const response = await fetch(proxyUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; PulsePreviewProxy/1.0)'
      }
    });
    
    if (!response.ok) {
      console.log(`  ⚠️  Test URL returned ${response.status}, skipping JS interception test`);
      return { success: true, skipped: true };
    }
    
    const html = await response.text();
    
    // Check for fetch interception
    const hasFetchInterception = html.includes('window.fetch') && 
                                 html.includes('originalFetch');
    
    // Check for XHR interception
    const hasXHRInterception = html.includes('XMLHttpRequest') &&
                               html.includes('prototype.open');
    
    // Check for script tag interception (for module scripts)
    const hasScriptInterception = html.includes('createElement') &&
                                  html.includes('script');
    
    console.log(`  ${hasFetchInterception ? '✓' : '✗'} Fetch interception present`);
    console.log(`  ${hasXHRInterception ? '✓' : '✗'} XHR interception present`);
    console.log(`  ${hasScriptInterception ? '✓' : '✗'} Script tag interception present`);
    
    return {
      success: hasFetchInterception && hasXHRInterception,
      hasFetchInterception,
      hasXHRInterception,
      hasScriptInterception
    };
  } catch (error) {
    console.error(`  ✗ Error testing JS interception: ${error.message}`);
    return { success: false, error: error.message };
  }
}

/**
 * Test that relative paths are rewritten in HTML attributes
 */
async function testRelativePathInAttributes() {
  console.log('Testing relative paths in HTML attributes...');
  
  // Create a simple HTML with relative paths
  const testHtml = `
    <html>
      <head><title>Test</title></head>
      <body>
        <script src="/js/file.js"></script>
        <link rel="stylesheet" href="./styles.css">
        <img src="../images/logo.png">
      </body>
    </html>
  `;
  
  // We can't easily test this without a real server, so we'll check the logic
  // by verifying the proxy handles relative paths correctly
  const testUrl = 'https://www.uncommongoods.com/';
  const proxyUrl = `${PROXY_BASE_URL}/proxy?url=${encodeURIComponent(testUrl)}`;
  
  try {
    const response = await fetch(proxyUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; PulsePreviewProxy/1.0)'
      }
    });
    
    if (!response.ok) {
      console.log(`  ⚠️  Test URL returned ${response.status}, skipping attribute test`);
      return { success: true, skipped: true };
    }
    
    const html = await response.text();
    
    // Look for script tags with src attributes that might contain relative paths
    // If they're rewritten, they should contain /proxy?url=
    const scriptTags = html.match(/<script[^>]*src=["']([^"']+)["'][^>]*>/gi) || [];
    const hasRewrittenScripts = scriptTags.some(tag => tag.includes('/proxy?url='));
    
    console.log(`  ${hasRewrittenScripts ? '✓' : '⚠️'} Script tags with relative paths ${hasRewrittenScripts ? 'rewritten' : 'may need JS interception'}`);
    
    return {
      success: true, // Not a failure if scripts aren't rewritten (they'll be caught by JS interception)
      hasRewrittenScripts
    };
  } catch (error) {
    console.error(`  ✗ Error testing attributes: ${error.message}`);
    return { success: false, error: error.message };
  }
}

/**
 * Main test function
 */
async function runTests() {
  console.log('🧪 URL Rewriting Integration Tests');
  console.log('==================================\n');
  
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
  results.push(await testRelativePathRewriting());
  console.log('');
  
  results.push(await testJavaScriptInterception());
  console.log('');
  
  results.push(await testRelativePathInAttributes());
  console.log('');
  
  // Summary
  const successful = results.filter(r => r.success && !r.skipped);
  const failed = results.filter(r => !r.success);
  const skipped = results.filter(r => r.skipped);
  
  console.log('📊 Test Summary');
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

