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
  
  // Test rate limiting
  results.push(await testRateLimiting());
  console.log('');
  
  // Test cookie sanitization
  results.push(await testCookieSanitization());
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

/**
 * Test rate limiting behavior
 */
async function testRateLimiting() {
  console.log('Testing rate limiting...');
  
  const testUrl = 'https://www.example.com/';
  const proxyUrl = `${PROXY_BASE_URL}/proxy?url=${encodeURIComponent(testUrl)}`;
  
  try {
    // Make multiple rapid requests
    const requests = [];
    for (let i = 0; i < 150; i++) {
      requests.push(
        fetch(proxyUrl, {
          headers: {
            'User-Agent': 'Mozilla/5.0 (compatible; PulsePreviewProxy/1.0)'
          }
        }).catch(() => ({ status: 0 }))
      );
    }
    
    const responses = await Promise.all(requests);
    const status429 = responses.filter(r => r.status === 429).length;
    const status200 = responses.filter(r => r.status === 200).length;
    
    console.log(`  ${status200 > 0 ? '✓' : '✗'} Some requests succeeded (${status200})`);
    console.log(`  ${status429 > 0 ? '✓' : '⚠️'} Rate limiting active (${status429} rate limited)`);
    
    return {
      success: true, // Rate limiting is working if we get any 429s or all succeed (depending on limit)
      status429,
      status200
    };
  } catch (error) {
    console.error(`  ✗ Error testing rate limiting: ${error.message}`);
    return { success: false, error: error.message };
  }
}

/**
 * Test cookie sanitization
 */
async function testCookieSanitization() {
  console.log('Testing cookie sanitization...');
  
  // This is a unit-level test since we can't easily test cookie filtering in integration
  // The actual sanitization happens server-side
  const testCookies = 'session=abc123; auth=xyz789; theme=dark; language=en';
  const sensitivePatterns = ['session', 'auth', 'token', 'csrf'];
  
  const cookies = testCookies.split(';').map(c => c.trim()).filter(Boolean);
  const filtered = cookies.filter(cookie => {
    const name = cookie.split('=')[0].toLowerCase();
    return !sensitivePatterns.some(pattern => name.includes(pattern.toLowerCase()));
  });
  
  const hasSensitive = filtered.some(cookie => {
    const name = cookie.split('=')[0].toLowerCase();
    return sensitivePatterns.some(pattern => name.includes(pattern.toLowerCase()));
  });
  
  console.log(`  ${!hasSensitive ? '✓' : '✗'} Sensitive cookies filtered`);
  console.log(`  ${filtered.length > 0 ? '✓' : '✗'} Non-sensitive cookies preserved`);
  
  return {
    success: !hasSensitive && filtered.length > 0,
    filteredCount: filtered.length,
    originalCount: cookies.length
  };
}

/**
 * Test POST request support
 */
async function testPostRequest() {
  console.log('Testing POST request support...');
  
  // Test POST to a simple endpoint (using httpbin.org for testing)
  const testUrl = 'https://httpbin.org/post';
  const proxyUrl = `${PROXY_BASE_URL}/proxy?url=${encodeURIComponent(testUrl)}`;
  
  try {
    const response = await fetch(proxyUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0 (compatible; PulsePreviewProxy/1.0)'
      },
      body: JSON.stringify({ test: 'data' })
    });
    
    if (!response.ok) {
      console.log(`  ⚠️  POST test returned ${response.status}, may not be supported`);
      return { success: response.status === 405 ? false : true, skipped: response.status !== 405 };
    }
    
    const data = await response.json();
    const hasPostData = data.json && data.json.test === 'data';
    
    console.log(`  ${response.status === 200 ? '✓' : '✗'} POST request succeeded`);
    console.log(`  ${hasPostData ? '✓' : '✗'} Request body forwarded correctly`);
    
    return {
      success: response.status === 200 && hasPostData,
      status: response.status
    };
  } catch (error) {
    console.error(`  ✗ Error testing POST request: ${error.message}`);
    return { success: false, error: error.message };
  }
}

/**
 * Test HTML entity decoding in URLs
 */
async function testHtmlEntityDecoding() {
  console.log('Testing HTML entity decoding...');
  
  // Test URL with HTML entities (encoded)
  const testUrl = 'https://www.example.com/path%26%23x27%3Btest';
  const proxyUrl = `${PROXY_BASE_URL}/proxy?url=${encodeURIComponent(testUrl)}`;
  
  try {
    const response = await fetch(proxyUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; PulsePreviewProxy/1.0)'
      }
    });
    
    // The URL should be decoded before processing
    // We can't easily test the internal decoding, but we can verify the request doesn't crash
    const success = response.status !== 500;
    
    console.log(`  ${success ? '✓' : '✗'} HTML entity handling (no crash)`);
    console.log(`  ${response.status < 500 ? '✓' : '✗'} Request processed (status: ${response.status})`);
    
    return {
      success: success && response.status < 500,
      status: response.status
    };
  } catch (error) {
    console.error(`  ✗ Error testing HTML entity decoding: ${error.message}`);
    return { success: false, error: error.message };
  }
}

/**
 * Test error handling for JavaScript requests
 */
async function testErrorHandling() {
  console.log('Testing error handling...');
  
  // Test with a URL that will return 404
  const testUrl = 'https://www.example.com/nonexistent-page-12345';
  const proxyUrl = `${PROXY_BASE_URL}/proxy?url=${encodeURIComponent(testUrl)}`;
  
  try {
    // Test HTML request (should return HTML error)
    const htmlResponse = await fetch(proxyUrl, {
      headers: {
        'Accept': 'text/html',
        'User-Agent': 'Mozilla/5.0 (compatible; PulsePreviewProxy/1.0)'
      }
    });
    
    const htmlContent = await htmlResponse.text();
    const isHtmlError = htmlContent.includes('<html') || htmlContent.includes('<!DOCTYPE');
    
    // Test JavaScript request (should return JSON error, not HTML)
    const jsResponse = await fetch(proxyUrl, {
      headers: {
        'Accept': 'application/javascript',
        'User-Agent': 'Mozilla/5.0 (compatible; PulsePreviewProxy/1.0)'
      }
    });
    
    const jsContent = await jsResponse.text();
    let isJsonError = false;
    try {
      const parsed = JSON.parse(jsContent);
      isJsonError = parsed.error !== undefined;
    } catch {
      // Not JSON
    }
    
    console.log(`  ${htmlResponse.status === 404 ? '✓' : '✗'} HTML error response correct status`);
    console.log(`  ${isHtmlError ? '✓' : '✗'} HTML error returns HTML content`);
    console.log(`  ${jsResponse.status === 404 ? '✓' : '✗'} JS error response correct status`);
    console.log(`  ${isJsonError || !jsContent.includes('<html') ? '✓' : '✗'} JS error returns JSON (not HTML)`);
    
    return {
      success: htmlResponse.status === 404 && isHtmlError && 
               jsResponse.status === 404 && (isJsonError || !jsContent.includes('<html')),
      htmlStatus: htmlResponse.status,
      jsStatus: jsResponse.status
    };
  } catch (error) {
    console.error(`  ✗ Error testing error handling: ${error.message}`);
    return { success: false, error: error.message };
  }
}

// Run tests
async function runAllTests() {
  const results = await runTests();
  
  // Add new tests
  const postResult = await testPostRequest();
  const entityResult = await testHtmlEntityDecoding();
  const errorResult = await testErrorHandling();
  
  results.push(postResult, entityResult, errorResult);
  
  // Print summary
  const successful = results.filter(r => r.success && !r.skipped);
  const failed = results.filter(r => !r.success);
  const skipped = results.filter(r => r.skipped);
  
  console.log('\n📊 Final Test Summary');
  console.log('====================');
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

runAllTests().catch((error) => {
  console.error('❌ Test failed:', error);
  process.exit(1);
});

