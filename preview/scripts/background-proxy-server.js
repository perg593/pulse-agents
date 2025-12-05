#!/usr/bin/env node

const express = require('express');
const { URL } = require('url');
const path = require('path');

// Load centralized port configuration
let PORT;
try {
  const configPath = path.resolve(__dirname, '../../config/ports.js');
  const config = require(configPath);
  PORT = config.getPort('BACKGROUND_PROXY_PORT', 'development');
} catch (error) {
  // Fallback to environment variable or default
  PORT = Number.parseInt(process.env.BACKGROUND_PROXY_PORT || '3100', 10);
}

const app = express();
const ALLOWLIST = (process.env.BACKGROUND_PROXY_ALLOWLIST || '*')
  .split(',')
  .map((entry) => entry.trim())
  .filter(Boolean);
const BLOCKED_HOSTS = (process.env.BACKGROUND_PROXY_BLOCKLIST || 'localhost,127.,::1')
  .split(',')
  .map((entry) => entry.trim())
  .filter(Boolean);

const DEFAULT_USER_AGENT =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 PulsePreviewProxy/1.0';

const CONSENT_BANNER_SELECTORS = [
  '#onetrust-banner-sdk',
  '.onetrust-pc-dark-filter',
  '.optanon-alert-box-wrapper',
  '.cc-window',
  '.cc-banner',
  '.cookie-consent',
  '.cookie-consent-container',
  '#cookie-consent',
  '.js-consent-banner',
  '.app-consent-banner',
  '.osano-cm-window',
  '.osano-cm-wrapper',
  '.cky-consent-container',
  '.cky-overlay',
  '.gdprCookieMessage',
  '#cookiebanner',
  '.cookieBanner',
  '.truste_overlay',
  '.truste_box_overlay'
];

function isHostAllowed(hostname) {
  if (!hostname) return false;
  const lower = hostname.toLowerCase();
  if (BLOCKED_HOSTS.some((blocked) => lower.startsWith(blocked))) {
    return false;
  }
  if (ALLOWLIST.includes('*')) return true;
  return ALLOWLIST.some((pattern) => {
    if (!pattern) return false;
    const normalized = pattern.toLowerCase();
    return lower === normalized || lower.endsWith(`.${normalized}`);
  });
}

function resolveTarget(raw) {
  let url;
  try {
    url = new URL(raw);
  } catch (error) {
    throw new Error('Invalid URL');
  }
  if (!['http:', 'https:'].includes(url.protocol)) {
    throw new Error('Only http/https protocols supported');
  }
  if (!isHostAllowed(url.hostname)) {
    throw new Error(`Host not allowed: ${url.hostname}`);
  }
  return url;
}

app.options('/proxy', (req, res) => {
  const allowHeaders = req.headers['access-control-request-headers'] || 'Accept,Content-Type,User-Agent';
  res.setHeader('access-control-allow-origin', '*');
  res.setHeader('access-control-allow-headers', allowHeaders);
  res.setHeader('access-control-allow-methods', 'GET,HEAD,OPTIONS');
  res.setHeader('access-control-max-age', '86400');
  res.status(204).end();
});

app.get('/background-proxy/health', (req, res) => {
  res.json({
    status: 'ok',
    port: PORT,
    allowlist: ALLOWLIST
  });
});

app.get('/proxy', async (req, res) => {
  const targetRaw = req.query.url;
  if (!targetRaw || typeof targetRaw !== 'string') {
    res.status(400).json({ error: 'Missing url query parameter' });
    return;
  }

  let target;
  try {
    target = resolveTarget(targetRaw);
  } catch (error) {
    res.status(400).json({ error: error.message });
    return;
  }

  try {
    const incomingHeaders = req.headers;
    const upstreamHeaders = {
      'User-Agent': incomingHeaders['user-agent'] || DEFAULT_USER_AGENT,
      Accept: incomingHeaders['accept'] || '*/*',
      'Accept-Language': incomingHeaders['accept-language'] || 'en-US,en;q=0.9',
      'Accept-Encoding': incomingHeaders['accept-encoding'] || 'gzip, deflate, br',
      Referer: incomingHeaders['referer'] || target.origin,
      Origin: target.origin,
      Cookie: incomingHeaders.cookie || undefined,
      'Sec-Fetch-Dest': incomingHeaders['sec-fetch-dest'] || 'document',
      'Sec-Fetch-Mode': incomingHeaders['sec-fetch-mode'] || 'navigate',
      'Sec-Fetch-Site': incomingHeaders['sec-fetch-site'] || 'none'
    };

    Object.keys(upstreamHeaders).forEach((key) => {
      if (upstreamHeaders[key] === undefined) {
        delete upstreamHeaders[key];
      }
    });

    const response = await fetch(target.toString(), {
      headers: upstreamHeaders,
      redirect: 'follow'
    });

    const contentType = response.headers.get('content-type') || '';
    res.status(response.status);
    const allowHeaders = req.headers['access-control-request-headers'] || 'Accept,Content-Type,User-Agent';
    res.setHeader('access-control-allow-origin', '*');
    res.setHeader('access-control-allow-headers', allowHeaders);
    res.setHeader('access-control-allow-methods', 'GET,HEAD,OPTIONS');
    res.setHeader('access-control-expose-headers', 'cache-control,expires,pragma,content-type');
    if (contentType) {
      res.setHeader('content-type', contentType);
    }

    // Remove frame-blocking headers
    removeFrameBlockingHeaders(response, res);

    const passthroughHeaders = ['cache-control', 'expires', 'pragma'];
    passthroughHeaders.forEach((header) => {
      const value = response.headers.get(header);
      if (value) {
        res.setHeader(header, value);
      }
    });

    if (contentType.includes('text/html')) {
      let body = await response.text();
      if (!/base\s+href=/i.test(body)) {
        // Use the target URL's directory as base href
        // Handle query params and fragments by removing them first
        let baseHref = target.href;
        try {
          const url = new URL(baseHref);
          // Remove query and fragment, keep pathname
          url.search = '';
          url.hash = '';
          baseHref = url.toString();
          // Ensure it ends with / if it's a directory
          if (!baseHref.endsWith('/') && !baseHref.match(/\/[^/]*\.[^/]*$/)) {
            baseHref += '/';
          }
        } catch (_error) {
          // Fallback: simple string replacement
          baseHref = target.href.replace(/[^/]*$/, '').replace(/[?#].*$/, '');
          if (!baseHref.endsWith('/')) {
            baseHref += '/';
          }
        }
        
        // Escape HTML entities in baseHref
        const escapedBaseHref = baseHref
          .replace(/&/g, '&amp;')
          .replace(/"/g, '&quot;')
          .replace(/'/g, '&#39;');
        
        if (/<head[^>]*>/i.test(body)) {
          body = body.replace(/<head([^>]*)>/i, `<head$1><base href="${escapedBaseHref}">`);
        } else {
          body = `<base href="${escapedBaseHref}">${body}`;
        }
      }
      // Rewrite resource URLs to go through proxy
      body = rewriteResourceUrls(body, target, req);
      body = injectUrlRewritingScript(body, target, req);
      body = injectConsentCleanup(body);
      
      // Add 403 error messaging if applicable
      if (response.status === 403) {
        body = inject403Message(body, target);
      }
      
      res.send(body);
    } else {
      const buffer = Buffer.from(await response.arrayBuffer());
      res.send(buffer);
    }
  } catch (error) {
    console.error('Proxy error', target.toString(), error.message);
    res.status(502).json({
      error: `Failed to fetch ${target.toString()}: ${error.message}`
    });
  }
});

app.listen(PORT, () => {
  console.log(`Background proxy listening on http://localhost:${PORT}`);
});

/**
 * Rewrites resource URLs in HTML to go through the proxy.
 * Handles src, href, srcset, and other URL attributes.
 *
 * @param {string} html - The HTML content to rewrite
 * @param {URL} target - The target URL being proxied
 * @param {object} req - Express request object (to determine proxy origin)
 * @returns {string} HTML with rewritten URLs
 */
function rewriteResourceUrls(html, target, req) {
  const protocol = req.protocol || 'http';
  const host = req.get('host') || 'localhost:3100';
  const proxyOrigin = `${protocol}://${host}`;
  const proxyBase = proxyOrigin.replace(/\/$/, '');
  const targetOrigin = target.origin;

  // Don't rewrite if proxy origin is not available
  if (!proxyBase) return html;

  let output = html;

  // Rewrite URLs in common attributes: src, href, srcset, data-src, etc.
  const urlAttributes = [
    'src',
    'href',
    'srcset',
    'data-src',
    'data-href',
    'data-srcset',
    'action',
    'formaction',
    'cite',
    'poster',
    'background',
    'content'
  ];

  urlAttributes.forEach((attr) => {
    // Match attribute="value" or attribute='value' or attribute=value
    const attrRegex = new RegExp(
      `(${attr}\\s*=\\s*["'])([^"']+)(["'])`,
      'gi'
    );
    output = output.replace(attrRegex, (match, prefix, url, suffix) => {
      const rewritten = rewriteUrl(url, targetOrigin, proxyBase);
      return `${prefix}${rewritten}${suffix}`;
    });

    // Also handle unquoted attributes (less common but possible)
    const unquotedRegex = new RegExp(
      `(${attr}\\s*=\\s*)([^\\s>]+)`,
      'gi'
    );
    output = output.replace(unquotedRegex, (match, prefix, url) => {
      const trimmed = url.trim();
      // Skip if it's clearly not a URL (data URLs, javascript:, etc. are handled by rewriteUrl)
      // But process relative paths and absolute URLs
      if (trimmed && !/^(data:|blob:|javascript:|mailto:|tel:|#|about:)/i.test(trimmed)) {
        const rewritten = rewriteUrl(trimmed, targetOrigin, proxyBase);
        return `${prefix}${rewritten}`;
      }
      return match;
    });
  });

  // Handle srcset attribute specially (can contain multiple URLs)
  const srcsetRegex = /srcset\s*=\s*["']([^"']+)["']/gi;
  output = output.replace(srcsetRegex, (match, srcsetValue) => {
    // srcset format: "url1 1x, url2 2x, url3 100w"
    const rewritten = srcsetValue
      .split(',')
      .map((entry) => {
        const trimmed = entry.trim();
        const parts = trimmed.split(/\s+/);
        if (parts.length === 0) return trimmed;
        const url = parts[0];
        const descriptors = parts.slice(1).join(' ');
        const rewrittenUrl = rewriteUrl(url, targetOrigin, proxyBase);
        return descriptors ? `${rewrittenUrl} ${descriptors}` : rewrittenUrl;
      })
      .join(', ');
    return match.replace(srcsetValue, rewritten);
  });

  // Handle CSS url() references in style attributes and style tags
  const cssUrlRegex = /url\s*\(\s*["']?([^"')]+)["']?\s*\)/gi;
  output = output.replace(cssUrlRegex, (match, url) => {
    const trimmed = url.trim();
    // Skip data URLs and other special schemes (handled by rewriteUrl)
    // But process relative paths and absolute URLs
    if (trimmed && !/^(data:|blob:|javascript:|mailto:|tel:|#|about:)/i.test(trimmed)) {
      const rewritten = rewriteUrl(trimmed, targetOrigin, proxyBase);
      return match.replace(url, rewritten);
    }
    return match;
  });

  return output;
}

/**
 * Rewrites a single URL to go through the proxy if needed.
 *
 * @param {string} url - The URL to potentially rewrite
 * @param {string} targetOrigin - The origin of the target page
 * @param {string} proxyBase - The base URL of the proxy
 * @returns {string} The rewritten URL (or original if no rewrite needed)
 */
function rewriteUrl(url, targetOrigin, proxyBase) {
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

  // Handle protocol-relative URLs (//example.com)
  let absoluteUrl = trimmed;
  if (trimmed.startsWith('//')) {
    absoluteUrl = `https:${trimmed}`;
  } else if (!/^https?:\/\//i.test(trimmed)) {
    // Relative URL - resolve against target origin
    // This handles:
    // - Root-relative paths: /path/to/file.js
    // - Relative paths: ./path/to/file.js or path/to/file.js
    // - Parent directory: ../path/to/file.js
    try {
      // Use targetOrigin as base, which should be the full URL of the target page
      // If targetOrigin is just an origin (e.g., "https://example.com"), 
      // new URL will resolve relative paths correctly
      const baseUrl = targetOrigin.endsWith('/') ? targetOrigin : `${targetOrigin}/`;
      absoluteUrl = new URL(trimmed, baseUrl).toString();
    } catch (_error) {
      // If URL resolution fails, return original
      return url;
    }
  }

  // Skip same-origin URLs (relative to proxy origin)
  try {
    const parsed = new URL(absoluteUrl);
    const proxyParsed = new URL(proxyBase);
    // Don't proxy URLs that are already on the proxy origin
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

/**
 * Injects JavaScript to intercept fetch, XMLHttpRequest, and dynamic import() calls
 * to rewrite URLs through the proxy.
 *
 * @param {string} html - The HTML content
 * @param {URL} target - The target URL being proxied
 * @param {object} req - Express request object (to determine proxy origin)
 * @returns {string} HTML with URL rewriting script injected
 */
function injectUrlRewritingScript(html, target, req) {
  const protocol = req.protocol || 'http';
  const host = req.get('host') || 'localhost:3100';
  const proxyOrigin = `${protocol}://${host}`;
  const proxyBase = proxyOrigin.replace(/\/$/, '');
  const targetOrigin = target.origin;

  if (!proxyBase) return html;

  // Create URL rewriting function for JavaScript
  // This matches the logic in rewriteUrl() but runs in the browser context
  const scriptContent = `
(function() {
  'use strict';
  
  // Debug logging
  console.log('[PI-Proxy] URL rewriting script starting...');
  
  const PROXY_BASE = ${JSON.stringify(proxyBase)};
  const TARGET_ORIGIN = ${JSON.stringify(targetOrigin)};
  
  // Check if we're on a proxied page - use multiple detection methods
  const currentHref = (document.location && document.location.href) || (window.location && window.location.href) || '';
  const referrer = document.referrer || '';
  const proxyOrigin = PROXY_BASE.replace(/\\/$/, '');
  const currentPageOrigin = (document.location && document.location.origin) || (window.location && window.location.origin) || '';
  
  const isProxied = currentHref.includes('/proxy?url=') ||
                    currentHref.includes('proxy%3Furl%3D') ||
                    referrer.includes('/proxy?url=') ||
                    currentPageOrigin === proxyOrigin ||
                    (currentPageOrigin && proxyOrigin && currentPageOrigin.includes(proxyOrigin.split('://')[1]?.split(':')[0]));
  
  console.log('[PI-Proxy] Detection check:', {
    currentHref: currentHref.substring(0, 100),
    referrer: referrer.substring(0, 100),
    currentPageOrigin,
    proxyOrigin,
    isProxied
  });
  
  // Always run if we're on the proxy origin (even if URL pattern doesn't match)
  // This ensures the script runs for all pages served through the proxy
  if (!isProxied) {
    console.log('[PI-Proxy] Not a proxied page, skipping URL rewriting');
    return;
  }
  
  console.log('[PI-Proxy] URL rewriting script active');
  
  // URL rewriting function (matches server-side rewriteUrl logic)
  function rewriteUrlForJs(url, baseOrigin) {
    if (!url || typeof url !== 'string') return url;
    
    const trimmed = url.trim();
    if (!trimmed) return url;
    
    // Skip data URLs, blob URLs, and javascript: URLs
    if (/^(data:|blob:|javascript:|mailto:|tel:|#|about:)/i.test(trimmed)) {
      return url;
    }
    
    // Skip URLs that are already proxied
    if (trimmed.includes('/proxy?url=')) {
      return url;
    }
    
    // Handle protocol-relative URLs (//example.com)
    let absoluteUrl = trimmed;
    const isRelative = !/^https?:\\/\\//i.test(trimmed) && !trimmed.startsWith('//');
    
    if (trimmed.startsWith('//')) {
      absoluteUrl = 'https:' + trimmed;
    } else if (isRelative) {
      // Relative URL - resolve against base origin (target origin, not proxy origin)
      try {
        const baseUrl = baseOrigin.endsWith('/') ? baseOrigin : baseOrigin + '/';
        absoluteUrl = new URL(trimmed, baseUrl).toString();
      } catch (e) {
        return url;
      }
    }
    
    // Skip same-origin URLs ONLY if they're NOT relative URLs that resolved to proxy origin
    // Relative URLs should always be proxied, even if they resolve to the proxy origin
    // (because they should resolve to the target origin instead)
    try {
      const parsed = new URL(absoluteUrl);
      const proxyParsed = new URL(PROXY_BASE);
      // Only skip if it's an absolute URL that's already on the proxy origin
      // Don't skip relative URLs that happened to resolve to proxy origin
      if (!isRelative && parsed.origin === proxyParsed.origin) {
        return url;
      }
    } catch (e) {
      // If parsing fails, proceed with proxying
    }
    
    // Rewrite to proxy URL
    const encoded = encodeURIComponent(absoluteUrl);
    return PROXY_BASE + '/proxy?url=' + encoded;
  }
  
  // Get current page origin for resolving relative URLs
  function getCurrentOrigin() {
    try {
      // Try multiple methods to get the original target URL
      const locationHref = (document.location && document.location.href) || (window.location && window.location.href) || '';
      
      // Method 1: Extract from proxy URL parameter
      let match = locationHref.match(/proxy[?&]url=([^&]+)/);
      if (!match) {
        // Try URL-encoded version
        match = locationHref.match(/proxy%3Furl%3D([^&]+)/);
      }
      if (match) {
        const decoded = decodeURIComponent(match[1]);
        const url = new URL(decoded);
        const pathname = url.pathname.replace(/\\/[^/]*$/, '');
        const baseOrigin = url.origin + (pathname || '/');
        console.log('[PI-Proxy] Extracted origin from proxy URL:', baseOrigin);
        return baseOrigin;
      }
      
      // Method 2: Use document.baseURI if available
      if (document.baseURI) {
        try {
          const baseUrl = new URL(document.baseURI);
          const baseOrigin = baseUrl.origin + baseUrl.pathname.replace(/\\/[^/]*$/, '');
          console.log('[PI-Proxy] Using document.baseURI:', baseOrigin);
          return baseOrigin;
        } catch (e) {
          // Ignore
        }
      }
      
      // Method 3: Use referrer if it contains the target origin
      if (document.referrer) {
        try {
          const referrerUrl = new URL(document.referrer);
          const match = referrerUrl.searchParams.get('url');
          if (match) {
            const decoded = decodeURIComponent(match);
            const url = new URL(decoded);
            const baseOrigin = url.origin + url.pathname.replace(/\\/[^/]*$/, '');
            console.log('[PI-Proxy] Extracted origin from referrer:', baseOrigin);
            return baseOrigin;
          }
        } catch (e) {
          // Ignore
        }
      }
      
      // Fallback: Use TARGET_ORIGIN (injected constant) instead of current origin
      // Current origin would be the proxy origin, which is wrong for relative URL resolution
      if (TARGET_ORIGIN) {
        const baseOrigin = TARGET_ORIGIN.endsWith('/') ? TARGET_ORIGIN : TARGET_ORIGIN + '/';
        console.log('[PI-Proxy] Using TARGET_ORIGIN fallback:', baseOrigin);
        return baseOrigin;
      }
      
      // Last resort: Use current page origin (should rarely happen)
      const currentPageOrigin = (document.location && document.location.origin) || (window.location && window.location.origin) || '';
      const currentPath = (document.location && document.location.pathname) || (window.location && window.location.pathname) || '';
      const baseOrigin = currentPageOrigin + currentPath.replace(/\\/[^/]*$/, '');
      console.log('[PI-Proxy] Using current page origin fallback (may be incorrect):', baseOrigin);
      return baseOrigin;
    } catch (e) {
      console.error('[PI-Proxy] Error getting current origin:', e);
      // Final fallback
      return (window.location && window.location.origin) || '';
    }
  }
  
  const currentOrigin = getCurrentOrigin();
  console.log('[PI-Proxy] Current origin for URL resolution:', currentOrigin);
  
  // Intercept fetch()
  if (typeof window.fetch !== 'undefined') {
    const originalFetch = window.fetch;
    window.fetch = function(input, init) {
      // Handle string URL
      if (typeof input === 'string') {
        const rewritten = rewriteUrlForJs(input, currentOrigin);
        if (rewritten !== input) {
          console.log('[PI-Proxy] fetch() rewritten:', input, '->', rewritten);
        }
        return originalFetch.call(this, rewritten, init);
      }
      // Handle Request object
      if (input && typeof input === 'object') {
        if (input instanceof Request) {
          const rewritten = rewriteUrlForJs(input.url, currentOrigin);
          if (rewritten !== input.url) {
            console.log('[PI-Proxy] fetch(Request) rewritten:', input.url, '->', rewritten);
          }
          return originalFetch.call(this, rewritten, init || {});
        } else if (input.url) {
          // Object with url property
          const rewritten = rewriteUrlForJs(input.url, currentOrigin);
          if (rewritten !== input.url) {
            console.log('[PI-Proxy] fetch(object) rewritten:', input.url, '->', rewritten);
          }
          return originalFetch.call(this, rewritten, init);
        }
      }
      // Fallback to original
      return originalFetch.call(this, input, init);
    };
    console.log('[PI-Proxy] fetch() interception installed');
  }
  
  // Intercept XMLHttpRequest.open()
  if (typeof XMLHttpRequest !== 'undefined') {
    const OriginalXHR = XMLHttpRequest;
    XMLHttpRequest.prototype.open = function(method, url, async, user, password) {
      const rewritten = rewriteUrlForJs(url, currentOrigin);
      if (rewritten !== url) {
        console.log('[PI-Proxy] XHR.open() rewritten:', url, '->', rewritten);
      }
      return OriginalXHR.prototype.open.call(this, method, rewritten, async, user, password);
    };
    console.log('[PI-Proxy] XMLHttpRequest interception installed');
  }
  
  // Intercept dynamic script tag creation (for webpack code splitting)
  // CRITICAL: Intercept on the prototype FIRST so it applies to ALL script elements
  if (typeof HTMLScriptElement !== 'undefined' && HTMLScriptElement.prototype) {
    const originalSrcDescriptor = Object.getOwnPropertyDescriptor(HTMLScriptElement.prototype, 'src');
    if (originalSrcDescriptor && originalSrcDescriptor.set) {
      Object.defineProperty(HTMLScriptElement.prototype, 'src', {
        set: function(value) {
          const rewritten = rewriteUrlForJs(value, currentOrigin);
          if (rewritten !== value) {
            console.log('[PI-Proxy] HTMLScriptElement.prototype.src rewritten:', value, '->', rewritten);
          }
          originalSrcDescriptor.set.call(this, rewritten);
        },
        get: originalSrcDescriptor.get || function() {
          return this.getAttribute('src');
        },
        configurable: true,
        enumerable: true
      });
      console.log('[PI-Proxy] HTMLScriptElement.prototype.src interception installed');
    }
    
    // Also intercept setAttribute on the prototype
    const originalSetAttribute = HTMLScriptElement.prototype.setAttribute;
    HTMLScriptElement.prototype.setAttribute = function(name, value) {
      if (name.toLowerCase() === 'src' && typeof value === 'string') {
        const rewritten = rewriteUrlForJs(value, currentOrigin);
        if (rewritten !== value) {
          console.log('[PI-Proxy] HTMLScriptElement.prototype.setAttribute("src") rewritten:', value, '->', rewritten);
        }
        return originalSetAttribute.call(this, name, rewritten);
      }
      return originalSetAttribute.call(this, name, value);
    };
    console.log('[PI-Proxy] HTMLScriptElement.prototype.setAttribute interception installed');
  }
  
  if (document && document.createElement) {
    const originalCreateElement = document.createElement;
    document.createElement = function(tagName, options) {
      const element = originalCreateElement.call(this, tagName, options);
      // Note: src property interception is already handled at prototype level above
      // But we can add element-specific logic here if needed
      return element;
    };
    
    // Also intercept appendChild and insertBefore to catch scripts added dynamically
    const originalAppendChild = Node.prototype.appendChild;
    const originalInsertBefore = Node.prototype.insertBefore;
    
    // Helper function to rewrite script src
    function rewriteScriptSrc(scriptElement) {
      if (!scriptElement || scriptElement.tagName !== 'SCRIPT') return;
      
      // Check both src property and src attribute
      const srcValue = scriptElement.src || scriptElement.getAttribute('src');
      if (srcValue && typeof srcValue === 'string') {
        const rewritten = rewriteUrlForJs(srcValue, currentOrigin);
        if (rewritten !== srcValue) {
          console.log('[PI-Proxy] Rewriting script src:', srcValue, '->', rewritten);
          // Set both property and attribute to be safe
          try {
            scriptElement.src = rewritten;
          } catch (e) {
            // If property setter fails, use setAttribute
            scriptElement.setAttribute('src', rewritten);
          }
          if (scriptElement.getAttribute('src') !== rewritten) {
            scriptElement.setAttribute('src', rewritten);
          }
        }
      }
    }
    
    Node.prototype.appendChild = function(child) {
      rewriteScriptSrc(child);
      return originalAppendChild.call(this, child);
    };
    
    Node.prototype.insertBefore = function(newNode, referenceNode) {
      rewriteScriptSrc(newNode);
      return originalInsertBefore.call(this, newNode, referenceNode);
    };
    
    // Also intercept innerHTML/outerHTML for script tags (less common but possible)
    const originalSetInnerHTML = Object.getOwnPropertyDescriptor(Element.prototype, 'innerHTML')?.set;
    if (originalSetInnerHTML) {
      Object.defineProperty(Element.prototype, 'innerHTML', {
        set: function(value) {
          // Check if value contains script tags with src attributes
          if (typeof value === 'string' && /<script[^>]*src=["']([^"']+)["']/i.test(value)) {
            const rewritten = value.replace(/<script([^>]*)src=["']([^"']+)["']/gi, (match, attrs, src) => {
              const rewrittenSrc = rewriteUrlForJs(src, currentOrigin);
              if (rewrittenSrc !== src) {
                console.log('[PI-Proxy] innerHTML script src rewritten:', src, '->', rewrittenSrc);
              }
              return '<script' + attrs + 'src="' + rewrittenSrc + '"';
            });
            return originalSetInnerHTML.call(this, rewritten);
          }
          return originalSetInnerHTML.call(this, value);
        },
        get: function() {
          return originalSetInnerHTML ? this.innerHTML : '';
        },
        configurable: true
      });
    }
    
    console.log('[PI-Proxy] Script tag interception installed');
  }
  
  console.log('[PI-Proxy] URL rewriting script initialization complete');
})();
`;

  const scriptTag = `<script data-pi-proxy="url-rewriting">${scriptContent}</script>`;

  let output = html;

  // Inject script early in head, before other scripts
  if (/<head[^>]*>/i.test(output)) {
    // Try to inject right after <head> tag, before any existing scripts
    const headMatch = output.match(/<head([^>]*)>/i);
    if (headMatch) {
      const afterHead = output.indexOf('>', headMatch.index) + 1;
      output = output.slice(0, afterHead) + scriptTag + output.slice(afterHead);
    } else {
      output = output.replace(/<head([^>]*)>/i, `<head$1>${scriptTag}`);
    }
  } else {
    // If no head tag, inject at the very beginning
    output = scriptTag + output;
  }

  return output;
}

/**
 * Removes headers that prevent iframe embedding.
 *
 * @param {Response} upstreamResponse - The upstream fetch response
 * @param {object} res - Express response object
 */
function removeFrameBlockingHeaders(upstreamResponse, res) {
  // Remove X-Frame-Options to allow iframe embedding
  const frameOptions = upstreamResponse.headers.get('x-frame-options');
  if (frameOptions) {
    // Don't set it - it will be omitted from response
  }

  // Remove or modify Content-Security-Policy frame-ancestors directive
  const csp = upstreamResponse.headers.get('content-security-policy');
  if (csp) {
    // Remove frame-ancestors directive to allow embedding
    const modifiedCsp = csp
      .split(';')
      .map((directive) => {
        const trimmed = directive.trim();
        if (/^frame-ancestors/i.test(trimmed)) {
          return '';
        }
        return trimmed;
      })
      .filter(Boolean)
      .join('; ');
    if (modifiedCsp) {
      res.setHeader('content-security-policy', modifiedCsp);
    }
    // If empty, don't set header
  }

  // Also handle Content-Security-Policy-Report-Only
  const cspReportOnly = upstreamResponse.headers.get(
    'content-security-policy-report-only'
  );
  if (cspReportOnly) {
    const modifiedCsp = cspReportOnly
      .split(';')
      .map((directive) => {
        const trimmed = directive.trim();
        if (/^frame-ancestors/i.test(trimmed)) {
          return '';
        }
        return trimmed;
      })
      .filter(Boolean)
      .join('; ');
    if (modifiedCsp) {
      res.setHeader('content-security-policy-report-only', modifiedCsp);
    }
    // If empty, don't set header
  }
}

/**
 * Injects a subtle 403 error message banner into HTML.
 * Informs users that the site blocked the proxy request.
 *
 * @param {string} html - The HTML content
 * @param {URL} target - The target URL that was blocked
 * @returns {string} HTML with 403 message injected
 */
function inject403Message(html, target) {
  const message = `This site (${target.hostname}) blocked the preview proxy request.`;
  
  const styleBlock = `
<style data-pi-proxy="403-message">
.pi-proxy-403-banner {
  position: fixed !important;
  top: 0 !important;
  left: 0 !important;
  right: 0 !important;
  z-index: 999999 !important;
  background: linear-gradient(135deg, #ff6b6b 0%, #ee5a6f 100%) !important;
  color: white !important;
  padding: 12px 20px !important;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif !important;
  font-size: 14px !important;
  line-height: 1.5 !important;
  text-align: center !important;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15) !important;
  border-bottom: 1px solid rgba(255, 255, 255, 0.2) !important;
  display: block !important;
  visibility: visible !important;
  opacity: 1 !important;
  margin: 0 !important;
  width: 100% !important;
  box-sizing: border-box !important;
}
.pi-proxy-403-banner strong {
  font-weight: 600 !important;
  display: block !important;
  margin-bottom: 4px !important;
}
.pi-proxy-403-banner .pi-proxy-403-detail {
  font-size: 12px !important;
  opacity: 0.9 !important;
}
</style>`;

  const bannerBlock = `
<div class="pi-proxy-403-banner" data-pi-proxy="403-message" style="position:fixed!important;top:0!important;left:0!important;right:0!important;z-index:999999!important;background:linear-gradient(135deg,#ff6b6b 0%,#ee5a6f 100%)!important;color:white!important;padding:12px 20px!important;display:block!important;visibility:visible!important;opacity:1!important;">
  <strong>⚠️ Preview Blocked</strong>
  <span class="pi-proxy-403-detail">${message}</span>
</div>`;

  let output = html;

  // Inject styles in head
  if (/<head[^>]*>/i.test(output)) {
    output = output.replace(/<head([^>]*)>/i, `<head$1>${styleBlock}`);
  } else {
    output = `${styleBlock}${output}`;
  }

  // Inject banner at start of body
  if (/<body[^>]*>/i.test(output)) {
    output = output.replace(/<body([^>]*)>/i, `<body$1>${bannerBlock}`);
  } else {
    output = `${bannerBlock}${output}`;
  }

  // Add script to ensure banner stays visible even if page scripts try to hide it
  const protectionScript = `
<script data-pi-proxy="403-protection">
(function() {
  function protectBanner() {
    const banner = document.querySelector('.pi-proxy-403-banner[data-pi-proxy="403-message"]');
    if (banner) {
      banner.style.setProperty('position', 'fixed', 'important');
      banner.style.setProperty('top', '0', 'important');
      banner.style.setProperty('left', '0', 'important');
      banner.style.setProperty('right', '0', 'important');
      banner.style.setProperty('z-index', '999999', 'important');
      banner.style.setProperty('display', 'block', 'important');
      banner.style.setProperty('visibility', 'visible', 'important');
      banner.style.setProperty('opacity', '1', 'important');
    }
  }
  protectBanner();
  ['DOMContentLoaded', 'load'].forEach(function(evt) {
    window.addEventListener(evt, protectBanner, {once: false});
  });
  setInterval(protectBanner, 1000);
})();
</script>`;

  // Inject protection script before closing body tag or at end
  if (/<\/body>/i.test(output)) {
    output = output.replace(/<\/body>/i, `${protectionScript}</body>`);
  } else {
    output = `${output}${protectionScript}`;
  }

  return output;
}

function injectConsentCleanup(html) {
  let output = html;
  const styleBlock = `\n<style data-pi-proxy="consent-hide">${CONSENT_BANNER_SELECTORS.join(
    ', '
  )}{display:none!important;visibility:hidden!important;opacity:0!important;}</style>`;
  if (/<head[^>]*>/i.test(output)) {
    output = output.replace(/<head([^>]*)>/i, `<head$1>${styleBlock}`);
  } else {
    output = `${styleBlock}${output}`;
  }

  const scriptBlock = `\n<script data-pi-proxy="consent-hide">(function(){const selectors=${JSON.stringify(
    CONSENT_BANNER_SELECTORS
  )};const hide=()=>{selectors.forEach((sel)=>{try{document.querySelectorAll(sel).forEach((node)=>{if(!node)return;node.style.setProperty('display','none','important');node.style.setProperty('visibility','hidden','important');node.style.setProperty('opacity','0','important');node.setAttribute('data-pi-proxy-hidden','true');if(node.parentElement&&node.parentElement.children.length===1&&node.parentElement.innerText.trim().length<2){node.parentElement.style.setProperty('display','none','important');}});}catch(e){}});};hide();['load','DOMContentLoaded'].forEach((evt)=>window.addEventListener(evt,hide,{once:false}));const interval=setInterval(hide,500);setTimeout(()=>clearInterval(interval),5000);})();</script>`;

  if (/<\/body>/i.test(output)) {
    output = output.replace(/<\/body>/i, `${scriptBlock}</body>`);
  } else {
    output = `${output}${scriptBlock}`;
  }
  return output;
}
