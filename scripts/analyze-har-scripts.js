#!/usr/bin/env node

/**
 * Deep analysis of script injection and URL rewriting in HAR files
 */

const fs = require('fs');

function parseHAR(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  return JSON.parse(content);
}

function analyzeScriptInjection(har, label) {
  const entries = har.log?.entries || [];
  const results = {
    label,
    htmlResponses: [],
    scriptInjectionFound: [],
    urlRewritingScripts: [],
    proxyOrigin: null,
    baseHrefInjection: []
  };

  entries.forEach((entry, index) => {
    const request = entry.request;
    const response = entry.response;
    const url = request.url;
    const contentType = response.headers?.find(h => h.name.toLowerCase() === 'content-type')?.value || '';

    if (contentType.includes('text/html') && response.content?.text) {
      const html = response.content.text;
      const isProxyRequest = url.includes('/proxy?url=');

      // Extract proxy origin from URL
      if (isProxyRequest && !results.proxyOrigin) {
        try {
          const urlObj = new URL(url);
          results.proxyOrigin = `${urlObj.protocol}//${urlObj.host}`;
        } catch (e) {
          // Ignore
        }
      }

      // Check for script injection
      const hasScriptInjection = html.includes('data-pi-proxy="url-rewriting"') ||
                                  html.includes('[PI-Proxy]') ||
                                  html.includes('rewriteUrlForJs');

      // Check for base href injection
      const hasBaseHref = /<base[^>]*href/i.test(html);

      // Extract script content if present
      const scriptMatch = html.match(/<script[^>]*data-pi-proxy="url-rewriting"[^>]*>([\s\S]*?)<\/script>/i);
      const scriptContent = scriptMatch ? scriptMatch[1] : null;

      if (hasScriptInjection || scriptContent) {
        results.scriptInjectionFound.push({
          url: url.substring(0, 150),
          hasInjection: hasScriptInjection,
          hasScriptContent: !!scriptContent,
          scriptLength: scriptContent ? scriptContent.length : 0,
          hasBaseHref
        });

        if (scriptContent) {
          // Extract PROXY_BASE from script
          const proxyBaseMatch = scriptContent.match(/const PROXY_BASE = (.*?);/);
          const targetOriginMatch = scriptContent.match(/const TARGET_ORIGIN = (.*?);/);
          
          results.urlRewritingScripts.push({
            url: url.substring(0, 150),
            proxyBase: proxyBaseMatch ? proxyBaseMatch[1] : null,
            targetOrigin: targetOriginMatch ? targetOriginMatch[1] : null,
            scriptLength: scriptContent.length
          });
        }
      }

      results.htmlResponses.push({
        url: url.substring(0, 150),
        isProxyRequest,
        hasScriptInjection,
        hasBaseHref,
        htmlLength: html.length,
        status: response.status
      });
    }
  });

  return results;
}

function compareScriptInjection(prod, localhost) {
  const comparison = {
    proxyOrigin: {
      production: prod.proxyOrigin,
      localhost: localhost.proxyOrigin,
      match: prod.proxyOrigin === localhost.proxyOrigin
    },
    htmlResponses: {
      production: prod.htmlResponses.length,
      localhost: localhost.htmlResponses.length,
      diff: prod.htmlResponses.length - localhost.htmlResponses.length
    },
    scriptInjection: {
      production: prod.scriptInjectionFound.length,
      localhost: localhost.scriptInjectionFound.length,
      diff: prod.scriptInjectionFound.length - localhost.scriptInjectionFound.length
    },
    urlRewritingScripts: {
      production: prod.urlRewritingScripts.length,
      localhost: localhost.urlRewritingScripts.length,
      diff: prod.urlRewritingScripts.length - localhost.urlRewritingScripts.length
    },
    baseHrefInjection: {
      production: prod.htmlResponses.filter(h => h.hasBaseHref).length,
      localhost: localhost.htmlResponses.filter(h => h.hasBaseHref).length
    }
  };

  return comparison;
}

function printScriptAnalysis(prod, localhost, comparison) {
  console.log('\n' + '='.repeat(80));
  console.log('SCRIPT INJECTION ANALYSIS');
  console.log('='.repeat(80) + '\n');

  console.log('PROXY ORIGIN:');
  console.log(`  Production:  ${prod.proxyOrigin || 'NOT FOUND'}`);
  console.log(`  Localhost:   ${localhost.proxyOrigin || 'NOT FOUND'}`);
  console.log(`  Match:       ${comparison.proxyOrigin.match ? 'YES' : 'NO'}\n`);

  console.log('HTML RESPONSES:');
  console.log(`  Production:  ${comparison.htmlResponses.production}`);
  console.log(`  Localhost:   ${comparison.htmlResponses.localhost}`);
  console.log(`  Difference:  ${comparison.htmlResponses.diff}\n`);

  console.log('SCRIPT INJECTION DETECTED:');
  console.log(`  Production:  ${comparison.scriptInjection.production} pages`);
  console.log(`  Localhost:   ${comparison.scriptInjection.localhost} pages`);
  console.log(`  Difference:  ${comparison.scriptInjection.diff}\n`);

  console.log('URL REWRITING SCRIPTS:');
  console.log(`  Production:  ${comparison.urlRewritingScripts.production}`);
  console.log(`  Localhost:   ${comparison.urlRewritingScripts.localhost}`);
  console.log(`  Difference:  ${comparison.urlRewritingScripts.diff}\n`);

  console.log('BASE HREF INJECTION:');
  console.log(`  Production:  ${comparison.baseHrefInjection.production}`);
  console.log(`  Localhost:   ${comparison.baseHrefInjection.localhost}\n`);

  if (prod.scriptInjectionFound.length > 0) {
    console.log('\nPRODUCTION SCRIPT INJECTION DETAILS:');
    prod.scriptInjectionFound.slice(0, 5).forEach((item, i) => {
      console.log(`  ${i + 1}. ${item.url}`);
      console.log(`     Has injection: ${item.hasInjection}, Has script content: ${item.hasScriptContent}`);
      console.log(`     Script length: ${item.scriptLength}, Has base href: ${item.hasBaseHref}`);
    });
  }

  if (localhost.scriptInjectionFound.length > 0) {
    console.log('\nLOCALHOST SCRIPT INJECTION DETAILS:');
    localhost.scriptInjectionFound.slice(0, 5).forEach((item, i) => {
      console.log(`  ${i + 1}. ${item.url}`);
      console.log(`     Has injection: ${item.hasInjection}, Has script content: ${item.hasScriptContent}`);
      console.log(`     Script length: ${item.scriptLength}, Has base href: ${item.hasBaseHref}`);
    });
  }

  if (prod.urlRewritingScripts.length > 0) {
    console.log('\nPRODUCTION URL REWRITING SCRIPT CONFIG:');
    prod.urlRewritingScripts.slice(0, 3).forEach((item, i) => {
      console.log(`  ${i + 1}. ${item.url}`);
      console.log(`     PROXY_BASE: ${item.proxyBase || 'NOT FOUND'}`);
      console.log(`     TARGET_ORIGIN: ${item.targetOrigin || 'NOT FOUND'}`);
    });
  }

  if (localhost.urlRewritingScripts.length > 0) {
    console.log('\nLOCALHOST URL REWRITING SCRIPT CONFIG:');
    localhost.urlRewritingScripts.slice(0, 3).forEach((item, i) => {
      console.log(`  ${i + 1}. ${item.url}`);
      console.log(`     PROXY_BASE: ${item.proxyBase || 'NOT FOUND'}`);
      console.log(`     TARGET_ORIGIN: ${item.targetOrigin || 'NOT FOUND'}`);
    });
  }

  // Check for HTML responses without script injection
  const prodWithoutInjection = prod.htmlResponses.filter(h => h.isProxyRequest && !h.hasScriptInjection);
  const localhostWithoutInjection = localhost.htmlResponses.filter(h => h.isProxyRequest && !h.hasScriptInjection);

  if (prodWithoutInjection.length > 0 || localhostWithoutInjection.length > 0) {
    console.log('\n⚠️  HTML RESPONSES WITHOUT SCRIPT INJECTION:');
    if (prodWithoutInjection.length > 0) {
      console.log(`\n  Production (${prodWithoutInjection.length}):`);
      prodWithoutInjection.slice(0, 5).forEach(item => {
        console.log(`    - ${item.url} [${item.status}]`);
      });
    }
    if (localhostWithoutInjection.length > 0) {
      console.log(`\n  Localhost (${localhostWithoutInjection.length}):`);
      localhostWithoutInjection.slice(0, 5).forEach(item => {
        console.log(`    - ${item.url} [${item.status}]`);
      });
    }
  }

  console.log('\n' + '='.repeat(80));
}

function main() {
  const args = process.argv.slice(2);
  if (args.length < 2) {
    console.error('Usage: node analyze-har-scripts.js <production.har> <localhost.har>');
    process.exit(1);
  }

  const [prodPath, localhostPath] = args;

  console.log('Parsing HAR files...');
  const prodHAR = parseHAR(prodPath);
  const localhostHAR = parseHAR(localhostPath);

  console.log('Analyzing script injection in production...');
  const prodAnalysis = analyzeScriptInjection(prodHAR, 'Production');

  console.log('Analyzing script injection in localhost...');
  const localhostAnalysis = analyzeScriptInjection(localhostHAR, 'Localhost');

  console.log('Comparing script injection...');
  const comparison = compareScriptInjection(prodAnalysis, localhostAnalysis);

  printScriptAnalysis(prodAnalysis, localhostAnalysis, comparison);
}

if (require.main === module) {
  main();
}

module.exports = { analyzeScriptInjection, compareScriptInjection };
