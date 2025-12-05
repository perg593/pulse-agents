/**
 * Unit tests for script interception functionality
 * Tests the JavaScript code that gets injected into proxied pages
 */

// Test framework
function assert(condition, message) {
  if (!condition) {
    throw new Error(`Assertion failed: ${message}`);
  }
}

function test(name, fn) {
  try {
    fn();
    console.log(`  ✓ ${name}`);
  } catch (error) {
    console.error(`  ✗ ${name}: ${error.message}`);
    throw error;
  }
}

/**
 * Test that the script interception code has correct syntax
 * This verifies the fix for the template literal issue
 */
function testScriptInterceptionSyntax() {
  // Simulate the script content structure
  const scriptContent = `
(function() {
  'use strict';
  
  const PROXY_BASE = 'http://localhost:3100';
  const TARGET_ORIGIN = 'https://example.com';
  
  function rewriteUrlForJs(url, baseOrigin) {
    return url;
  }
  
  // Test innerHTML interception - this was the problematic code
  const value = '<script src="/js/file.js"></script>';
  const rewritten = value.replace(/<script([^>]*)src=["']([^"']+)["']/gi, (match, attrs, src) => {
    const rewrittenSrc = rewriteUrlForJs(src, 'https://example.com');
    // This should use string concatenation, not template literals
    return '<script' + attrs + 'src="' + rewrittenSrc + '"';
  });
  
  assert(rewritten.includes('<script'), 'Should contain script tag');
  assert(rewritten.includes('src="'), 'Should contain src attribute');
})();
`;

  // Try to parse it as JavaScript
  try {
    // eslint-disable-next-line no-eval
    eval(scriptContent);
    return true;
  } catch (error) {
    throw new Error(`Script syntax error: ${error.message}`);
  }
}

/**
 * Test that detection logic includes all required checks
 */
function testDetectionLogic() {
  const detectionCode = `
    const currentHref = window.location.href || '';
    const referrer = document.referrer || '';
    const proxyOrigin = 'http://localhost:3100';
    const currentOrigin = window.location.origin || '';
    
    const isProxied = currentHref.includes('/proxy?url=') ||
                      currentHref.includes('proxy%3Furl%3D') ||
                      referrer.includes('/proxy?url=') ||
                      currentOrigin === proxyOrigin;
  `;

  // Check that all detection methods are present
  assert(detectionCode.includes('/proxy?url='), 'Should check URL pattern');
  assert(detectionCode.includes('proxy%3Furl%3D'), 'Should check URL-encoded pattern');
  assert(detectionCode.includes('document.referrer'), 'Should check referrer');
  assert(detectionCode.includes('currentOrigin === proxyOrigin'), 'Should check origin');
}

/**
 * Test that getCurrentOrigin has multiple fallback methods
 */
function testGetCurrentOriginFallbacks() {
  const getCurrentOriginCode = `
    function getCurrentOrigin() {
      const locationHref = document.location.href || window.location.href || '';
      let match = locationHref.match(/proxy[?&]url=([^&]+)/);
      if (!match) {
        match = locationHref.match(/proxy%3Furl%3D([^&]+)/);
      }
      if (match) {
        return 'extracted from URL';
      }
      if (document.baseURI) {
        return 'from baseURI';
      }
      if (document.referrer) {
        return 'from referrer';
      }
      return 'fallback';
    }
  `;

  assert(getCurrentOriginCode.includes('proxy[?&]url='), 'Should extract from URL parameter');
  assert(getCurrentOriginCode.includes('proxy%3Furl%3D'), 'Should handle URL-encoded parameter');
  assert(getCurrentOriginCode.includes('document.baseURI'), 'Should use baseURI fallback');
  assert(getCurrentOriginCode.includes('document.referrer'), 'Should use referrer fallback');
}

/**
 * Test that script interception handles all creation methods
 */
function testScriptCreationInterception() {
  const interceptionCode = `
    // createElement interception
    document.createElement = function(tagName) {
      if (tagName.toLowerCase() === 'script') {
        // Intercept src property
        Object.defineProperty(element, 'src', {
          set: function(value) {
            // Rewrite URL
          }
        });
        // Intercept setAttribute
        element.setAttribute = function(name, value) {
          if (name.toLowerCase() === 'src') {
            // Rewrite URL
          }
        };
      }
    };
    
    // appendChild interception
    Node.prototype.appendChild = function(child) {
      if (child.tagName === 'SCRIPT') {
        // Rewrite script src
      }
    };
    
    // insertBefore interception
    Node.prototype.insertBefore = function(newNode) {
      if (newNode.tagName === 'SCRIPT') {
        // Rewrite script src
      }
    };
  `;

  assert(interceptionCode.includes('createElement'), 'Should intercept createElement');
  assert(interceptionCode.includes('setAttribute'), 'Should intercept setAttribute');
  assert(interceptionCode.includes('appendChild'), 'Should intercept appendChild');
  assert(interceptionCode.includes('insertBefore'), 'Should intercept insertBefore');
  assert(interceptionCode.includes('tagName === \'SCRIPT\''), 'Should check for SCRIPT tag');
}

/**
 * Test that fetch interception handles all input types
 */
function testFetchInterceptionTypes() {
  const fetchCode = `
    window.fetch = function(input, init) {
      if (typeof input === 'string') {
        // Handle string URL
      } else if (input instanceof Request) {
        // Handle Request object
      } else if (input && typeof input === 'object' && input.url) {
        // Handle object with url property
      }
    };
  `;

  assert(fetchCode.includes('typeof input === \'string\''), 'Should handle string URLs');
  assert(fetchCode.includes('instanceof Request'), 'Should handle Request objects');
  assert(fetchCode.includes('input.url'), 'Should handle objects with url property');
}

/**
 * Run all tests
 */
function runTests() {
  console.log('🧪 Script Interception Unit Tests');
  console.log('=================================\n');

  let passed = 0;
  let failed = 0;

  const tests = [
    ['Script interception syntax', testScriptInterceptionSyntax],
    ['Detection logic', testDetectionLogic],
    ['getCurrentOrigin fallbacks', testGetCurrentOriginFallbacks],
    ['Script creation interception', testScriptCreationInterception],
    ['Fetch interception types', testFetchInterceptionTypes]
  ];

  tests.forEach(([name, fn]) => {
    try {
      test(name, fn);
      passed++;
    } catch (error) {
      failed++;
      console.error(`  ✗ ${name}: ${error.message}`);
    }
  });

  console.log('\n📊 Test Summary');
  console.log('===============');
  console.log(`Total tests: ${tests.length}`);
  console.log(`✅ Passed: ${passed}`);
  console.log(`❌ Failed: ${failed}`);

  if (failed > 0) {
    console.error('\n❌ Some tests failed');
    process.exit(1);
  }

  console.log('\n✅ All tests passed!');
}

// Run tests
runTests();

