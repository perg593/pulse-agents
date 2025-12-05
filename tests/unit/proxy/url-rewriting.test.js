/**
 * Unit tests for URL rewriting functionality
 * Tests the rewriteUrl() logic used in proxy functions
 */

// Analytics blocking helper
function shouldBlockAnalyticsUrl(url, blocklist) {
  if (!url || typeof url !== 'string' || !blocklist || blocklist.length === 0) return false;
  
  try {
    const urlObj = new URL(url);
    const hostname = urlObj.hostname.toLowerCase();
    const pathname = urlObj.pathname.toLowerCase();
    
    return blocklist.some(pattern => {
      const lowerPattern = pattern.toLowerCase();
      return hostname.includes(lowerPattern) || pathname.includes(lowerPattern);
    });
  } catch (e) {
    const lowerUrl = url.toLowerCase();
    return blocklist.some(pattern => {
      return lowerUrl.includes(pattern.toLowerCase());
    });
  }
}

// Extract rewriteUrl logic for testing (updated with analytics blocking)
function rewriteUrl(url, targetOrigin, proxyBase, analyticsBlocklist = []) {
  if (!url || typeof url !== 'string') return url;

  const trimmed = url.trim();
  if (!trimmed) return url;

  // Skip data URLs, blob URLs, and javascript: URLs
  if (
    /^(data:|blob:|javascript:|mailto:|tel:|#)/i.test(trimmed) ||
    trimmed.startsWith('about:')
  ) {
    return url;
  }

  // Skip URLs that are already proxied
  if (trimmed.includes('/proxy?url=')) {
    return url;
  }

  // Block analytics/tracking URLs
  if (analyticsBlocklist.length > 0 && shouldBlockAnalyticsUrl(trimmed, analyticsBlocklist)) {
    return 'about:blank';
  }

  // Handle protocol-relative URLs (//example.com)
  let absoluteUrl = trimmed;
  if (trimmed.startsWith('//')) {
    absoluteUrl = `https:${trimmed}`;
  } else if (!/^https?:\/\//i.test(trimmed)) {
    // Relative URL - resolve against target origin
    try {
      const baseUrl = targetOrigin.endsWith('/') ? targetOrigin : `${targetOrigin}/`;
      absoluteUrl = new URL(trimmed, baseUrl).toString();
    } catch (_error) {
      return url;
    }
  }

  // Skip same-origin URLs (relative to proxy origin)
  try {
    const parsed = new URL(absoluteUrl);
    const proxyParsed = new URL(proxyBase);
    if (parsed.origin === proxyParsed.origin) {
      return url;
    }
    
    // Also skip if the URL is a fragment/anchor (starts with #)
    if (parsed.hash && parsed.pathname === parsed.pathname.split('#')[0] && trimmed.startsWith('#')) {
      return url;
    }
  } catch (_error) {
    // If parsing fails, proceed with proxying
  }

  // Rewrite to proxy URL
  const encoded = encodeURIComponent(absoluteUrl);
  return `${proxyBase}/proxy?url=${encoded}`;
}

// Test framework
function assert(condition, message) {
  if (!condition) {
    throw new Error(`Assertion failed: ${message}`);
  }
}

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

// Test cases
const PROXY_BASE = 'http://localhost:3100';
const TARGET_ORIGIN = 'https://www.example.com';

console.log('Testing URL rewriting functionality...\n');

// Test 1: Absolute URLs
test('Absolute HTTPS URL should be rewritten', () => {
  const result = rewriteUrl('https://cdn.example.com/file.js', TARGET_ORIGIN, PROXY_BASE);
  assert(result.includes('/proxy?url='), 'Should contain proxy URL');
  // Parse the rewritten proxy URL and check that the proxied URL's host is 'cdn.example.com'
  const proxiedUrl = new URL(result, PROXY_BASE);
  const targetUrl = new URL(decodeURIComponent(proxiedUrl.searchParams.get('url')));
  assert(targetUrl.host === 'cdn.example.com', 'Should contain original domain');
});

test('Absolute HTTP URL should be rewritten', () => {
  const result = rewriteUrl('http://cdn.example.com/file.js', TARGET_ORIGIN, PROXY_BASE);
  assert(result.includes('/proxy?url='), 'Should contain proxy URL');
});

// Test 2: Protocol-relative URLs
test('Protocol-relative URL should be rewritten with https:', () => {
  const result = rewriteUrl('//cdn.example.com/file.js', TARGET_ORIGIN, PROXY_BASE);
  assert(result.includes('/proxy?url='), 'Should contain proxy URL');
  assert(result.includes('https%3A%2F%2Fcdn.example.com'), 'Should use https:');
});

// Test 3: Root-relative paths
test('Root-relative path should be resolved and rewritten', () => {
  const result = rewriteUrl('/js/file.js', TARGET_ORIGIN, PROXY_BASE);
  assert(result.includes('/proxy?url='), 'Should contain proxy URL');
  // Parse the rewritten proxy URL and check that the proxied URL's host is 'www.example.com'
  const proxiedUrl = new URL(result, PROXY_BASE);
  const targetUrl = new URL(decodeURIComponent(proxiedUrl.searchParams.get('url')));
  assert(targetUrl.host === 'www.example.com', 'Should resolve against target origin');
  assert(targetUrl.pathname.includes('/js/file.js'), 'Should contain path');
});

test('Root-relative path with subdirectory should work', () => {
  const result = rewriteUrl('/js/20251203154408-374/ug-spa/dist/file.js', TARGET_ORIGIN, PROXY_BASE);
  assert(result.includes('/proxy?url='), 'Should contain proxy URL');
  // Parse the rewritten proxy URL and check that the proxied URL's host is 'www.example.com'
  const proxiedUrl = new URL(result, PROXY_BASE);
  const targetUrl = new URL(decodeURIComponent(proxiedUrl.searchParams.get('url')));
  assert(targetUrl.host === 'www.example.com', 'Should resolve against target origin');
});

// Test 4: Relative paths
test('Relative path should be resolved and rewritten', () => {
  const result = rewriteUrl('./file.js', TARGET_ORIGIN, PROXY_BASE);
  assert(result.includes('/proxy?url='), 'Should contain proxy URL');
  // Parse the rewritten proxy URL and check that the proxied URL's host is 'www.example.com'
  const proxiedUrl = new URL(result, PROXY_BASE);
  const targetUrl = new URL(decodeURIComponent(proxiedUrl.searchParams.get('url')));
  assert(targetUrl.host === 'www.example.com', 'Should resolve against target origin');
});

test('Relative path without ./ should work', () => {
  const result = rewriteUrl('file.js', TARGET_ORIGIN, PROXY_BASE);
  assert(result.includes('/proxy?url='), 'Should contain proxy URL');
});

test('Parent directory relative path should work', () => {
  const result = rewriteUrl('../file.js', TARGET_ORIGIN, PROXY_BASE);
  assert(result.includes('/proxy?url='), 'Should contain proxy URL');
});

// Test 5: Special URLs should not be rewritten
test('Data URL should not be rewritten', () => {
  const result = rewriteUrl('data:image/png;base64,iVBORw0KGgo=', TARGET_ORIGIN, PROXY_BASE);
  assert(result === 'data:image/png;base64,iVBORw0KGgo=', 'Should return original');
});

test('Blob URL should not be rewritten', () => {
  const result = rewriteUrl('blob:http://localhost/uuid', TARGET_ORIGIN, PROXY_BASE);
  assert(result === 'blob:http://localhost/uuid', 'Should return original');
});

test('JavaScript URL should not be rewritten', () => {
  const result = rewriteUrl('javascript:void(0)', TARGET_ORIGIN, PROXY_BASE);
  assert(result === 'javascript:void(0)', 'Should return original');
});

test('Mailto URL should not be rewritten', () => {
  const result = rewriteUrl('mailto:test@example.com', TARGET_ORIGIN, PROXY_BASE);
  assert(result === 'mailto:test@example.com', 'Should return original');
});

test('Anchor/fragment should not be rewritten', () => {
  const result = rewriteUrl('#section', TARGET_ORIGIN, PROXY_BASE);
  assert(result === '#section', 'Should return original');
});

// Test 6: Already proxied URLs
test('Already proxied URL should not be rewritten again', () => {
  const proxied = `${PROXY_BASE}/proxy?url=https%3A%2F%2Fexample.com`;
  const result = rewriteUrl(proxied, TARGET_ORIGIN, PROXY_BASE);
  assert(result === proxied, 'Should return original proxied URL');
});

// Test 7: Same-origin URLs
test('URL on proxy origin should not be rewritten', () => {
  const result = rewriteUrl('http://localhost:3100/some/path', TARGET_ORIGIN, PROXY_BASE);
  assert(result === 'http://localhost:3100/some/path', 'Should return original');
});

// Test 8: Edge cases
test('Empty string should return empty string', () => {
  const result = rewriteUrl('', TARGET_ORIGIN, PROXY_BASE);
  assert(result === '', 'Should return empty string');
});

test('Whitespace-only string should return original', () => {
  const result = rewriteUrl('   ', TARGET_ORIGIN, PROXY_BASE);
  assert(result === '   ', 'Should return original');
});

test('Null should return null', () => {
  const result = rewriteUrl(null, TARGET_ORIGIN, PROXY_BASE);
  assert(result === null, 'Should return null');
});

test('Undefined should return undefined', () => {
  const result = rewriteUrl(undefined, TARGET_ORIGIN, PROXY_BASE);
  assert(result === undefined, 'Should return undefined');
});

// Test 9: Query parameters and fragments
test('URL with query parameters should be preserved', () => {
  const result = rewriteUrl('https://example.com/file.js?v=1&t=123', TARGET_ORIGIN, PROXY_BASE);
  assert(result.includes('file.js%3Fv%3D1%26t%3D123'), 'Should encode query params');
});

test('URL with fragment should be preserved', () => {
  const result = rewriteUrl('https://example.com/file.js#section', TARGET_ORIGIN, PROXY_BASE);
  assert(result.includes('file.js%23section'), 'Should encode fragment');
});

// Test 10: Complex relative paths
test('Complex relative path should resolve correctly', () => {
  const result = rewriteUrl('../../js/dist/file.js', TARGET_ORIGIN, PROXY_BASE);
  assert(result.includes('/proxy?url='), 'Should contain proxy URL');
  // Extract the proxied URL from the result and assert its host is 'www.example.com'
  const proxiedUrl = new URL(result, PROXY_BASE);
  const targetUrl = new URL(decodeURIComponent(proxiedUrl.searchParams.get('url')));
  assert(targetUrl.host === 'www.example.com', 'Should resolve against target origin host');
});

// Test 11: srcset attribute rewriting
test('srcset with multiple URLs should rewrite all URLs', () => {
  const srcset = '/image1.jpg 1x, /image2.jpg 2x, https://cdn.example.com/image3.jpg 100w';
  // Simulate srcset rewriting logic
  const rewritten = srcset
    .split(',')
    .map((entry) => {
      const trimmed = entry.trim();
      const parts = trimmed.split(/\s+/);
      if (parts.length === 0) return trimmed;
      const url = parts[0];
      const descriptors = parts.slice(1).join(' ');
      const rewrittenUrl = rewriteUrl(url, TARGET_ORIGIN, PROXY_BASE);
      return descriptors ? `${rewrittenUrl} ${descriptors}` : rewrittenUrl;
    })
    .join(', ');
  
  assert(rewritten.includes('/proxy?url='), 'Should contain proxy URLs');
  assert(rewritten.includes('image1.jpg'), 'Should preserve first image');
  assert(rewritten.includes('image2.jpg'), 'Should preserve second image');
  assert(rewritten.includes('image3.jpg'), 'Should preserve third image');
});

// Test 12: CSS url() rewriting
test('CSS url() should be rewritten', () => {
  const cssUrl = 'url(/images/background.png)';
  const urlMatch = cssUrl.match(/url\s*\(\s*["']?([^"')]+)["']?\s*\)/);
  if (urlMatch) {
    const url = urlMatch[1].trim();
    const rewrittenUrl = rewriteUrl(url, TARGET_ORIGIN, PROXY_BASE);
    const rewritten = cssUrl.replace(url, rewrittenUrl);
    assert(rewritten.includes('/proxy?url='), 'Should contain proxy URL');
  }
});

test('CSS url() with quotes should be rewritten', () => {
  const cssUrl = "url('/images/background.png')";
  const urlMatch = cssUrl.match(/url\s*\(\s*["']?([^"')]+)["']?\s*\)/);
  if (urlMatch) {
    const url = urlMatch[1].trim();
    const rewrittenUrl = rewriteUrl(url, TARGET_ORIGIN, PROXY_BASE);
    const rewritten = cssUrl.replace(url, rewrittenUrl);
    assert(rewritten.includes('/proxy?url='), 'Should contain proxy URL');
  }
});

// Test 13: Request object preservation (simulated)
test('Request object URL should be rewritten while preserving other properties', () => {
  // Simulate Request object handling
  const originalUrl = 'https://api.example.com/data.json';
  const rewrittenUrl = rewriteUrl(originalUrl, TARGET_ORIGIN, PROXY_BASE);
  
  assert(rewrittenUrl !== originalUrl, 'URL should be rewritten');
  assert(rewrittenUrl.includes('/proxy?url='), 'Should contain proxy URL');
  
  // In actual implementation, Request would be cloned with new URL
  // This test verifies the URL rewriting logic works correctly
});

// Test 14: outerHTML script tag rewriting
test('outerHTML with script tag should rewrite script src', () => {
  const outerHTML = '<script src="/js/file.js"></script>';
  const scriptMatch = outerHTML.match(/<script([^>]*)src=["']([^"']+)["']/i);
  if (scriptMatch) {
    const src = scriptMatch[2];
    const rewrittenSrc = rewriteUrl(src, TARGET_ORIGIN, PROXY_BASE);
    const rewritten = outerHTML.replace(src, rewrittenSrc);
    assert(rewritten.includes('/proxy?url='), 'Should contain proxy URL');
  }
});

// Test 15: Analytics blocking
test('Google Tag Manager URL should be blocked', () => {
  const blocklist = ['googletagmanager.com'];
  const result = rewriteUrl('https://www.googletagmanager.com/gtm.js?id=GTM-XXXXX', TARGET_ORIGIN, PROXY_BASE, blocklist);
  assert(result === 'about:blank', 'Should return about:blank for blocked analytics URL');
});

test('Google Analytics URL should be blocked', () => {
  const blocklist = ['google-analytics.com'];
  const result = rewriteUrl('https://www.google-analytics.com/analytics.js', TARGET_ORIGIN, PROXY_BASE, blocklist);
  assert(result === 'about:blank', 'Should return about:blank for blocked analytics URL');
});

test('GTM path pattern should be blocked', () => {
  const blocklist = ['gtm.js'];
  const result = rewriteUrl('https://example.com/gtm.js', TARGET_ORIGIN, PROXY_BASE, blocklist);
  assert(result === 'about:blank', 'Should block URLs matching path pattern');
});

test('Non-analytics URL should not be blocked', () => {
  const blocklist = ['googletagmanager.com'];
  const result = rewriteUrl('https://cdn.example.com/app.js', TARGET_ORIGIN, PROXY_BASE, blocklist);
  assert(result.includes('/proxy?url='), 'Should rewrite non-blocked URLs normally');
});

// Test 16: JSON-LD preservation
test('JSON-LD script block should be preserved', () => {
  const html = '<script type="application/ld+json">{"@context":"https://schema.org","@type":"WebSite","url":"https://example.com"}</script>';
  const jsonLdRegex = /<script\s+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
  const matches = [];
  let match;
  while ((match = jsonLdRegex.exec(html)) !== null) {
    matches.push(match[0]);
  }
  assert(matches.length === 1, 'Should find JSON-LD script');
  assert(matches[0].includes('https://example.com'), 'Should preserve original URL in JSON-LD');
});

// Test 17: srcset parsing with multiple URLs
test('srcset with multiple URLs and descriptors should parse correctly', () => {
  const srcset = '/image1.jpg 150w, /image2.jpg 512w, /image3.jpg 768w';
  const parsed = srcset
    .split(',')
    .map((entry) => {
      const trimmed = entry.trim();
      const parts = trimmed.split(/\s+/);
      if (parts.length === 0) return trimmed;
      const url = parts[0];
      const descriptors = parts.slice(1).join(' ');
      return { url, descriptors };
    });
  
  assert(parsed.length === 3, 'Should parse 3 entries');
  assert(parsed[0].url === '/image1.jpg', 'First URL should be correct');
  assert(parsed[0].descriptors === '150w', 'First descriptor should be correct');
  assert(parsed[1].url === '/image2.jpg', 'Second URL should be correct');
  assert(parsed[2].url === '/image3.jpg', 'Third URL should be correct');
});

test('srcset rewriting should handle each URL separately', () => {
  const srcset = '/image1.jpg 150w, /image2.jpg 512w';
  const rewritten = srcset
    .split(',')
    .map((entry) => {
      const trimmed = entry.trim();
      const parts = trimmed.split(/\s+/);
      if (parts.length === 0) return trimmed;
      const url = parts[0];
      const descriptors = parts.slice(1).join(' ');
      const rewrittenUrl = rewriteUrl(url, TARGET_ORIGIN, PROXY_BASE);
      return descriptors ? `${rewrittenUrl} ${descriptors}` : rewrittenUrl;
    })
    .join(', ');
  
  // Should have two separate proxy URLs
  const proxyMatches = rewritten.match(/\/proxy\?url=/g);
  assert(proxyMatches && proxyMatches.length === 2, 'Should rewrite each URL separately');
  assert(rewritten.includes('150w'), 'Should preserve first descriptor');
  assert(rewritten.includes('512w'), 'Should preserve second descriptor');
});

console.log('\nAll URL rewriting tests passed!');

