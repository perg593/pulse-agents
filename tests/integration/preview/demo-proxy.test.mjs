#!/usr/bin/env node

/**
 * Integration test for demo URLs through proxy
 * Tests that all demo URLs from Google Sheet load correctly through the proxy
 */

import { strict as assert } from 'node:assert';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const SHEET_CSV_URL =
  'https://docs.google.com/spreadsheets/d/17k7uKh_TGMNy0hJblfImUGmmbkW_71rDbYlIEfya5Z8/gviz/tq?tqx=out:csv&gid=1498031266';
const DEMO_DATA_PATH = join(__dirname, '../../../preview/app/data/demo-surveys.json');
const PROXY_BASE_URL = process.env.PROXY_BASE_URL || 'http://localhost:3100';

/**
 * Parse CSV text into array of objects
 * Uses the same parser as preview.js for consistency
 * Handles quoted fields and commas within quoted values
 */
function parseCsv(text) {
  const rows = [];
  let current = '';
  let row = [];
  let insideQuotes = false;

  for (let i = 0; i < text.length; i += 1) {
    const char = text[i];

    if (insideQuotes) {
      if (char === '"') {
        if (text[i + 1] === '"') {
          current += '"';
          i += 1;
        } else {
          insideQuotes = false;
        }
      } else {
        current += char;
      }
      continue;
    }

    if (char === '"') {
      insideQuotes = true;
      continue;
    }

    if (char === ',') {
      row.push(current.trim());
      current = '';
      continue;
    }

    if (char === '\r') {
      continue;
    }

    if (char === '\n') {
      row.push(current.trim());
      rows.push(row);
      row = [];
      current = '';
      continue;
    }

    current += char;
  }

  if (current !== '' || row.length > 0) {
    row.push(current.trim());
    rows.push(row);
  }

  if (rows.length < 2) return [];

  // Convert to array of objects
  const headers = rows[0];
  return rows.slice(1).map((row) => {
    const obj = {};
    headers.forEach((header, idx) => {
      obj[header] = row[idx] || '';
    });
    return obj;
  });
}

/**
 * Load demo data from Google Sheet or fallback JSON
 */
async function loadDemoData() {
  // Try Google Sheet first
  try {
    console.log('📥 Loading demo data from Google Sheet...');
    const response = await fetch(SHEET_CSV_URL, { cache: 'no-cache' });
    if (!response.ok) {
      throw new Error(`Sheet responded with ${response.status}`);
    }
    const csvText = await response.text();
    const rows = parseCsv(csvText);
    
    if (rows.length > 0) {
      console.log(`✅ Loaded ${rows.length} demos from Google Sheet`);
      return rows;
    }
  } catch (error) {
    console.warn(`⚠️  Google Sheet unavailable: ${error.message}`);
  }
  
  // Fallback to JSON
  try {
    console.log('📥 Loading demo data from fallback JSON...');
    const jsonText = readFileSync(DEMO_DATA_PATH, 'utf-8');
    const data = JSON.parse(jsonText);
    console.log(`✅ Loaded ${data.length} demos from fallback JSON`);
    return data;
  } catch (error) {
    console.error(`❌ Failed to load fallback JSON: ${error.message}`);
    throw error;
  }
}

/**
 * Extract URLs from demo records
 */
function extractUrls(records) {
  const urls = new Set();
  
  records.forEach((record) => {
    // Check for 'url' field (from CSV)
    if (record.url && typeof record.url === 'string') {
      const trimmed = record.url.trim();
      // Only include absolute HTTP/HTTPS URLs (skip relative paths)
      if (trimmed && /^https?:\/\//i.test(trimmed)) {
        urls.add(trimmed);
      }
    }
    
    // Check for 'backgroundUrl' field (from JSON)
    if (record.backgroundUrl && typeof record.backgroundUrl === 'string') {
      const trimmed = record.backgroundUrl.trim();
      if (trimmed && /^https?:\/\//i.test(trimmed)) {
        urls.add(trimmed);
      }
    }
  });
  
  return Array.from(urls);
}

/**
 * Test a URL through the proxy
 */
async function testProxyUrl(url, timeout = 10000) {
  const proxyUrl = `${PROXY_BASE_URL}/proxy?url=${encodeURIComponent(url)}`;
  
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeout);
    
    const response = await fetch(proxyUrl, {
      signal: controller.signal,
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; PulsePreviewProxy/1.0)'
      }
    });
    
    clearTimeout(timeoutId);
    
    const contentType = response.headers.get('content-type') || '';
    const isHtml = contentType.includes('text/html');
    
    // Handle 403 responses specially - they should have the banner injected
    if (response.status === 403) {
      if (isHtml) {
        const html = await response.text();
        // Check if 403 banner is injected
        const has403Banner = html.includes('pi-proxy-403-banner') || 
                           html.includes('data-pi-proxy="403-message"') ||
                           html.includes('Preview Blocked');
        
        return {
          success: true, // 403 is handled correctly, so it's a success
          status: response.status,
          contentType,
          is403: true,
          has403Banner,
          urlsRewritten: false, // 403 pages don't need URL rewriting
          url
        };
      }
      // Non-HTML 403 responses are still considered handled
      return {
        success: true,
        status: response.status,
        contentType,
        is403: true,
        has403Banner: false,
        urlsRewritten: false,
        url
      };
    }
    
    // For non-403 responses, check if they're successful
    if (!response.ok) {
      return {
        success: false,
        error: `HTTP ${response.status}: ${response.statusText}`,
        url
      };
    }
    
    // For HTML, check if URLs are rewritten and JS interception is present
    let urlsRewritten = false;
    let hasJsInterception = false;
    let hasRelativePathRewriting = false;
    if (isHtml) {
      const html = await response.text();
      // Check if at least some URLs are rewritten to proxy
      urlsRewritten = html.includes('/proxy?url=');
      // Check for JavaScript interception script
      hasJsInterception = html.includes('data-pi-proxy="url-rewriting"') ||
                         html.includes('rewriteUrlForJs') ||
                         (html.includes('window.fetch') && html.includes('originalFetch'));
      // Check for relative path rewriting (look for script/link tags with rewritten URLs)
      hasRelativePathRewriting = /<script[^>]*src=["'][^"']*\/proxy\?url=[^"']*["']/i.test(html) ||
                                 /<link[^>]*href=["'][^"']*\/proxy\?url=[^"']*["']/i.test(html);
    }
    
    return {
      success: true,
      status: response.status,
      contentType,
      is403: false,
      has403Banner: false,
      urlsRewritten,
      hasJsInterception,
      hasRelativePathRewriting,
      url
    };
  } catch (error) {
    if (error.name === 'AbortError') {
      return {
        success: false,
        error: `Timeout after ${timeout}ms`,
        url
      };
    }
    return {
      success: false,
      error: error.message,
      url
    };
  }
}

/**
 * Check if proxy server is running
 */
async function checkProxyHealth() {
  try {
    const healthUrl = `${PROXY_BASE_URL}/background-proxy/health`;
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 5000);
    
    const response = await fetch(healthUrl, { signal: controller.signal });
    clearTimeout(timeoutId);
    
    if (response.ok) {
      const data = await response.json();
      return { running: true, data };
    }
    return { running: false, error: `Health check returned ${response.status}` };
  } catch (error) {
    return { running: false, error: error.message };
  }
}

/**
 * Test 403 error handling with known URLs
 */
async function test403Handling() {
  console.log('🔒 Testing 403 error handling...');
  
  // Known URLs that return 403 (may change over time)
  const known403Urls = [
    'https://www.waterworks.com/us_en/fixtures-bathtubs-sinks/kitchen/sinks',
    'https://www.xfinity.com/learn/internet-service'
  ];
  
  const results = [];
  for (const url of known403Urls) {
    const result = await testProxyUrl(url, 15000); // Longer timeout for 403 checks
    results.push(result);
    
    if (result.is403) {
      if (result.has403Banner) {
        console.log(`  ✅ ${url}`);
        console.log(`     Status 403 with banner injection`);
      } else {
        console.log(`  ⚠️  ${url}`);
        console.log(`     Status 403 but no banner detected`);
      }
    } else if (result.success) {
      console.log(`  ℹ️  ${url}`);
      console.log(`     Status ${result.status} (not 403, may have changed)`);
    } else {
      console.log(`  ❌ ${url}`);
      console.log(`     ${result.error}`);
    }
  }
  
  console.log('');
  return results;
}

/**
 * Main test function
 */
async function runTests() {
  console.log('🧪 Demo Proxy Integration Test');
  console.log('==============================\n');
  
  // Check proxy health
  console.log(`🔍 Checking proxy server at ${PROXY_BASE_URL}...`);
  const health = await checkProxyHealth();
  if (!health.running) {
    console.error(`❌ Proxy server not running: ${health.error}`);
    console.error(`\n💡 Start the proxy server with: npm start`);
    process.exit(1);
  }
  console.log(`✅ Proxy server is running\n`);
  
  // Test 403 handling first
  const test403Results = await test403Handling();
  
  // Load demo data
  const records = await loadDemoData();
  console.log('');
  
  // Extract URLs
  const urls = extractUrls(records);
  console.log(`📋 Found ${urls.length} unique demo URLs to test\n`);
  
  if (urls.length === 0) {
    console.warn('⚠️  No URLs found in demo data');
    return;
  }
  
  // Test each URL
  const results = [];
  const concurrency = 3; // Test 3 URLs at a time
  
  for (let i = 0; i < urls.length; i += concurrency) {
    const batch = urls.slice(i, i + concurrency);
    console.log(`Testing batch ${Math.floor(i / concurrency) + 1}/${Math.ceil(urls.length / concurrency)}...`);
    
    const batchResults = await Promise.all(
      batch.map(async (url) => {
        const result = await testProxyUrl(url);
        const status = result.success ? '✅' : '❌';
        let message;
        if (result.success) {
          if (result.is403) {
            message = `Status ${result.status} (403 handled${result.has403Banner ? ', banner injected' : ', no banner'})`;
          } else {
            const parts = [];
            if (result.urlsRewritten) parts.push('URLs rewritten');
            if (result.hasJsInterception) parts.push('JS interception');
            if (result.hasRelativePathRewriting) parts.push('relative paths');
            message = `Status ${result.status}${parts.length > 0 ? ` (${parts.join(', ')})` : ''}`;
          }
        } else {
          message = result.error;
        }
        console.log(`  ${status} ${url}`);
        console.log(`     ${message}`);
        return result;
      })
    );
    
    results.push(...batchResults);
    console.log('');
  }
  
  // Summary
  console.log('📊 Test Summary');
  console.log('===============');
  const successful = results.filter((r) => r.success);
  const failed = results.filter((r) => !r.success);
  
  console.log(`Total URLs tested: ${results.length}`);
  console.log(`✅ Successful: ${successful.length}`);
  console.log(`❌ Failed: ${failed.length}`);
  
  // Include 403 test results in summary if any
  if (test403Results && test403Results.length > 0) {
    const test403Successful = test403Results.filter((r) => r.is403 && r.has403Banner);
    if (test403Successful.length > 0) {
      console.log(`\n🔒 403 Handling Test: ${test403Successful.length}/${test403Results.length} URLs with proper banner injection`);
    }
  }
  
  if (failed.length > 0) {
    console.log('\n❌ Failed URLs:');
    failed.forEach((result) => {
      console.log(`  - ${result.url}`);
      console.log(`    Error: ${result.error}`);
    });
  }
  
  // Check URL rewriting
  const withRewriting = successful.filter((r) => r.urlsRewritten);
  const withJsInterception = successful.filter((r) => r.hasJsInterception);
  const withRelativePaths = successful.filter((r) => r.hasRelativePathRewriting);
  
  if (withRewriting.length > 0) {
    console.log(`\n✅ URLs with rewriting: ${withRewriting.length}/${successful.length}`);
  }
  if (withJsInterception.length > 0) {
    console.log(`✅ JavaScript interception: ${withJsInterception.length}/${successful.length}`);
  }
  if (withRelativePaths.length > 0) {
    console.log(`✅ Relative path rewriting: ${withRelativePaths.length}/${successful.length}`);
  }
  
  // Check 403 handling
  const with403 = successful.filter((r) => r.is403);
  if (with403.length > 0) {
    console.log(`\n🔒 URLs with 403 responses: ${with403.length}`);
    const withBanner = with403.filter((r) => r.has403Banner);
    const withoutBanner = with403.filter((r) => !r.has403Banner);
    if (withBanner.length > 0) {
      console.log(`  ✅ With 403 banner: ${withBanner.length}`);
    }
    if (withoutBanner.length > 0) {
      console.log(`  ⚠️  Without 403 banner: ${withoutBanner.length}`);
      withoutBanner.forEach((r) => {
        console.log(`    - ${r.url} (status ${r.status}, content-type: ${r.contentType})`);
      });
    }
  }
  
  // Assertions
  const successRate = successful.length / results.length;
  const minSuccessRate = 0.8; // 80% success rate
  
  if (successRate < minSuccessRate) {
    console.error(`\n❌ Success rate ${(successRate * 100).toFixed(1)}% is below minimum ${(minSuccessRate * 100).toFixed(0)}%`);
    process.exit(1);
  }
  
  // Warn if 403 responses don't have banners (but don't fail the test)
  const html403WithoutBanner = with403.filter((r) => r.contentType?.includes('text/html') && !r.has403Banner);
  if (html403WithoutBanner.length > 0) {
    console.warn(`\n⚠️  Warning: ${html403WithoutBanner.length} HTML 403 response(s) without banner injection`);
  }
  
  console.log(`\n✅ Test passed! Success rate: ${(successRate * 100).toFixed(1)}%`);
}

// Run tests
runTests().catch((error) => {
  console.error('❌ Test failed:', error);
  process.exit(1);
});

