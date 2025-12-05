#!/usr/bin/env node

/**
 * Analyzes HAR files to compare production vs localhost behavior
 * @fileoverview HAR file comparison tool
 */

const fs = require('fs');
const path = require('path');

function parseHAR(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  const har = JSON.parse(content);
  return har;
}

function analyzeHAR(har, label) {
  const entries = har.log?.entries || [];
  const analysis = {
    label,
    totalRequests: entries.length,
    requests: [],
    failedRequests: [],
    proxyRequests: [],
    scriptInjection: null,
    urlRewriting: [],
    headers: {},
    statusCodes: {},
    contentTypes: {}
  };

  entries.forEach((entry, index) => {
    const request = entry.request;
    const response = entry.response;
    const url = request.url;
    const method = request.method;
    const status = response.status;
    const contentType = response.headers?.find(h => h.name.toLowerCase() === 'content-type')?.value || 'unknown';

    // Track status codes
    analysis.statusCodes[status] = (analysis.statusCodes[status] || 0) + 1;

    // Track content types
    const type = contentType.split(';')[0].trim();
    analysis.contentTypes[type] = (analysis.contentTypes[type] || 0) + 1;

    // Track proxy requests
    if (url.includes('/proxy?url=')) {
      analysis.proxyRequests.push({
        index,
        url,
        method,
        status,
        contentType
      });
    }

    // Track failed requests
    if (status >= 400 || !response.status) {
      analysis.failedRequests.push({
        index,
        url,
        method,
        status,
        contentType,
        error: entry.response?.content?.text || ''
      });
    }

    // Check for script injection in HTML responses
    if (contentType.includes('text/html') && response.content?.text) {
      const html = response.content.text;
      if (html.includes('[PI-Proxy]') || html.includes('data-pi-proxy="url-rewriting"')) {
        analysis.scriptInjection = {
          url,
          hasInjection: true,
          injectionType: html.includes('data-pi-proxy="url-rewriting"') ? 'url-rewriting' : 'other'
        };
      }
    }

    // Track URL rewriting patterns
    if (url.includes('/proxy?url=')) {
      const match = url.match(/proxy[?&]url=([^&]+)/);
      if (match) {
        try {
          const decoded = decodeURIComponent(match[1]);
          analysis.urlRewriting.push({
            original: decoded,
            proxied: url
          });
        } catch (e) {
          // Ignore decode errors
        }
      }
    }

    // Store key request info
    analysis.requests.push({
      index,
      url: url.substring(0, 200), // Truncate for readability
      method,
      status,
      contentType: type
    });
  });

  return analysis;
}

function compareAnalyses(prod, localhost) {
  const differences = {
    totalRequests: {
      production: prod.totalRequests,
      localhost: localhost.totalRequests,
      diff: prod.totalRequests - localhost.totalRequests
    },
    failedRequests: {
      production: prod.failedRequests.length,
      localhost: localhost.failedRequests.length,
      diff: prod.failedRequests.length - localhost.failedRequests.length
    },
    proxyRequests: {
      production: prod.proxyRequests.length,
      localhost: localhost.proxyRequests.length,
      diff: prod.proxyRequests.length - localhost.proxyRequests.length
    },
    scriptInjection: {
      production: prod.scriptInjection?.hasInjection || false,
      localhost: localhost.scriptInjection?.hasInjection || false,
      match: (prod.scriptInjection?.hasInjection || false) === (localhost.scriptInjection?.hasInjection || false)
    },
    statusCodes: {},
    contentTypes: {},
    uniqueUrls: {
      production: new Set(prod.requests.map(r => r.url)).size,
      localhost: new Set(localhost.requests.map(r => r.url)).size
    },
    failedRequestDetails: {
      production: prod.failedRequests.map(f => ({
        url: f.url.substring(0, 150),
        status: f.status,
        contentType: f.contentType
      })),
      localhost: localhost.failedRequests.map(f => ({
        url: f.url.substring(0, 150),
        status: f.status,
        contentType: f.contentType
      }))
    }
  };

  // Compare status codes
  const allStatusCodes = new Set([
    ...Object.keys(prod.statusCodes),
    ...Object.keys(localhost.statusCodes)
  ]);
  allStatusCodes.forEach(code => {
    differences.statusCodes[code] = {
      production: prod.statusCodes[code] || 0,
      localhost: localhost.statusCodes[code] || 0,
      diff: (prod.statusCodes[code] || 0) - (localhost.statusCodes[code] || 0)
    };
  });

  // Compare content types
  const allContentTypes = new Set([
    ...Object.keys(prod.contentTypes),
    ...Object.keys(localhost.contentTypes)
  ]);
  allContentTypes.forEach(type => {
    differences.contentTypes[type] = {
      production: prod.contentTypes[type] || 0,
      localhost: localhost.contentTypes[type] || 0,
      diff: (prod.contentTypes[type] || 0) - (localhost.contentTypes[type] || 0)
    };
  });

  return differences;
}

function printReport(prodAnalysis, localhostAnalysis, differences) {
  console.log('\n' + '='.repeat(80));
  console.log('HAR FILE COMPARISON REPORT');
  console.log('='.repeat(80) + '\n');

  console.log('OVERVIEW:');
  console.log(`  Production:  ${prodAnalysis.totalRequests} total requests`);
  console.log(`  Localhost:   ${localhostAnalysis.totalRequests} total requests`);
  console.log(`  Difference:  ${differences.totalRequests.diff}\n`);

  console.log('PROXY REQUESTS:');
  console.log(`  Production:  ${differences.proxyRequests.production}`);
  console.log(`  Localhost:   ${differences.proxyRequests.localhost}`);
  console.log(`  Difference:  ${differences.proxyRequests.diff}\n`);

  console.log('FAILED REQUESTS:');
  console.log(`  Production:  ${differences.failedRequests.production}`);
  console.log(`  Localhost:   ${differences.failedRequests.localhost}`);
  console.log(`  Difference:  ${differences.failedRequests.diff}\n`);

  console.log('SCRIPT INJECTION:');
  console.log(`  Production:  ${differences.scriptInjection.production ? 'YES' : 'NO'}`);
  console.log(`  Localhost:   ${differences.scriptInjection.localhost ? 'YES' : 'NO'}`);
  console.log(`  Match:       ${differences.scriptInjection.match ? 'YES' : 'NO'}\n`);

  if (differences.failedRequests.production > 0 || differences.failedRequests.localhost > 0) {
    console.log('\nFAILED REQUEST DETAILS:');
    if (differences.failedRequestDetails.production.length > 0) {
      console.log('\n  Production failures:');
      differences.failedRequestDetails.production.slice(0, 10).forEach(f => {
        console.log(`    [${f.status}] ${f.url.substring(0, 100)}`);
      });
    }
    if (differences.failedRequestDetails.localhost.length > 0) {
      console.log('\n  Localhost failures:');
      differences.failedRequestDetails.localhost.slice(0, 10).forEach(f => {
        console.log(`    [${f.status}] ${f.url.substring(0, 100)}`);
      });
    }
  }

  console.log('\nSTATUS CODE DISTRIBUTION:');
  Object.keys(differences.statusCodes)
    .sort((a, b) => parseInt(a) - parseInt(b))
    .forEach(code => {
      const diff = differences.statusCodes[code];
      if (diff.diff !== 0 || diff.production > 0 || diff.localhost > 0) {
        console.log(`  ${code}: Production=${diff.production}, Localhost=${diff.localhost}, Diff=${diff.diff}`);
      }
    });

  console.log('\nCONTENT TYPE DISTRIBUTION:');
  Object.keys(differences.contentTypes)
    .sort()
    .forEach(type => {
      const diff = differences.contentTypes[type];
      if (diff.diff !== 0 || diff.production > 5 || diff.localhost > 5) {
        console.log(`  ${type}: Production=${diff.production}, Localhost=${diff.localhost}, Diff=${diff.diff}`);
      }
    });

  // Show first few proxy requests from each
  console.log('\n' + '='.repeat(80));
  console.log('SAMPLE PROXY REQUESTS:');
  console.log('='.repeat(80));
  
  if (prodAnalysis.proxyRequests.length > 0) {
    console.log('\nProduction (first 5):');
    prodAnalysis.proxyRequests.slice(0, 5).forEach(req => {
      console.log(`  [${req.status}] ${req.url.substring(0, 120)}`);
    });
  }
  
  if (localhostAnalysis.proxyRequests.length > 0) {
    console.log('\nLocalhost (first 5):');
    localhostAnalysis.proxyRequests.slice(0, 5).forEach(req => {
      console.log(`  [${req.status}] ${req.url.substring(0, 120)}`);
    });
  }

  console.log('\n' + '='.repeat(80));
}

function main() {
  const args = process.argv.slice(2);
  if (args.length < 2) {
    console.error('Usage: node analyze-har-diff.js <production.har> <localhost.har>');
    process.exit(1);
  }

  const [prodPath, localhostPath] = args;

  if (!fs.existsSync(prodPath)) {
    console.error(`Error: Production HAR file not found: ${prodPath}`);
    process.exit(1);
  }

  if (!fs.existsSync(localhostPath)) {
    console.error(`Error: Localhost HAR file not found: ${localhostPath}`);
    process.exit(1);
  }

  console.log('Parsing HAR files...');
  const prodHAR = parseHAR(prodPath);
  const localhostHAR = parseHAR(localhostPath);

  console.log('Analyzing production HAR...');
  const prodAnalysis = analyzeHAR(prodHAR, 'Production');

  console.log('Analyzing localhost HAR...');
  const localhostAnalysis = analyzeHAR(localhostHAR, 'Localhost');

  console.log('Comparing analyses...');
  const differences = compareAnalyses(prodAnalysis, localhostAnalysis);

  printReport(prodAnalysis, localhostAnalysis, differences);
}

if (require.main === module) {
  main();
}

module.exports = { parseHAR, analyzeHAR, compareAnalyses };
