#!/usr/bin/env node

const express = require('express');
const { URL } = require('url');
const path = require('path');
const { isRewritableUrl, URL_ATTRS } = require('../../lib/url-rewrite-utils');

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

// Cookie name for storing the target origin across navigations
const PROXY_TARGET_COOKIE = '__pi_proxy_target';

// Simple cookie parser middleware - needed to read proxy target cookie
app.use((req, res, next) => {
  const cookieHeader = req.headers.cookie || '';
  req.cookies = {};
  cookieHeader.split(';').forEach(cookie => {
    const parts = cookie.split('=');
    if (parts.length >= 2) {
      const key = parts[0].trim();
      const value = parts.slice(1).join('=').trim();
      try {
        req.cookies[key] = decodeURIComponent(value);
      } catch (e) {
        if (process.env.NODE_ENV !== 'production') {
          console.warn('[Cookie Parser] Failed to decode cookie:', key, e.message);
        }
        req.cookies[key] = value;
      }
    }
  });
  next();
});

// Body parser middleware for POST/PUT requests
// Order matters: more specific parsers first, then generic ones
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.text({ type: 'text/plain' })); // Fix: Handle text/plain content type
// Use raw parser for other content types, but only if not already parsed
app.use(express.raw({ type: (req) => {
  const contentType = req.headers['content-type'] || '';
  return !contentType.includes('application/json') && 
         !contentType.includes('application/x-www-form-urlencoded') &&
         !contentType.includes('text/plain');
}, limit: '10mb' }));

// Default to wildcard (*) for ease of use - users can restrict via BACKGROUND_PROXY_ALLOWLIST
// For production deployments, consider setting BACKGROUND_PROXY_ALLOWLIST to specific domains
const ALLOWLIST = (process.env.BACKGROUND_PROXY_ALLOWLIST || '*')
  .split(',')
  .map((entry) => entry.trim())
  .filter(Boolean);
const BLOCKED_HOSTS = (process.env.BACKGROUND_PROXY_BLOCKLIST || 'localhost,127.,::1')
  .split(',')
  .map((entry) => entry.trim())
  .filter(Boolean);

const DEFAULT_USER_AGENT =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

// Analytics domains to block from proxying
const DEFAULT_ANALYTICS_BLOCKLIST = [
  'googletagmanager.com',
  'google-analytics.com',
  'googleadservices.com',
  'doubleclick.net',
  'googlesyndication.com',
  'analytics.google.com',
  'gtag/js',
  'gtm.js',
  'facebook.net',
  'facebook.com/tr',
  'fbcdn.net',
  'adservice.google',
  'adsystem.amazon',
  'amazon-adsystem.com',
  'bing.com/ms/clr',
  'bat.bing.com',
  'scorecardresearch.com',
  'quantserve.com',
  'outbrain.com',
  'taboola.com',
  'adsrvr.org',
  'adnxs.com',
  'rubiconproject.com',
  'pubmatic.com',
  'criteo.com',
  'adsafeprotected.com',
  'advertising.com',
  'adtechus.com'
];

/**
 * Parse analytics blocklist from environment variable or use defaults
 * @param {string|undefined} envValue - Environment variable value (comma-separated)
 * @returns {string[]} Array of domain patterns to block
 */
function parseAnalyticsBlocklist(envValue) {
  if (!envValue) {
    return DEFAULT_ANALYTICS_BLOCKLIST.slice();
  }
  
  const custom = envValue
    .split(',')
    .map(entry => entry.trim())
    .filter(Boolean);
  
  // Merge with defaults, removing duplicates
  const combined = [...DEFAULT_ANALYTICS_BLOCKLIST, ...custom];
  return [...new Set(combined)];
}

/**
 * Check if a URL should be blocked based on analytics blocklist
 * @param {string} url - URL to check
 * @param {string[]} blocklist - List of domain patterns to block
 * @returns {boolean} True if URL should be blocked
 */
function shouldBlockAnalyticsUrl(url, blocklist) {
  if (!url || typeof url !== 'string') return false;
  
  try {
    const urlObj = new URL(url);
    const hostname = urlObj.hostname.toLowerCase();
    const pathname = urlObj.pathname.toLowerCase();
    
    // Check if hostname or path matches any blocklist pattern
    return blocklist.some(pattern => {
      const lowerPattern = pattern.toLowerCase();
      return hostname.includes(lowerPattern) || pathname.includes(lowerPattern);
    });
  } catch (e) {
    // If URL parsing fails, check if pattern appears in the raw URL string
    const lowerUrl = url.toLowerCase();
    return blocklist.some(pattern => {
      return lowerUrl.includes(pattern.toLowerCase());
    });
  }
}

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

/**
 * Cloudflare challenge markers to detect blocked/challenge responses
 * @type {string[]}
 */
const CLOUDFLARE_CHALLENGE_MARKERS = [
  'cdn-cgi/challenge-platform',
  'cf-chl-bypass',
  'jsd/main.js',
  'challenge-platform',
  'cf-browser-verification',
  'checking your browser',
  'ray id',
  'cf-ray'
];

/**
 * Check if a response indicates a Cloudflare challenge or blocking
 * @param {Object} response - The upstream response (node-fetch Response)
 * @param {string} bodyText - The response body text (if available)
 * @param {string} url - The requested URL
 * @returns {boolean} True if this appears to be a Cloudflare challenge/block
 */
function isCloudflareChallenge(response, bodyText = '', url = '') {
  // Check server header first (works for any status code)
  const server = response.headers.get('server') || '';
  if (server.toLowerCase().includes('cloudflare')) {
    // For Cloudflare servers, check if it's a challenge page
    // Check URL for challenge markers
    const urlLower = url.toLowerCase();
    if (CLOUDFLARE_CHALLENGE_MARKERS.some(marker => urlLower.includes(marker.toLowerCase()))) {
      return true;
    }
    
    // Check response body for challenge markers
    if (bodyText) {
      const bodyLower = bodyText.toLowerCase();
      if (CLOUDFLARE_CHALLENGE_MARKERS.some(marker => bodyLower.includes(marker.toLowerCase()))) {
        return true;
      }
    }
    
    // If Cloudflare server with 403/503, likely a challenge
    if (response.status === 403 || response.status === 503) {
      return true;
    }
  }
  
  // For non-Cloudflare servers, only check 403/503 with challenge markers
  if (response.status === 403 || response.status === 503) {
    // Check URL for challenge markers
    const urlLower = url.toLowerCase();
    if (CLOUDFLARE_CHALLENGE_MARKERS.some(marker => urlLower.includes(marker.toLowerCase()))) {
      return true;
    }
    
    // Check response body for challenge markers
    if (bodyText) {
      const bodyLower = bodyText.toLowerCase();
      if (CLOUDFLARE_CHALLENGE_MARKERS.some(marker => bodyLower.includes(marker.toLowerCase()))) {
        return true;
      }
    }
  }
  
  return false;
}

/**
 * Check if a URL is malformed or double-encoded
 * @param {string} url - URL to check
 * @returns {boolean} True if URL appears malformed
 */
function isMalformedUrl(url) {
  if (!url || typeof url !== 'string') return false;
  
  try {
    // Decode once
    let decoded = decodeURIComponent(url);
    
    // Check if still contains encoded fragments after decoding
    if (decoded.includes('https%3A') || decoded.includes('http%3A') || decoded.includes('%3A%2F%2F')) {
      return true;
    }
    
    // Check for mismatched quotes (common in malformed URLs)
    const singleQuotes = (decoded.match(/'/g) || []).length;
    const doubleQuotes = (decoded.match(/"/g) || []).length;
    if (singleQuotes % 2 !== 0 || doubleQuotes % 2 !== 0) {
      // Odd number of quotes suggests malformation
      return true;
    }
    
    // Try to parse as URL - if it fails, it's malformed
    try {
      new URL(decoded);
    } catch (e) {
      // If decoding helped, try the original
      try {
        new URL(url);
      } catch (e2) {
        return true;
      }
    }
    
    return false;
  } catch (e) {
    // If decoding fails entirely, consider it malformed
    return true;
  }
}

/**
 * Check if content-type mismatch indicates a blocked/challenge response
 * @param {string} contentType - Response content-type
 * @param {string} expectedType - Expected content type ('javascript', 'css', 'html', etc.)
 * @param {number} status - Response status code
 * @returns {boolean} True if mismatch suggests blocking
 */
function isContentTypeMismatch(contentType, expectedType, status) {
  if (!contentType || !expectedType) return false;
  
  const contentTypeLower = contentType.toLowerCase();
  const isHtml = contentTypeLower.includes('text/html');
  
  // If we expected JS/CSS but got HTML with error status, it's likely a challenge/block
  if ((expectedType === 'javascript' || expectedType === 'css' || expectedType === 'font') && 
      isHtml && 
      status >= 400) {
    return true;
  }
  
  return false;
}

/**
 * Parse domain blocklist from environment variable
 * @param {string|undefined} envValue - Environment variable value (comma-separated)
 * @returns {string[]} Array of domain patterns to block
 */
function parseDomainBlocklist(envValue) {
  if (!envValue) {
    return [];
  }
  
  return envValue
    .split(',')
    .map(entry => entry.trim().toLowerCase())
    .filter(Boolean);
}

/**
 * Check if a domain should be blocked based on blocklist
 * @param {string} hostname - Hostname to check
 * @param {string[]} blocklist - List of domain patterns to block
 * @returns {boolean} True if domain should be blocked
 */
function shouldBlockDomain(hostname, blocklist) {
  if (!hostname || !blocklist || blocklist.length === 0) return false;
  
  const hostnameLower = hostname.toLowerCase();
  return blocklist.some(pattern => {
    return hostnameLower === pattern || hostnameLower.endsWith('.' + pattern);
  });
}

/**
 * Parse Cloudflare passthrough allowlist from environment variable
 * @param {string|undefined} envValue - Environment variable value (comma-separated)
 * @returns {string[]} Array of domains that should bypass Cloudflare challenge detection
 */
function parseCfPassthroughDomains(envValue) {
  if (!envValue) {
    return [];
  }
  
  return envValue
    .split(',')
    .map(entry => entry.trim())
    .filter(Boolean);
}

/**
 * Check if a domain should bypass Cloudflare challenge detection
 * @param {string} hostname - Hostname to check
 * @param {string[]} allowlist - List of domains that should bypass detection
 * @returns {boolean} True if domain should bypass Cloudflare challenge detection
 */
function shouldPassthroughCfChallenge(hostname, allowlist) {
  if (!hostname || !allowlist || allowlist.length === 0) {
    return false;
  }
  
  const hostnameLower = hostname.toLowerCase();
  
  // Check for exact match or subdomain match
  return allowlist.some(domain => {
    const domainLower = domain.toLowerCase();
    return hostnameLower === domainLower || hostnameLower.endsWith('.' + domainLower);
  });
}

/**
 * Generate a blocked site page HTML
 * @param {URL} target - The target URL that was blocked
 * @param {string} reason - Reason for blocking ('cloudflare_challenge', 'content_type_mismatch', 'domain_blocklist')
 * @returns {string} HTML page for blocked site
 */
function generateBlockedSitePage(target, reason = 'unknown') {
  const reasonMessages = {
    cloudflare_challenge: 'This site is protected by Cloudflare and is blocking automated access.',
    content_type_mismatch: 'This site returned an unexpected response type, indicating it may be blocking the proxy.',
    domain_blocklist: 'This domain has been marked as non-demoable.',
    unknown: 'This site blocked the preview proxy request.'
  };
  
  const message = reasonMessages[reason] || reasonMessages.unknown;
  
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Preview Blocked - ${target.hostname}</title>
  <style>
    body {
      margin: 0;
      padding: 0;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      color: white;
    }
    .container {
      text-align: center;
      padding: 40px;
      max-width: 600px;
    }
    h1 {
      font-size: 48px;
      margin: 0 0 20px 0;
    }
    p {
      font-size: 18px;
      line-height: 1.6;
      margin: 20px 0;
      opacity: 0.9;
    }
    .domain {
      font-weight: 600;
      font-size: 20px;
      margin: 20px 0;
      padding: 15px;
      background: rgba(255, 255, 255, 0.1);
      border-radius: 8px;
      display: inline-block;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>⚠️ Preview Blocked</h1>
    <p>${message}</p>
    <div class="domain">${target.hostname}</div>
    <p>Some sites block automated access for security reasons. This site cannot be previewed through the proxy.</p>
  </div>
</body>
</html>`;
}

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

/**
 * Sanitizes cookies by removing sensitive cookie patterns
 * @param {string} cookieHeader - The Cookie header value
 * @param {string[]} sensitivePatterns - Patterns to filter (default: common sensitive cookie names)
 * @returns {string|undefined} - Sanitized cookie header or undefined if empty
 */
function sanitizeCookies(cookieHeader, sensitivePatterns = null) {
  if (!cookieHeader) return undefined;
  
  const patterns = sensitivePatterns || (process.env.PROXY_SENSITIVE_COOKIE_PATTERNS || 'session,auth,token,csrf,jwt,secret,password,credential')
    .split(',')
    .map((entry) => entry.trim())
    .filter(Boolean);
  
  const cookies = cookieHeader.split(';').map(c => c.trim()).filter(Boolean);
  const filtered = cookies.filter(cookie => {
    const name = cookie.split('=')[0].toLowerCase();
    return !patterns.some(pattern => name.includes(pattern.toLowerCase()));
  });
  
  return filtered.length > 0 ? filtered.join('; ') : undefined;
}

/**
 * Detects the expected content type from the request.
 * Checks Accept header, file extension, and URL path to determine if request expects JS, CSS, or HTML.
 * 
 * @param {Object} req - Express request object
 * @param {URL} targetUrl - The target URL being requested
 * @returns {Object} Object with expected type and MIME type
 */
function detectExpectedContentType(req, targetUrl) {
  const accept = req.headers.accept || '';
  const pathname = targetUrl.pathname || '';
  const extension = pathname.split('.').pop()?.toLowerCase() || '';
  
  // Check Accept header first (most reliable)
  if (accept.includes('application/javascript') || accept.includes('text/javascript') || accept.includes('application/json')) {
    return { type: 'javascript', mimeType: 'application/javascript' };
  }
  if (accept.includes('text/css')) {
    return { type: 'css', mimeType: 'text/css' };
  }
  if (accept.includes('text/html')) {
    return { type: 'html', mimeType: 'text/html' };
  }
  
  // Fallback to file extension
  const jsExtensions = ['js', 'mjs', 'jsx', 'ts', 'tsx'];
  const cssExtensions = ['css', 'scss', 'sass', 'less'];
  const fontExtensions = ['woff', 'woff2', 'ttf', 'otf', 'eot'];
  
  if (jsExtensions.includes(extension)) {
    return { type: 'javascript', mimeType: 'application/javascript' };
  }
  if (cssExtensions.includes(extension)) {
    return { type: 'css', mimeType: 'text/css' };
  }
  if (fontExtensions.includes(extension)) {
    return { type: 'font', mimeType: 'application/font-woff' };
  }
  
  // Check URL path patterns
  if (pathname.includes('/js/') || pathname.includes('/javascript/') || pathname.includes('/scripts/')) {
    return { type: 'javascript', mimeType: 'application/javascript' };
  }
  if (pathname.includes('/css/') || pathname.includes('/styles/') || pathname.includes('/stylesheets/')) {
    return { type: 'css', mimeType: 'text/css' };
  }
  
  // Default to HTML for ambiguous cases
  return { type: 'html', mimeType: 'text/html' };
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

// Handle OPTIONS for CORS preflight (already handled above, but keeping for compatibility)

app.get('/background-proxy/health', (req, res) => {
  res.json({
    status: 'ok',
    port: PORT,
    allowlist: ALLOWLIST
  });
});

// Handle OPTIONS for CORS preflight
app.options('/proxy', (req, res) => {
  const allowHeaders = req.headers['access-control-request-headers'] || 'Accept,Content-Type,User-Agent,Authorization';
  res.setHeader('access-control-allow-origin', '*');
  res.setHeader('access-control-allow-credentials', 'true');
  res.setHeader('access-control-allow-headers', allowHeaders);
  res.setHeader('access-control-allow-methods', 'GET,POST,PUT,DELETE,HEAD,OPTIONS');
  res.setHeader('access-control-max-age', '86400');
  res.setHeader('access-control-expose-headers', 'content-type,content-length,content-encoding');
  res.status(204).send();
});

// Handle /cdn-cgi/ paths (Cloudflare challenge platform endpoints)
// These come as relative URLs from challenge scripts and need to be forwarded to the passthrough domain
app.all('/cdn-cgi/*', async (req, res) => {
  // Parse passthrough allowlist
  const cfPassthroughDomains = parseCfPassthroughDomains(process.env.PROXY_CF_PASSTHROUGH_DOMAINS);
  
  if (cfPassthroughDomains.length === 0) {
    res.status(400).json({ error: 'No passthrough domains configured' });
    return;
  }
  
  // Extract target origin from referer header
  // The referer should be a proxied URL like: /proxy?url=https%3A%2F%2Fwww.njtransit.com%2F...
  let targetOrigin = null;
  const referer = req.headers['referer'] || req.headers['referrer'];
  
  if (referer) {
    try {
      const refererUrl = new URL(referer);
      const urlParam = refererUrl.searchParams.get('url');
      if (urlParam) {
        const decodedUrl = decodeURIComponent(urlParam);
        const targetUrl = new URL(decodedUrl);
        targetOrigin = targetUrl.origin;
      }
    } catch (e) {
      // If referer parsing fails, try to extract from pathname
      const refererMatch = referer.match(/proxy[?&]url=([^&]+)/);
      if (refererMatch) {
        try {
          const decodedUrl = decodeURIComponent(refererMatch[1]);
          const targetUrl = new URL(decodedUrl);
          targetOrigin = targetUrl.origin;
        } catch (e2) {
          // Ignore
        }
      }
    }
  }
  
  // If no target origin found, use first passthrough domain
  if (!targetOrigin && cfPassthroughDomains.length > 0) {
    // Default to https://www.{domain} format
    const domain = cfPassthroughDomains[0];
    targetOrigin = `https://www.${domain}`;
  }
  
  if (!targetOrigin) {
    res.status(400).json({ error: 'Could not determine target origin' });
    return;
  }
  
  // Parse and validate target origin against allowlist
  let parsedOrigin;
  try {
    parsedOrigin = new URL(targetOrigin);
  } catch (e) {
    res.status(400).json({ error: 'Invalid target origin URL' });
    return;
  }
  
  // Find matching domain in allowlist - returns the allowlist domain (trusted)
  const matchedDomain = cfPassthroughDomains.find(domain => {
    const hostname = parsedOrigin.hostname.toLowerCase();
    const domainLower = domain.toLowerCase();
    return hostname === domainLower || hostname.endsWith('.' + domainLower);
  });
  
  if (!matchedDomain) {
    res.status(403).json({ error: 'Domain not in passthrough allowlist' });
    return;
  }
  
  // Validate path starts with /cdn-cgi/ to prevent path traversal attacks
  const requestPath = req.path;
  if (!requestPath.startsWith('/cdn-cgi/') || requestPath.includes('..')) {
    res.status(400).json({ error: 'Invalid path' });
    return;
  }
  
  // Build target URL using ONLY the allowlist domain (trusted source)
  // This breaks the taint chain for CodeQL SSRF detection
  // We always use www.{allowlistDomain} format for consistency
  const trustedOrigin = `https://www.${matchedDomain}`;
  
  // Construct URL from trusted components only - domain from allowlist, path validated above
  const targetUrl = `${trustedOrigin}${requestPath}${req.url.includes('?') ? req.url.substring(req.url.indexOf('?')) : ''}`;
  
  try {
    const incomingHeaders = req.headers;
    const method = req.method.toUpperCase();
    const upstreamHeaders = {
      'User-Agent': incomingHeaders['user-agent'] || DEFAULT_USER_AGENT,
      Accept: incomingHeaders['accept'] || '*/*',
      'Accept-Language': incomingHeaders['accept-language'] || 'en-US,en;q=0.9',
      'Accept-Encoding': incomingHeaders['accept-encoding'] || 'gzip, deflate, br',
      Referer: trustedOrigin,
      Origin: trustedOrigin,
      Cookie: sanitizeCookies(incomingHeaders.cookie),
      'Sec-Fetch-Dest': incomingHeaders['sec-fetch-dest'] || 'empty',
      'Sec-Fetch-Mode': incomingHeaders['sec-fetch-mode'] || 'cors',
      'Sec-Fetch-Site': incomingHeaders['sec-fetch-site'] || 'same-origin',
      'Sec-Fetch-User': incomingHeaders['sec-fetch-user'] || '?1',
      'Upgrade-Insecure-Requests': '1'
    };
    
    // Forward Content-Type for POST/PUT requests
    if (['POST', 'PUT'].includes(method)) {
      const contentType = incomingHeaders['content-type'];
      if (contentType) {
        upstreamHeaders['Content-Type'] = contentType;
      }
    }
    
    Object.keys(upstreamHeaders).forEach((key) => {
      if (upstreamHeaders[key] === undefined) {
        delete upstreamHeaders[key];
      }
    });
    
    const fetchOptions = {
      method: method,
      headers: upstreamHeaders,
      redirect: 'follow'
    };
    
    // Forward request body for POST/PUT requests
    if (['POST', 'PUT'].includes(method)) {
      // Express body parsers have already parsed the body
      if (req.body) {
        if (Buffer.isBuffer(req.body)) {
          fetchOptions.body = req.body;
        } else if (typeof req.body === 'string') {
          fetchOptions.body = req.body;
        } else {
          fetchOptions.body = JSON.stringify(req.body);
        }
      }
    }
    
    const response = await fetch(targetUrl, fetchOptions);
    
    // Set CORS headers
    res.setHeader('access-control-allow-origin', '*');
    res.setHeader('access-control-allow-credentials', 'true');
    res.setHeader('access-control-expose-headers', 'content-type,content-length,content-encoding');
    
    // Copy response headers (excluding hop-by-hop headers)
    const hopByHopHeaders = ['connection', 'keep-alive', 'proxy-authenticate', 'proxy-authorization', 'te', 'trailers', 'transfer-encoding', 'upgrade'];
    response.headers.forEach((value, key) => {
      const lowerKey = key.toLowerCase();
      if (!hopByHopHeaders.includes(lowerKey) && lowerKey !== 'content-encoding') {
        res.setHeader(key, value);
      }
    });
    
    // For challenge platform endpoints, pass through response as-is (even 403s)
    const buffer = await response.arrayBuffer().catch(() => new ArrayBuffer(0));
    
    res.status(response.status).send(Buffer.from(buffer));
  } catch (error) {
    console.error('[PI-Proxy] Error forwarding /cdn-cgi/ request:', error);
    res.status(500).json({ error: 'Failed to forward request' });
  }
});

// Handle all HTTP methods for proxy
['get', 'post', 'put', 'delete'].forEach(httpMethod => {
  app[httpMethod]('/proxy', async (req, res) => {
  const targetRaw = req.query.url;
  if (!targetRaw || typeof targetRaw !== 'string') {
    res.status(400).json({ error: 'Missing url query parameter' });
    return;
  }

  // Check for malformed/double-encoded URLs early
  if (isMalformedUrl(targetRaw)) {
    console.warn('[PI-Proxy] Malformed URL detected, blocking request:', targetRaw.substring(0, 100));
    res.status(400).json({ 
      error: 'Invalid URL format detected',
      reason: 'malformed_url'
    });
    return;
  }

  // Parse domain blocklist for demo (optional per-domain blocking)
  const domainBlocklist = parseDomainBlocklist(process.env.PROXY_DOMAIN_BLOCKLIST);

  let target;
  try {
    target = resolveTarget(targetRaw);
    
    // Check if domain is in blocklist
    if (shouldBlockDomain(target.hostname, domainBlocklist)) {
      console.log('[PI-Proxy] Domain blocked by blocklist:', target.hostname);
      res.status(403).json({ 
        error: `Domain ${target.hostname} is blocked`,
        reason: 'domain_blocklist'
      });
      return;
    }
  } catch (error) {
    res.status(400).json({ error: error.message });
    return;
  }

  try {
    const incomingHeaders = req.headers;
    const method = req.method.toUpperCase();
    const upstreamHeaders = {
      'User-Agent': incomingHeaders['user-agent'] || DEFAULT_USER_AGENT,
      Accept: incomingHeaders['accept'] || '*/*',
      'Accept-Language': incomingHeaders['accept-language'] || 'en-US,en;q=0.9',
      'Accept-Encoding': incomingHeaders['accept-encoding'] || 'gzip, deflate, br',
      Referer: incomingHeaders['referer'] || target.origin,
      Origin: target.origin,
      Cookie: sanitizeCookies(incomingHeaders.cookie),
      'Sec-Fetch-Dest': incomingHeaders['sec-fetch-dest'] || 'document',
      'Sec-Fetch-Mode': incomingHeaders['sec-fetch-mode'] || 'navigate',
      'Sec-Fetch-Site': incomingHeaders['sec-fetch-site'] || 'cross-site',
      'Sec-Fetch-User': incomingHeaders['sec-fetch-user'] || '?1',
      'Upgrade-Insecure-Requests': '1'
    };
    
    // NOTE: Cookie for target origin is set ONLY for HTML responses (see below)
    // to avoid third-party scripts (like js.pulseinsights.com) overwriting the correct target
    
    // Forward Content-Type for POST/PUT requests
    if (['POST', 'PUT'].includes(method)) {
      const contentType = incomingHeaders['content-type'];
      if (contentType) {
        upstreamHeaders['Content-Type'] = contentType;
      }
    }

    Object.keys(upstreamHeaders).forEach((key) => {
      if (upstreamHeaders[key] === undefined) {
        delete upstreamHeaders[key];
      }
    });

    const fetchOptions = {
      method: method,
      headers: upstreamHeaders,
      redirect: 'follow'
    };
    
    // Forward request body for POST/PUT requests
    if (['POST', 'PUT'].includes(method)) {
      const contentType = incomingHeaders['content-type'] || '';
      
      if (req.body !== undefined && req.body !== null) {
        // Handle different body types based on Content-Type
        if (contentType.includes('application/json')) {
          // JSON body - stringify the parsed object
          fetchOptions.body = JSON.stringify(req.body);
        } else if (contentType.includes('application/x-www-form-urlencoded')) {
          // Form data - convert back to URL-encoded string
          if (typeof req.body === 'object') {
            const params = new URLSearchParams();
            Object.keys(req.body).forEach(key => {
              params.append(key, req.body[key]);
            });
            fetchOptions.body = params.toString();
          } else {
            fetchOptions.body = req.body;
          }
        } else if (Buffer.isBuffer(req.body)) {
          // Raw body (Buffer) - use directly
          fetchOptions.body = req.body;
        } else if (typeof req.body === 'string') {
          // String body - use directly
          fetchOptions.body = req.body;
        } else {
          // Fallback: try to stringify
          fetchOptions.body = JSON.stringify(req.body);
        }
      }
    }

    const response = await fetch(target.toString(), fetchOptions);

    const contentType = response.headers.get('content-type') || '';
    const expectedContentType = detectExpectedContentType(req, target);
    
    res.status(response.status);
    const allowHeaders = req.headers['access-control-request-headers'] || 'Accept,Content-Type,User-Agent,Authorization';
    res.setHeader('access-control-allow-origin', '*');
    res.setHeader('access-control-allow-credentials', 'true');
    res.setHeader('access-control-allow-headers', allowHeaders);
    res.setHeader('access-control-allow-methods', 'GET,POST,PUT,DELETE,HEAD,OPTIONS');
    res.setHeader('access-control-expose-headers', 'content-type,content-length,content-encoding');
    
    // Forward CORS headers from upstream if present
    const corsHeaders = [
      'access-control-allow-origin',
      'access-control-allow-credentials',
      'access-control-expose-headers',
      'access-control-allow-methods',
      'access-control-allow-headers'
    ];
    corsHeaders.forEach(header => {
      const value = response.headers.get(header);
      if (value) {
        res.setHeader(header, value);
      }
    });
    
    // Remove frame-blocking headers
    removeFrameBlockingHeaders(response, res);

    const passthroughHeaders = ['cache-control', 'expires', 'pragma'];
    passthroughHeaders.forEach((header) => {
      const value = response.headers.get(header);
      if (value) {
        res.setHeader(header, value);
      }
    });
    
    // Handle error responses - fix MIME type when upstream returns HTML error pages for JS/CSS requests
    if (response.status >= 400) {
      // Parse passthrough allowlist and check if domain should bypass CF detection
      const cfPassthroughDomains = parseCfPassthroughDomains(process.env.PROXY_CF_PASSTHROUGH_DOMAINS);
      const shouldPassthrough = shouldPassthroughCfChallenge(target.hostname, cfPassthroughDomains);
      
      // Check if this is a challenge script URL from a passthrough domain BEFORE reading body
      // Challenge scripts (e.g., cdn-cgi/challenge-platform/scripts/jsd/main.js) are legitimate
      // and should be allowed through even if they return 403, as they're needed for challenge resolution
      // Use pathname for safer URL checking (avoids query string manipulation)
      const pathnameLower = target.pathname.toLowerCase();
      const isChallengeScriptUrl = pathnameLower.includes('/cdn-cgi/challenge-platform') || 
                                   pathnameLower.includes('/challenge-platform/scripts');
      const allowChallengeScript = shouldPassthrough && isChallengeScriptUrl;
      
      // For passthrough domains, pass through ALL error responses as-is (including 403s)
      // This ensures Cloudflare challenge responses are passed through without modification
      if (shouldPassthrough) {
        console.log(`[PI-Proxy] Passing through error response for passthrough domain (status ${response.status}): ${target.toString()}`);
        // Get the response body as buffer and send it directly
        const buffer = await response.arrayBuffer().catch(() => new ArrayBuffer(0));
        res.status(response.status).send(Buffer.from(buffer));
        return;
      }
      
      // For challenge scripts from passthrough domains, pass through immediately without reading body
      if (allowChallengeScript) {
        // Get the response body as buffer and send it directly
        const buffer = await response.arrayBuffer().catch(() => new ArrayBuffer(0));
        res.send(Buffer.from(buffer));
        return;
      }
      
      // Read error body only if not a passthrough domain or challenge script
      const errorBody = await response.text().catch(() => '');
      const isHtmlErrorPage = errorBody.trim().startsWith('<!') || errorBody.trim().startsWith('<html') || contentType.includes('text/html');
      
      // Detect Cloudflare challenge/blocking (skip if domain is in passthrough allowlist)
      // Also skip if this is a challenge script URL from a passthrough domain
      // For passthrough domains, skip ALL blocking checks (challenge detection and content-type mismatches)
      const isChallenge = (shouldPassthrough || allowChallengeScript) ? false : isCloudflareChallenge(response, errorBody, target.toString());
      const isMismatch = (shouldPassthrough || allowChallengeScript) ? false : isContentTypeMismatch(contentType, expectedContentType.type, response.status);
      
      if (isChallenge || isMismatch) {
        console.warn(`[PI-Proxy] Cloudflare challenge/block detected (status: ${response.status}, challenge: ${isChallenge}, mismatch: ${isMismatch}): ${target.toString()}`);
        
        // For HTML requests, return blocked page with banner
        if (expectedContentType.type === 'html') {
          const blockedHtml = generateBlockedSitePage(target, isChallenge ? 'cloudflare_challenge' : 'content_type_mismatch');
          res.setHeader('content-type', 'text/html');
          res.status(403).send(blockedHtml);
          return;
        }
        
        // For JS/CSS/font requests, return empty/error response instead of HTML
        if (expectedContentType.type === 'javascript') {
          res.setHeader('content-type', 'application/javascript');
          res.status(403).send(`// Error ${response.status}: Site blocked (Cloudflare challenge detected)\n// Resource: ${target.toString()}\n// This site is blocking automated access`);
          return;
        } else if (expectedContentType.type === 'css') {
          res.setHeader('content-type', 'text/css');
          res.status(403).send(`/* Error ${response.status}: Site blocked (Cloudflare challenge detected) */\n/* Resource: ${target.toString()} */`);
          return;
        } else if (expectedContentType.type === 'font') {
          // For fonts, return empty response to allow fallback
          res.setHeader('content-type', 'application/octet-stream');
          res.status(403).send('');
          return;
        }
      }
      
      // If upstream returned HTML error page but request expects JS/CSS, override Content-Type
      // Skip this conversion for passthrough domains - pass through responses as-is
      if (isHtmlErrorPage && expectedContentType.type !== 'html' && !shouldPassthrough) {
        console.warn(`[PI-Proxy] Upstream returned HTML error page (${response.status}) for ${expectedContentType.type} request: ${target.toString()}`);
        
        if (expectedContentType.type === 'javascript') {
          // Return empty JS module or error comment for JS requests
          res.setHeader('content-type', 'application/javascript');
          res.send(`// Error ${response.status}: Failed to load module from ${target.toString()}\n// Upstream returned HTML error page`);
          return;
        } else if (expectedContentType.type === 'css') {
          // Return empty CSS or error comment for CSS requests
          res.setHeader('content-type', 'text/css');
          res.send(`/* Error ${response.status}: Failed to load stylesheet from ${target.toString()} */`);
          return;
        }
      }
      
      // For HTML requests or when error body is not HTML, set Content-Type appropriately
      if (expectedContentType.type === 'html' || !isHtmlErrorPage) {
        if (contentType) {
          res.setHeader('content-type', contentType);
        }
        // Return HTML error page for HTML requests
        if (expectedContentType.type === 'html') {
          res.send(errorBody);
          return;
        }
      } else {
        // Non-HTML request with non-HTML error - use expected type
        res.setHeader('content-type', expectedContentType.mimeType);
      }
      
      // For non-HTML error responses that aren't HTML error pages, return as-is
      if (!isHtmlErrorPage) {
        res.send(errorBody);
        return;
      }
    }

    // Success response - forward Content-Type from upstream
    if (contentType) {
      res.setHeader('content-type', contentType);
    }

    if (contentType.includes('text/html')) {
      // Parse analytics blocklist from environment
      const analyticsBlocklist = parseAnalyticsBlocklist(process.env.PROXY_ANALYTICS_BLOCKLIST);
      
      let body = await response.text();
      
      // Parse passthrough allowlist and check if domain should bypass CF detection
      const cfPassthroughDomains = parseCfPassthroughDomains(process.env.PROXY_CF_PASSTHROUGH_DOMAINS);
      const shouldPassthrough = shouldPassthroughCfChallenge(target.hostname, cfPassthroughDomains);
      
      // Check for Cloudflare challenge even in successful responses (skip if domain is in passthrough allowlist)
      const isChallenge = shouldPassthrough ? false : isCloudflareChallenge(response, body, target.toString());
      if (isChallenge) {
        console.warn(`[PI-Proxy] Cloudflare challenge detected in HTML response: ${target.toString()}`);
        const blockedHtml = generateBlockedSitePage(target, 'cloudflare_challenge');
        res.setHeader('content-type', 'text/html');
        res.status(403).send(blockedHtml);
        return;
      }
      
      // Store the target origin in a cookie ONLY for HTML responses
      // This prevents third-party scripts (like js.pulseinsights.com) from overwriting the correct target
      const cookieValue = `${PROXY_TARGET_COOKIE}=${encodeURIComponent(target.origin)}; Path=/; Max-Age=3600; SameSite=Lax`;
      res.setHeader('Set-Cookie', cookieValue);
      console.log(`[Proxy] Setting target origin cookie for HTML response: ${target.origin}`);
      
      body = ensureBaseHref(body, target);
      // Rewrite resource URLs to go through proxy
      body = rewriteResourceUrls(body, target, req, analyticsBlocklist);
      // Inject framework error handler FIRST (before URL rewriting script)
      body = injectFrameworkErrorHandler(body);
      body = injectUrlRewritingScript(body, target, req, analyticsBlocklist);
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
    const expectedContentType = detectExpectedContentType(req, target);
    
    // Return appropriate Content-Type based on request type
    if (expectedContentType.type === 'javascript') {
      res.setHeader('content-type', 'application/javascript');
      res.status(502).send(`// Error: Failed to fetch ${target.toString()}: ${error.message}\n`);
    } else if (expectedContentType.type === 'css') {
      res.setHeader('content-type', 'text/css');
      res.status(502).send(`/* Error: Failed to fetch ${target.toString()}: ${error.message} */\n`);
    } else {
      res.status(502).json({
        error: `Failed to fetch ${target.toString()}: ${error.message}`
      });
    }
  }
  });
});

/**
 * Catch-all handler for requests that don't go through /proxy?url=
 * This handles dynamic imports and other relative resource requests.
 * Attempts to infer the target origin from:
 * 1. The Referer header (proxy URL pattern)
 * 2. The __pi_proxy_target cookie (set by initial proxy request)
 */
app.use(async (req, res, next) => {
  // Skip if this is already a proxy request or a known route
  if (req.path === '/proxy' || req.path === '/background-proxy/health') {
    return next();
  }
  
  // Skip if path looks like a local file request (for development)
  if (req.path.startsWith('/preview/') || req.path.startsWith('/node_modules/')) {
    return next();
  }
  
  // Try to extract target origin from Referer header
  const referer = req.headers.referer || req.headers.referrer || '';
  let targetOrigin = null;
  let originSource = null;
  
  // Method 1: Try to extract from proxy URL in referer
  const proxyUrlMatch = referer.match(/\/proxy\?url=([^&]+)/);
  if (proxyUrlMatch) {
    try {
      const decodedUrl = decodeURIComponent(proxyUrlMatch[1]);
      const refererUrl = new URL(decodedUrl);
      targetOrigin = refererUrl.origin;
      originSource = 'referer-proxy-url';
    } catch (e) {
      // Ignore parsing errors
    }
  }
  
  // Method 2: Try URL-encoded format in referer
  if (!targetOrigin) {
    const encodedMatch = referer.match(/proxy%3Furl%3D([^&]+)/i);
    if (encodedMatch) {
      try {
        const decoded = decodeURIComponent(decodeURIComponent(encodedMatch[1]));
        const refererUrl = new URL(decoded);
        targetOrigin = refererUrl.origin;
        originSource = 'referer-encoded-proxy-url';
      } catch (e) {
        // Ignore parsing errors
      }
    }
  }
  
  // Method 3: Check the __pi_proxy_target cookie (set by initial proxy request)
  // This handles the case where client-side navigation changed the URL
  if (!targetOrigin && req.cookies && req.cookies[PROXY_TARGET_COOKIE]) {
    try {
      const cookieOrigin = req.cookies[PROXY_TARGET_COOKIE];
      // Validate it's a proper URL
      new URL(cookieOrigin);
      targetOrigin = cookieOrigin;
      originSource = 'cookie';
      console.log(`[Catch-all] Using target origin from cookie: ${targetOrigin}`);
    } catch (e) {
      console.log(`[Catch-all] Invalid origin in cookie: ${req.cookies[PROXY_TARGET_COOKIE]}`);
    }
  }
  
  // If we couldn't determine the target origin, return 404
  if (!targetOrigin) {
    console.log(`[Catch-all] No target origin for ${req.method} ${req.path} (referer: ${referer.substring(0, 100)})`);
    res.status(404).json({ 
      error: 'Resource not found',
      path: req.path,
      hint: 'Could not determine target origin from referer or cookie'
    });
    return;
  }
  
  console.log(`[Catch-all] Target origin: ${targetOrigin} (source: ${originSource}) for ${req.path}`);
  
  // Construct the full target URL
  // Special handling for Nuxt.js chunks: files like /DFAEgFtp.js should be /_nuxt/DFAEgFtp.js
  let targetPath = req.path;
  
  // Detect Nuxt.js chunk paths (short hash filenames at root level)
  // These are typically 8-12 character alphanumeric strings with optional underscore/dash
  const nuxtChunkPattern = /^\/[A-Za-z0-9_-]{6,16}\.(js|css|json)$/;
  const nuxtPathPattern = /^\/_nuxt\//;
  
  if (nuxtChunkPattern.test(targetPath) && !nuxtPathPattern.test(targetPath)) {
    // This looks like a Nuxt chunk at root - prepend /_nuxt/
    targetPath = '/_nuxt' + targetPath;
    console.log(`[Catch-all] Detected Nuxt chunk, rewriting path: ${req.path} -> ${targetPath}`);
  }
  
  // Also handle CSS files that might be chunks
  const cssChunkPattern = /^\/[A-Za-z0-9_.-]+\.(css)$/;
  if (cssChunkPattern.test(req.path) && !req.path.startsWith('/_nuxt/')) {
    // Try /_nuxt/ path first for CSS
    targetPath = '/_nuxt' + req.path;
    console.log(`[Catch-all] Detected CSS chunk, rewriting path: ${req.path} -> ${targetPath}`);
  }
  
  // Handle other common paths
  if (req.path.startsWith('/builds/')) {
    // Nuxt builds should be under /_nuxt/
    targetPath = '/_nuxt' + req.path;
    console.log(`[Catch-all] Detected Nuxt builds path, rewriting: ${req.path} -> ${targetPath}`);
  }
  
  // Handle CDN-cgi paths (Cloudflare)
  if (req.path.startsWith('/cdn-cgi/')) {
    // These stay at root - no rewriting needed
    console.log(`[Catch-all] Detected Cloudflare CDN path: ${req.path}`);
  }
  
  // Handle API paths - keep as-is (at root)
  if (req.path.startsWith('/api/')) {
    console.log(`[Catch-all] Detected API path: ${req.path}`);
  }
  
  const targetUrl = new URL(targetPath, targetOrigin);
  // Preserve query string
  if (req.query && Object.keys(req.query).length > 0) {
    Object.keys(req.query).forEach(key => {
      targetUrl.searchParams.set(key, req.query[key]);
    });
  }
  
  // Check for malformed URL in catch-all handler
  if (isMalformedUrl(targetUrl.toString())) {
    console.warn('[PI-Proxy] [Catch-all] Malformed URL detected, blocking request:', targetUrl.toString().substring(0, 100));
    res.status(400).json({ 
      error: 'Invalid URL format detected',
      reason: 'malformed_url',
      path: req.path
    });
    return;
  }
  
  // Parse domain blocklist for demo (optional per-domain blocking)
  const domainBlocklist = parseDomainBlocklist(process.env.PROXY_DOMAIN_BLOCKLIST);
  
  // Check if domain is in blocklist
  if (shouldBlockDomain(targetUrl.hostname, domainBlocklist)) {
    console.log('[PI-Proxy] [Catch-all] Domain blocked by blocklist:', targetUrl.hostname);
    res.status(403).json({ 
      error: `Domain ${targetUrl.hostname} is blocked`,
      reason: 'domain_blocklist',
      path: req.path
    });
    return;
  }
  
  console.log(`[Catch-all] Proxying ${req.method} ${req.path} -> ${targetUrl.toString()}`);
  
  try {
    // Check if target is allowed
    if (!isHostAllowed(targetUrl.hostname)) {
      res.status(403).json({ error: `Host not allowed: ${targetUrl.hostname}` });
      return;
    }
    
    const upstreamHeaders = {
      'User-Agent': req.headers['user-agent'] || DEFAULT_USER_AGENT,
      Accept: req.headers['accept'] || '*/*',
      'Accept-Language': req.headers['accept-language'] || 'en-US,en;q=0.9',
      'Accept-Encoding': req.headers['accept-encoding'] || 'gzip, deflate, br',
      Referer: targetOrigin,
      Origin: targetOrigin,
      Cookie: sanitizeCookies(req.headers.cookie),
      'Sec-Fetch-Dest': req.headers['sec-fetch-dest'] || 'document',
      'Sec-Fetch-Mode': req.headers['sec-fetch-mode'] || 'navigate',
      'Sec-Fetch-Site': req.headers['sec-fetch-site'] || 'cross-site',
      'Sec-Fetch-User': req.headers['sec-fetch-user'] || '?1',
      'Upgrade-Insecure-Requests': '1'
    };
    
    // Forward Content-Type for POST/PUT requests
    if (['POST', 'PUT'].includes(req.method)) {
      if (req.headers['content-type']) {
        upstreamHeaders['Content-Type'] = req.headers['content-type'];
      }
    }
    
    Object.keys(upstreamHeaders).forEach((key) => {
      if (upstreamHeaders[key] === undefined) {
        delete upstreamHeaders[key];
      }
    });
    
    const fetchOptions = {
      method: req.method,
      headers: upstreamHeaders,
      redirect: 'follow'
    };
    
    // Forward body for POST/PUT
    if (['POST', 'PUT'].includes(req.method) && req.body) {
      const contentType = req.headers['content-type'] || '';
      if (contentType.includes('application/json')) {
        fetchOptions.body = JSON.stringify(req.body);
      } else if (contentType.includes('application/x-www-form-urlencoded')) {
        // Fix: Handle form-urlencoded data (was missing from catch-all route)
        if (typeof req.body === 'object') {
          const params = new URLSearchParams();
          Object.keys(req.body).forEach(key => {
            params.append(key, req.body[key]);
          });
          fetchOptions.body = params.toString();
        } else {
          fetchOptions.body = req.body;
        }
      } else if (Buffer.isBuffer(req.body)) {
        fetchOptions.body = req.body;
      } else if (typeof req.body === 'string') {
        fetchOptions.body = req.body;
      }
    }
    
    const response = await fetch(targetUrl.toString(), fetchOptions);
    
    const contentType = response.headers.get('content-type') || '';
    const expectedContentType = detectExpectedContentType(req, targetUrl);
    
    res.status(response.status);
    
    // Set CORS headers
    res.setHeader('access-control-allow-origin', '*');
    res.setHeader('access-control-allow-credentials', 'true');
    res.setHeader('access-control-allow-methods', 'GET,POST,PUT,DELETE,HEAD,OPTIONS');
    
    // Remove frame-blocking headers
    removeFrameBlockingHeaders(response, res);
    
    // Handle error responses - fix MIME type when upstream returns HTML error pages for JS/CSS requests
    if (response.status >= 400) {
      // Parse passthrough allowlist and check if domain should bypass CF detection
      const cfPassthroughDomains = parseCfPassthroughDomains(process.env.PROXY_CF_PASSTHROUGH_DOMAINS);
      const shouldPassthrough = shouldPassthroughCfChallenge(targetUrl.hostname, cfPassthroughDomains);
      
      // Check if this is a challenge script URL from a passthrough domain BEFORE reading body
      // Challenge scripts (e.g., cdn-cgi/challenge-platform/scripts/jsd/main.js) are legitimate
      // and should be allowed through even if they return 403, as they're needed for challenge resolution
      // Use pathname for safer URL checking (avoids query string manipulation)
      const pathnameLower = targetUrl.pathname.toLowerCase();
      const isChallengeScriptUrl = pathnameLower.includes('/cdn-cgi/challenge-platform') || 
                                   pathnameLower.includes('/challenge-platform/scripts');
      const allowChallengeScript = shouldPassthrough && isChallengeScriptUrl;
      
      // For passthrough domains, pass through ALL error responses as-is (including 403s)
      // This ensures Cloudflare challenge responses are passed through without modification
      if (shouldPassthrough) {
        console.log(`[PI-Proxy] [Catch-all] Passing through error response for passthrough domain (status ${response.status}): ${targetUrl.toString()}`);
        // Get the response body as buffer and send it directly
        const buffer = await response.arrayBuffer().catch(() => new ArrayBuffer(0));
        res.status(response.status).send(Buffer.from(buffer));
        return;
      }
      
      // For challenge scripts from passthrough domains, pass through immediately without reading body
      if (allowChallengeScript) {
        // Get the response body as buffer and send it directly
        const buffer = await response.arrayBuffer().catch(() => new ArrayBuffer(0));
        res.send(Buffer.from(buffer));
        return;
      }
      
      // Read error body only if not a passthrough domain or challenge script
      const errorBody = await response.text().catch(() => '');
      const isHtmlErrorPage = errorBody.trim().startsWith('<!') || errorBody.trim().startsWith('<html') || contentType.includes('text/html');
      
      // Detect Cloudflare challenge/blocking (skip if domain is in passthrough allowlist)
      // Also skip if this is a challenge script URL from a passthrough domain
      // For passthrough domains, skip ALL blocking checks (challenge detection and content-type mismatches)
      const isChallenge = (shouldPassthrough || allowChallengeScript) ? false : isCloudflareChallenge(response, errorBody, targetUrl.toString());
      const isMismatch = (shouldPassthrough || allowChallengeScript) ? false : isContentTypeMismatch(contentType, expectedContentType.type, response.status);
      
      if (isChallenge || isMismatch) {
        console.warn(`[PI-Proxy] [Catch-all] Cloudflare challenge/block detected (status: ${response.status}, challenge: ${isChallenge}, mismatch: ${isMismatch}): ${targetUrl.toString()}`);
        
        // For HTML requests, return blocked page with banner
        if (expectedContentType.type === 'html') {
          const blockedHtml = generateBlockedSitePage(targetUrl, isChallenge ? 'cloudflare_challenge' : 'content_type_mismatch');
          res.setHeader('content-type', 'text/html');
          res.status(403).send(blockedHtml);
          return;
        }
        
        // For JS/CSS/font requests, return empty/error response instead of HTML
        if (expectedContentType.type === 'javascript') {
          res.setHeader('content-type', 'application/javascript');
          res.status(403).send(`// Error ${response.status}: Site blocked (Cloudflare challenge detected)\n// Resource: ${targetUrl.toString()}\n// This site is blocking automated access`);
          return;
        } else if (expectedContentType.type === 'css') {
          res.setHeader('content-type', 'text/css');
          res.status(403).send(`/* Error ${response.status}: Site blocked (Cloudflare challenge detected) */\n/* Resource: ${targetUrl.toString()} */`);
          return;
        } else if (expectedContentType.type === 'font') {
          // For fonts, return empty response to allow fallback
          res.setHeader('content-type', 'application/octet-stream');
          res.status(403).send('');
          return;
        }
      }
      
      // If upstream returned HTML error page but request expects JS/CSS, override Content-Type
      // Skip this conversion for passthrough domains - pass through responses as-is
      if (isHtmlErrorPage && expectedContentType.type !== 'html' && !shouldPassthrough) {
        console.warn(`[PI-Proxy] [Catch-all] Upstream returned HTML error page (${response.status}) for ${expectedContentType.type} request: ${targetUrl.toString()}`);
        
        if (expectedContentType.type === 'javascript') {
          // Return empty JS module or error comment for JS requests
          res.setHeader('content-type', 'application/javascript');
          res.send(`// Error ${response.status}: Failed to load module from ${targetUrl.toString()}\n// Upstream returned HTML error page`);
          return;
        } else if (expectedContentType.type === 'css') {
          // Return empty CSS or error comment for CSS requests
          res.setHeader('content-type', 'text/css');
          res.send(`/* Error ${response.status}: Failed to load stylesheet from ${targetUrl.toString()} */`);
          return;
        }
      }
      
      // For HTML requests or when error body is not HTML, set Content-Type appropriately
      if (expectedContentType.type === 'html' || !isHtmlErrorPage) {
        if (contentType) {
          res.setHeader('content-type', contentType);
        }
        // Return HTML error page for HTML requests
        if (expectedContentType.type === 'html') {
          res.send(errorBody);
          return;
        }
      } else {
        // Non-HTML request with non-HTML error - use expected type
        res.setHeader('content-type', expectedContentType.mimeType);
      }
      
      // For non-HTML error responses that aren't HTML error pages, return as-is
      if (!isHtmlErrorPage) {
        res.send(errorBody);
        return;
      }
    }
    
    // Forward content type for successful responses
    if (contentType) {
      res.setHeader('content-type', contentType);
    }
    
    // Handle based on content type
    if (contentType.includes('text/html')) {
      // Parse analytics blocklist from environment
      const analyticsBlocklist = parseAnalyticsBlocklist(process.env.PROXY_ANALYTICS_BLOCKLIST);
      
      let body = await response.text();
      
      // Parse passthrough allowlist and check if domain should bypass CF detection
      const cfPassthroughDomains = parseCfPassthroughDomains(process.env.PROXY_CF_PASSTHROUGH_DOMAINS);
      const shouldPassthrough = shouldPassthroughCfChallenge(targetUrl.hostname, cfPassthroughDomains);
      
      // Check for Cloudflare challenge even in successful responses (skip if domain is in passthrough allowlist)
      const isChallenge = shouldPassthrough ? false : isCloudflareChallenge(response, body, targetUrl.toString());
      if (isChallenge) {
        console.warn(`[PI-Proxy] [Catch-all] Cloudflare challenge detected in HTML response: ${targetUrl.toString()}`);
        const blockedHtml = generateBlockedSitePage(targetUrl, 'cloudflare_challenge');
        res.setHeader('content-type', 'text/html');
        res.status(403).send(blockedHtml);
        return;
      }
      
      body = ensureBaseHref(body, targetUrl);
      body = rewriteResourceUrls(body, targetUrl, req, analyticsBlocklist);
      // Inject framework error handler FIRST (before URL rewriting script)
      body = injectFrameworkErrorHandler(body);
      body = injectUrlRewritingScript(body, targetUrl, req, analyticsBlocklist);
      body = injectConsentCleanup(body);
      res.send(body);
    } else if (contentType.includes('application/json') || 
               contentType.includes('text/json') ||
               contentType.includes('+json')) {
      // CRITICAL: Never modify JSON - pass through unchanged
      // Modifying JSON breaks JSON.parse() in client code
      const buffer = Buffer.from(await response.arrayBuffer());
      res.send(buffer);
    } else if (contentType.includes('javascript') || contentType.includes('text/css')) {
      // Pass through JS and CSS without server-side URL rewriting
      // The client-side fetch/XHR interception handles URL rewriting at runtime
      // Server-side regex replacement is fragile and causes syntax errors
      const buffer = Buffer.from(await response.arrayBuffer());
      res.send(buffer);
    } else {
      // All other content types: pass through unchanged
      const buffer = Buffer.from(await response.arrayBuffer());
      res.send(buffer);
    }
  } catch (error) {
    console.error('[Catch-all] Error:', error.message);
    const expectedContentType = detectExpectedContentType(req, targetUrl);
    
    // Return appropriate Content-Type based on request type
    if (expectedContentType.type === 'javascript') {
      res.setHeader('content-type', 'application/javascript');
      res.status(502).send(`// Error: Failed to fetch ${targetUrl.toString()}: ${error.message}\n`);
    } else if (expectedContentType.type === 'css') {
      res.setHeader('content-type', 'text/css');
      res.status(502).send(`/* Error: Failed to fetch ${targetUrl.toString()}: ${error.message} */\n`);
    } else if (expectedContentType.type === 'font') {
      res.setHeader('content-type', 'application/octet-stream');
      res.status(502).send('');
    } else {
      res.status(502).json({
        error: `Failed to fetch ${targetUrl.toString()}: ${error.message}`
      });
    }
  }
});

app.listen(PORT, () => {
  console.log(`Background proxy listening on http://localhost:${PORT}`);
});

/**
 * Ensures a base href tag exists in HTML for proper relative URL resolution.
 *
 * @param {string} html - The HTML content
 * @param {URL} target - The target URL being proxied
 * @returns {string} HTML with base href tag if missing
 */
function ensureBaseHref(html, target) {
  // Check if base tag already exists
  if (/<base[^>]*>/i.test(html)) {
    return html;
  }
  
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
  
  if (/<head[^>]*>/i.test(html)) {
    return html.replace(/<head([^>]*)>/i, `<head$1><base href="${escapedBaseHref}">`);
  }
  return `<base href="${escapedBaseHref}">${html}`;
}

/**
 * Rewrites resource URLs in HTML to go through the proxy.
 * Handles src, href, srcset, and other URL attributes.
 * Preserves JSON-LD script blocks from URL rewriting.
 *
 * @param {string} html - The HTML content to rewrite
 * @param {URL} target - The target URL being proxied
 * @param {object} req - Express request object (to determine proxy origin)
 * @param {string[]} analyticsBlocklist - List of analytics domains to block
 * @returns {string} HTML with rewritten URLs
 */
function rewriteResourceUrls(html, target, req, analyticsBlocklist = []) {
  const protocol = req.protocol || 'http';
  const host = req.get('host') || 'localhost:3100';
  const proxyOrigin = `${protocol}://${host}`;
  const proxyBase = proxyOrigin.replace(/\/$/, '');
  const targetOrigin = target.origin;

  // Don't rewrite if proxy origin is not available
  if (!proxyBase) return html;

  // Extract JSON-LD and other data script blocks to preserve them
  const jsonLdBlocks = [];
  const jsonLdPlaceholders = [];
  let placeholderIndex = 0;
  
  // Match <script type="application/ld+json">...</script> blocks
  const jsonLdRegex = /<script\s+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
  let match;
  while ((match = jsonLdRegex.exec(html)) !== null) {
    const fullMatch = match[0];
    const content = match[1];
    const placeholder = `__PI_PROXY_JSON_LD_PLACEHOLDER_${placeholderIndex}__`;
    jsonLdBlocks.push(fullMatch);
    jsonLdPlaceholders.push(placeholder);
    placeholderIndex++;
  }
  
  // Log JSON-LD preservation
  if (jsonLdBlocks.length > 0) {
    console.log('[PI-Proxy] [Bypass] Preserving JSON-LD blocks:', {
      count: jsonLdBlocks.length,
      reason: 'jsonld_preservation',
      blocks: jsonLdBlocks.map((block, i) => ({
        index: i,
        length: block.length,
        preview: block.substring(0, 100)
      }))
    });
  }
  
  // Replace JSON-LD blocks with placeholders
  let output = html;
  jsonLdBlocks.forEach((block, index) => {
    output = output.replace(block, jsonLdPlaceholders[index]);
  });

  let processedOutput = output;

  // Rewrite URLs in common attributes: src, href, srcset, data-src, etc.
  const allowedAttributes = Array.from(URL_ATTRS).filter((attr) => attr !== 'content');

  const rewriteAttrValue = (value) => {
    if (!isRewritableUrl(value)) return value;
    return rewriteUrl(value, targetOrigin, proxyBase, analyticsBlocklist);
  };

  allowedAttributes.forEach((attr) => {
    const attrRegex = new RegExp(`(${attr}\\s*=\\s*["'])([^"']+)(["'])`, 'gi');
    processedOutput = processedOutput.replace(attrRegex, (match, prefix, url, suffix) => {
      const rewritten = rewriteAttrValue(url);
      if (rewritten === url) return match;
      return `${prefix}${rewritten}${suffix}`;
    });

    const unquotedRegex = new RegExp(`(${attr}\\s*=\\s*)([^\\s>]+)`, 'gi');
    processedOutput = processedOutput.replace(unquotedRegex, (match, prefix, url) => {
      const trimmed = url.trim();
      if (!isRewritableUrl(trimmed)) return match;
      const rewritten = rewriteAttrValue(trimmed);
      if (rewritten === trimmed) return match;
      return `${prefix}${rewritten}`;
    });
  });

  const metaRefreshRegex = /<meta[^>]*http-equiv=["']refresh["'][^>]*content\s*=\s*(["'])([^"']*)(["'][^>]*>)/gi;
  processedOutput = processedOutput.replace(metaRefreshRegex, (full, prefixQuote, contentValue, suffixRest) => {
    const updatedContent = rewriteMetaRefreshContent(contentValue, targetOrigin, proxyBase, analyticsBlocklist);
    return full.replace(contentValue, updatedContent);
  });

  // Handle CSS url() references in style attributes and style tags
  // This includes @font-face and other CSS rules
  const cssUrlRegex = /url\s*\(\s*(['"]?)([^"')]+)\1\s*\)/gi;
  processedOutput = processedOutput.replace(cssUrlRegex, (match, _quote, url) => {
    const trimmed = url.trim();
    if (!isRewritableUrl(trimmed)) return match;
    const rewritten = rewriteUrl(trimmed, targetOrigin, proxyBase, analyticsBlocklist);
    if (rewritten === trimmed) return match;
    return match.replace(url, rewritten);
  });

  // Restore JSON-LD blocks (unchanged)
  jsonLdPlaceholders.forEach((placeholder, index) => {
    processedOutput = processedOutput.replace(placeholder, jsonLdBlocks[index]);
  });

  return processedOutput;
}

function rewriteMetaRefreshContent(contentValue, targetOrigin, proxyBase, analyticsBlocklist) {
  const urlMatch = contentValue.match(/url\s*=\s*([^;]+)/i);
  if (!urlMatch) return contentValue;
  const originalUrl = urlMatch[1].trim();
  if (!isRewritableUrl(originalUrl)) return contentValue;
  const rewritten = rewriteUrl(originalUrl, targetOrigin, proxyBase, analyticsBlocklist);
  if (rewritten === originalUrl) return contentValue;
  return contentValue.replace(urlMatch[0], `url=${rewritten}`);
}

/**
 * Decodes HTML entities in a string
 * @param {string} str - String potentially containing HTML entities
 * @returns {string} Decoded string
 */
function decodeHtmlEntities(str) {
  if (typeof str !== 'string') return str;
  return str
    .replace(/&#x27;/g, "'")
    .replace(/&#39;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&#x2F;/g, '/')
    .replace(/&#47;/g, '/');
}

/**
 * Rewrites a single URL to go through the proxy if needed.
 *
 * @param {string} url - The URL to potentially rewrite
 * @param {string} targetOrigin - The origin of the target page
 * @param {string} proxyBase - The base URL of the proxy
 * @param {string[]} analyticsBlocklist - List of analytics domains to block
 * @returns {string} The rewritten URL (or original if no rewrite needed, or 'about:blank' if blocked)
 */
function rewriteUrl(url, targetOrigin, proxyBase, analyticsBlocklist = []) {
  if (!url || typeof url !== 'string') return url;

  // Decode HTML entities before processing
  const decoded = decodeHtmlEntities(url);
  const trimmed = decoded.trim();
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

  // Block analytics/tracking URLs - return about:blank to prevent loading
  if (analyticsBlocklist.length > 0 && shouldBlockAnalyticsUrl(trimmed, analyticsBlocklist)) {
    console.log('[PI-Proxy] [Bypass] Blocked analytics URL:', {
      url: trimmed.substring(0, 100),
      reason: 'analytics_blocklist',
      blocklistMatch: analyticsBlocklist.find(pattern => trimmed.toLowerCase().includes(pattern.toLowerCase()))
    });
    return 'about:blank';
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
 * @param {string[]} analyticsBlocklist - List of analytics domains to block
 * @returns {string} HTML with URL rewriting script injected
 */
function injectUrlRewritingScript(html, target, req, analyticsBlocklist = []) {
  const protocol = req.protocol || 'http';
  const host = req.get('host') || 'localhost:3100';
  const proxyOrigin = `${protocol}://${host}`;
  const proxyBase = proxyOrigin.replace(/\/$/, '');
  const targetOrigin = target.origin;

  if (!proxyBase) return html;

  // Determine if debug logging should be enabled (default: true for development)
  const isDebug = process.env.NODE_ENV !== 'production' || process.env.PROXY_DEBUG === 'true';
  
  // Serialize analytics blocklist for injection into script
  const analyticsBlocklistJson = JSON.stringify(analyticsBlocklist);
  
  // Create URL rewriting function for JavaScript
  // This matches the logic in rewriteUrl() but runs in the browser context
  const scriptContent = `
(function() {
  'use strict';
  
  // Prevent multiple installations - guard against race conditions
  // MUST be checked FIRST, before ANY code execution, including try block
  // Use atomic check-and-set to prevent race conditions
  if (window.__PI_PROXY_URL_REWRITING_INSTALLED) {
    console.log('[PI-Proxy] URL rewriting script already installed, skipping duplicate');
    return;
  }
  // Set guard immediately to prevent concurrent execution
  window.__PI_PROXY_URL_REWRITING_INSTALLED = true;
  
  try {
  // Conditional logging based on environment
  const DEBUG = ${JSON.stringify(isDebug)};
  function log(...args) {
    if (DEBUG) console.log('[PI-Proxy]', ...args);
  }
  
  // Debug logging
  log('URL rewriting script starting...');
  
  // Validate URLs before using them
  const PROXY_BASE_RAW = ${JSON.stringify(proxyBase)};
  const TARGET_ORIGIN_RAW = ${JSON.stringify(targetOrigin)};
  const ANALYTICS_BLOCKLIST = ${analyticsBlocklistJson};
  
  // Helper to check if URL should be blocked
  function shouldBlockAnalyticsUrl(url, blocklist) {
    if (!url || typeof url !== 'string' || !blocklist || blocklist.length === 0) return false;
    
    try {
      const urlObj = new URL(url);
      const hostname = urlObj.hostname.toLowerCase();
      const pathname = urlObj.pathname.toLowerCase();
      
      return blocklist.some(function(pattern) {
        const lowerPattern = pattern.toLowerCase();
        return hostname.includes(lowerPattern) || pathname.includes(lowerPattern);
      });
    } catch (e) {
      const lowerUrl = url.toLowerCase();
      return blocklist.some(function(pattern) {
        return lowerUrl.includes(pattern.toLowerCase());
      });
    }
  }
  
  if (!PROXY_BASE_RAW || !TARGET_ORIGIN_RAW) {
    console.error('[PI-Proxy] Missing required URLs for script injection');
    return;
  }
  
  // Validate URLs are valid before using
  try {
    new URL(PROXY_BASE_RAW);
    new URL(TARGET_ORIGIN_RAW);
  } catch (e) {
    console.error('[PI-Proxy] Invalid URLs in script injection:', e);
    return;
  }
  
  const PROXY_BASE = PROXY_BASE_RAW;
  const TARGET_ORIGIN = TARGET_ORIGIN_RAW;
  
  // Check if we're on a proxied page - use multiple detection methods
  const currentHref = (document.location && document.location.href) || (window.location && window.location.href) || '';
  const referrer = document.referrer || '';
  const proxyOrigin = PROXY_BASE.replace(/\\/$/, '');
  const detectedPageOrigin = (document.location && document.location.origin) || (window.location && window.location.origin) || '';
  
  const isProxied = currentHref.includes('/proxy?url=') ||
                    currentHref.includes('proxy%3Furl%3D') ||
                    referrer.includes('/proxy?url=') ||
                    detectedPageOrigin === proxyOrigin ||
                    (detectedPageOrigin && proxyOrigin && detectedPageOrigin.includes(proxyOrigin.split('://')[1]?.split(':')[0]));
  
  log('Detection check:', {
    currentHref: currentHref.substring(0, 100),
    referrer: referrer.substring(0, 100),
    detectedPageOrigin,
    proxyOrigin,
    isProxied
  });
  
  // Always run if we're on the proxy origin (even if URL pattern doesn't match)
  // This ensures the script runs for all pages served through the proxy
  if (!isProxied) {
    log('Not a proxied page, skipping URL rewriting');
    return;
  }
  
  log('URL rewriting script active');
  
  // HTML entity decoding function
  function decodeHtmlEntities(str) {
    if (typeof str !== 'string') return str;
    return str
      .replace(/&#x27;/g, "'")
      .replace(/&#39;/g, "'")
      .replace(/&quot;/g, '"')
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&#x2F;/g, '/')
      .replace(/&#47;/g, '/');
  }
  
  // URL rewriting function (matches server-side rewriteUrl logic)
  function rewriteUrlForJs(url, baseOrigin) {
    if (!url || typeof url !== 'string') return url;
    
    // Decode HTML entities before processing
    const decoded = decodeHtmlEntities(url);
    const trimmed = decoded.trim();
    if (!trimmed) return url;
    
    // Skip data URLs, blob URLs, and javascript: URLs
    if (/^(data:|blob:|javascript:|mailto:|tel:|#|about:)/i.test(trimmed)) {
      return url;
    }
    
    // Skip URLs that are already proxied
    if (trimmed.includes('/proxy?url=')) {
      return url;
    }
    
    // Block analytics/tracking URLs - return about:blank to prevent loading
    if (ANALYTICS_BLOCKLIST && ANALYTICS_BLOCKLIST.length > 0 && shouldBlockAnalyticsUrl(trimmed, ANALYTICS_BLOCKLIST)) {
      log('Blocked analytics URL:', trimmed);
      return 'about:blank';
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
      
      // Method 1: Extract from proxy URL parameter in current URL
      let match = locationHref.match(/proxy[?&]url=([^&]+)/);
      if (!match) {
        // Try URL-encoded version
        match = locationHref.match(/proxy%3Furl%3D([^&]+)/);
      }
      if (match) {
        const decoded = decodeURIComponent(match[1]);
        const url = new URL(decoded);
        const baseOrigin = url.origin;
        log('Extracted origin from proxy URL:', baseOrigin);
        console.log('[PI-Proxy] getCurrentOrigin: Method 1 (proxy URL) ->', baseOrigin);
        // Store in cookie for future requests
        document.cookie = '__pi_proxy_target=' + encodeURIComponent(baseOrigin) + '; path=/; max-age=3600; SameSite=Lax';
        return baseOrigin;
      }
      
      // Method 2: Check cookie (set by proxy server or previous page load)
      // This is crucial for pages after client-side navigation
      const cookieMatch = document.cookie.match(/(?:^|;)\\s*__pi_proxy_target=([^;]+)/);
      if (cookieMatch) {
        try {
          const cookieOrigin = decodeURIComponent(cookieMatch[1]);
          // Validate it's a proper URL
          new URL(cookieOrigin);
          log('Using target origin from cookie:', cookieOrigin);
          console.log('[PI-Proxy] getCurrentOrigin: Method 2 (cookie) ->', cookieOrigin);
          return cookieOrigin;
        } catch (e) {
          log('Invalid origin in cookie');
        }
      }
      
      // Method 3: Use referrer if it contains the target origin
      if (document.referrer) {
        try {
          // Check if referrer is a proxy URL
          const referrerMatch = document.referrer.match(/proxy[?&]url=([^&]+)/);
          if (referrerMatch) {
            const decoded = decodeURIComponent(referrerMatch[1]);
            const url = new URL(decoded);
            const baseOrigin = url.origin;
            log('Extracted origin from referrer proxy URL:', baseOrigin);
            console.log('[PI-Proxy] getCurrentOrigin: Method 3a (referrer proxy URL) ->', baseOrigin);
            // Store in cookie for future requests
            document.cookie = '__pi_proxy_target=' + encodeURIComponent(baseOrigin) + '; path=/; max-age=3600; SameSite=Lax';
            return baseOrigin;
          }
          
          // Also try using searchParams
          const referrerUrl = new URL(document.referrer);
          const urlParam = referrerUrl.searchParams.get('url');
          if (urlParam) {
            const decoded = decodeURIComponent(urlParam);
            const url = new URL(decoded);
            const baseOrigin = url.origin;
            log('Extracted origin from referrer searchParams:', baseOrigin);
            console.log('[PI-Proxy] getCurrentOrigin: Method 3b (referrer searchParams) ->', baseOrigin);
            // Store in cookie for future requests
            document.cookie = '__pi_proxy_target=' + encodeURIComponent(baseOrigin) + '; path=/; max-age=3600; SameSite=Lax';
            return baseOrigin;
          }
        } catch (e) {
          // Ignore
        }
      }
      
      // Method 4: Use document.baseURI if it's set to the target origin (not proxy origin)
      if (document.baseURI) {
        try {
          const baseUrl = new URL(document.baseURI);
          // Only use baseURI if it's NOT the proxy origin
          if (baseUrl.origin !== proxyOrigin && baseUrl.origin !== detectedPageOrigin) {
            const baseOrigin = baseUrl.origin;
            log('Using document.baseURI (non-proxy origin):', baseOrigin);
            console.log('[PI-Proxy] getCurrentOrigin: Method 4 (baseURI) ->', baseOrigin);
            return baseOrigin;
          }
        } catch (e) {
          // Ignore
        }
      }
      
      // Method 5: Use TARGET_ORIGIN (injected constant) instead of current origin
      // Current origin would be the proxy origin, which is wrong for relative URL resolution
      if (TARGET_ORIGIN) {
        const baseOrigin = TARGET_ORIGIN;
        log('Using TARGET_ORIGIN fallback:', baseOrigin);
        console.log('[PI-Proxy] getCurrentOrigin: Method 5 (TARGET_ORIGIN constant) ->', baseOrigin);
        // Store in cookie for future requests
        document.cookie = '__pi_proxy_target=' + encodeURIComponent(baseOrigin) + '; path=/; max-age=3600; SameSite=Lax';
        return baseOrigin;
      }
      
      // Last resort: Use current page origin (should rarely happen and may not work correctly)
      const currentPageOrigin = (document.location && document.location.origin) || (window.location && window.location.origin) || '';
      log('Using current page origin fallback (may be incorrect):', currentPageOrigin);
      console.log('[PI-Proxy] getCurrentOrigin: Method 6 (current page fallback - WARNING) ->', currentPageOrigin);
      return currentPageOrigin;
    } catch (e) {
      console.error('[PI-Proxy] Error getting current origin:', e);
      // Final fallback
      return (window.location && window.location.origin) || '';
    }
  }
  
  // Get current origin for URL resolution
  // Store in window object to avoid any variable declaration conflicts
  window.__PI_PROXY_CURRENT_ORIGIN = getCurrentOrigin();
  log('Current origin for URL resolution:', window.__PI_PROXY_CURRENT_ORIGIN);
  console.log('[PI-Proxy] getCurrentOrigin() returned:', window.__PI_PROXY_CURRENT_ORIGIN);
  
  // Verify origin is set correctly
  if (!window.__PI_PROXY_CURRENT_ORIGIN) {
    console.error('[PI-Proxy] Failed to get current origin, URL rewriting may not work correctly');
  }
  
  // Helper to get the stored origin (avoids closure issues)
  function getStoredOrigin() {
    return window.__PI_PROXY_CURRENT_ORIGIN;
  }
  
  // Intercept fetch()
  if (typeof window.fetch !== 'undefined') {
    const originalFetch = window.fetch;
    window.fetch = function(input, init) {
      const origin = getStoredOrigin();
      // Handle string URL
      if (typeof input === 'string') {
        const rewritten = rewriteUrlForJs(input, origin);
        if (rewritten !== input) {
          log('fetch() rewritten:', input, '->', rewritten);
          console.log('[PI-Proxy] fetch() URL rewritten:', input, '->', rewritten);
        }
        return originalFetch.call(this, rewritten, init);
      }
      // Handle Request object
      if (input && typeof input === 'object') {
        if (input instanceof Request) {
          const rewritten = rewriteUrlForJs(input.url, origin);
          if (rewritten !== input.url) {
            log('fetch(Request) rewritten:', input.url, '->', rewritten);
            // Clone the Request with the new URL to preserve headers, body, method, etc.
            const newRequest = new Request(rewritten, input);
            return originalFetch.call(this, newRequest, init);
          }
          return originalFetch.call(this, input, init);
        } else if (input.url) {
          // Object with url property
          const rewritten = rewriteUrlForJs(input.url, origin);
          if (rewritten !== input.url) {
            log('fetch(object) rewritten:', input.url, '->', rewritten);
          }
          return originalFetch.call(this, rewritten, init);
        }
      }
      // Fallback to original
      return originalFetch.call(this, input, init);
    };
    log('fetch() interception installed');
  }
  
  // Intercept XMLHttpRequest.open()
  if (typeof XMLHttpRequest !== 'undefined') {
    // Save the original open method BEFORE overwriting it to prevent infinite recursion
    const originalOpen = XMLHttpRequest.prototype.open;
    const originalSetTimeout = XMLHttpRequest.prototype.setTimeout;
    
    XMLHttpRequest.prototype.open = function(method, url, async, user, password) {
      const origin = getStoredOrigin();
      const rewritten = rewriteUrlForJs(url, origin);
      if (rewritten !== url) {
        log('XHR.open() rewritten:', url, '->', rewritten);
        console.log('[PI-Proxy] XHR.open() URL rewritten:', url, '->', rewritten);
      }
      
      // CRITICAL: For synchronous XHR (async === false), don't set timeout
      // Synchronous requests must not have a timeout set (causes InvalidAccessError)
      const isAsync = async !== false;
      
      // Log synchronous XHR handling
      if (!isAsync) {
        log('[Bypass] Synchronous XHR detected, skipping timeout:', {
          method,
          url: url.substring(0, 100),
          reason: 'sync_xhr_no_timeout'
        });
      }
      
      // Store async flag for setTimeout interception
      this.__pi_proxy_is_async = isAsync;
      
      return originalOpen.call(this, method, rewritten, async, user, password);
    };
    
    // Intercept setTimeout to prevent setting timeout on synchronous XHR
    if (originalSetTimeout) {
      XMLHttpRequest.prototype.setTimeout = function(timeout) {
        // Only set timeout if this is an async request
        if (this.__pi_proxy_is_async !== false) {
          return originalSetTimeout.call(this, timeout);
        } else {
          log('[Bypass] Skipping setTimeout for synchronous XHR:', {
            reason: 'sync_xhr_no_timeout',
            url: this.responseURL ? this.responseURL.substring(0, 100) : 'unknown'
          });
          // Don't set timeout for sync requests - just return
          return;
        }
      };
    }
    
    log('XMLHttpRequest interception installed');
  }
  
  // Intercept dynamic script tag creation (for webpack code splitting)
  // CRITICAL: Intercept on the prototype FIRST so it applies to ALL script elements
  if (typeof HTMLScriptElement !== 'undefined' && HTMLScriptElement.prototype) {
    const originalSrcDescriptor = Object.getOwnPropertyDescriptor(HTMLScriptElement.prototype, 'src');
    if (originalSrcDescriptor && originalSrcDescriptor.set) {
      Object.defineProperty(HTMLScriptElement.prototype, 'src', {
        set: function(value) {
          const origin = getStoredOrigin();
          const rewritten = rewriteUrlForJs(value, origin);
          if (rewritten !== value) {
            log('HTMLScriptElement.prototype.src rewritten:', value, '->', rewritten);
          }
          originalSrcDescriptor.set.call(this, rewritten);
        },
        get: originalSrcDescriptor.get || function() {
          return this.getAttribute('src');
        },
        configurable: true,
        enumerable: true
      });
      log('HTMLScriptElement.prototype.src interception installed');
    }
    
    // Also intercept setAttribute on the prototype
    const originalSetAttribute = HTMLScriptElement.prototype.setAttribute;
    HTMLScriptElement.prototype.setAttribute = function(name, value) {
      if (name.toLowerCase() === 'src' && typeof value === 'string') {
        const origin = getStoredOrigin();
        const rewritten = rewriteUrlForJs(value, origin);
        if (rewritten !== value) {
          log('HTMLScriptElement.prototype.setAttribute("src") rewritten:', value, '->', rewritten);
        }
        return originalSetAttribute.call(this, name, rewritten);
      }
      return originalSetAttribute.call(this, name, value);
    };
    log('HTMLScriptElement.prototype.setAttribute interception installed');
  }
  
  // Intercept HTMLLinkElement.prototype.href (stylesheets)
  if (typeof HTMLLinkElement !== 'undefined' && HTMLLinkElement.prototype) {
    const originalHrefDescriptor = Object.getOwnPropertyDescriptor(HTMLLinkElement.prototype, 'href');
    if (originalHrefDescriptor && originalHrefDescriptor.set) {
      Object.defineProperty(HTMLLinkElement.prototype, 'href', {
        set: function(value) {
          const origin = getStoredOrigin();
          const rewritten = rewriteUrlForJs(value, origin);
          if (rewritten !== value) {
            log('HTMLLinkElement.prototype.href rewritten:', value, '->', rewritten);
          }
          originalHrefDescriptor.set.call(this, rewritten);
        },
        get: originalHrefDescriptor.get || function() {
          return this.getAttribute('href');
        },
        configurable: true,
        enumerable: true
      });
      log('HTMLLinkElement.prototype.href interception installed');
    }
  }
  
  // Intercept HTMLIFrameElement.prototype.src (nested iframes)
  if (typeof HTMLIFrameElement !== 'undefined' && HTMLIFrameElement.prototype) {
    const originalSrcDescriptor = Object.getOwnPropertyDescriptor(HTMLIFrameElement.prototype, 'src');
    if (originalSrcDescriptor && originalSrcDescriptor.set) {
      Object.defineProperty(HTMLIFrameElement.prototype, 'src', {
        set: function(value) {
          const origin = getStoredOrigin();
          const rewritten = rewriteUrlForJs(value, origin);
          if (rewritten !== value) {
            log('HTMLIFrameElement.prototype.src rewritten:', value, '->', rewritten);
          }
          originalSrcDescriptor.set.call(this, rewritten);
        },
        get: originalSrcDescriptor.get || function() {
          return this.getAttribute('src');
        },
        configurable: true,
        enumerable: true
      });
      log('HTMLIFrameElement.prototype.src interception installed');
    }
  }
  
  // Intercept HTMLImageElement.prototype.src (images)
  if (typeof HTMLImageElement !== 'undefined' && HTMLImageElement.prototype) {
    const originalSrcDescriptor = Object.getOwnPropertyDescriptor(HTMLImageElement.prototype, 'src');
    if (originalSrcDescriptor && originalSrcDescriptor.set) {
      Object.defineProperty(HTMLImageElement.prototype, 'src', {
        set: function(value) {
          const origin = getStoredOrigin();
          const rewritten = rewriteUrlForJs(value, origin);
          if (rewritten !== value) {
            log('HTMLImageElement.prototype.src rewritten:', value, '->', rewritten);
          }
          originalSrcDescriptor.set.call(this, rewritten);
        },
        get: originalSrcDescriptor.get || function() {
          return this.getAttribute('src');
        },
        configurable: true,
        enumerable: true
      });
      log('HTMLImageElement.prototype.src interception installed');
    }
    
    // Also intercept srcset attribute (for responsive images)
    const originalSetAttribute = HTMLImageElement.prototype.setAttribute;
    HTMLImageElement.prototype.setAttribute = function(name, value) {
      if (name.toLowerCase() === 'srcset' && typeof value === 'string') {
        // Parse srcset: "url1 1x, url2 2x, url3 100w"
        const origin = getStoredOrigin();
        const rewritten = value
          .split(',')
          .map(function(entry) {
            const trimmed = entry.trim();
            if (!trimmed) return trimmed;
            const parts = trimmed.split(/\s+/);
            if (parts.length === 0) return trimmed;
            const url = parts[0];
            const descriptors = parts.slice(1).join(' ');
            const rewrittenUrl = rewriteUrlForJs(url, origin);
            return descriptors ? rewrittenUrl + ' ' + descriptors : rewrittenUrl;
          })
          .join(', ');
        if (rewritten !== value) {
          log('HTMLImageElement.prototype.srcset rewritten:', value.substring(0, 100), '->', rewritten.substring(0, 100));
        }
        return originalSetAttribute.call(this, name, rewritten);
      }
      return originalSetAttribute.call(this, name, value);
    };
  }
  
  // Intercept Image() constructor
  if (typeof window !== 'undefined' && window.Image) {
    const OriginalImage = window.Image;
    window.Image = function(...args) {
      const img = new OriginalImage(...args);
      if (args.length > 0 && typeof args[0] === 'number' && args.length > 1 && typeof args[1] === 'number') {
        // Image(width, height) constructor - no src yet
        return img;
      }
      // Intercept src property after construction
      const originalSrcDescriptor = Object.getOwnPropertyDescriptor(HTMLImageElement.prototype, 'src');
      if (originalSrcDescriptor && originalSrcDescriptor.set) {
        const originalSetSrc = originalSrcDescriptor.set;
        Object.defineProperty(img, 'src', {
          set: function(value) {
            const origin = getStoredOrigin();
            const rewritten = rewriteUrlForJs(value, origin);
            if (rewritten !== value) {
              log('Image() constructor src rewritten:', value, '->', rewritten);
            }
            return originalSetSrc.call(this, rewritten);
          },
          get: originalSrcDescriptor.get || function() {
            return this.getAttribute('src');
          },
          configurable: true,
          enumerable: true
        });
      }
      return img;
    };
    // Copy static properties
    Object.setPrototypeOf(window.Image, OriginalImage);
    Object.setPrototypeOf(window.Image.prototype, OriginalImage.prototype);
    log('Image() constructor interception installed');
  }
  
  // Intercept Audio() constructor
  if (typeof window !== 'undefined' && window.Audio) {
    const OriginalAudio = window.Audio;
    window.Audio = function(...args) {
      const origin = getStoredOrigin();
      const audio = args.length > 0 && typeof args[0] === 'string' 
        ? new OriginalAudio(rewriteUrlForJs(args[0], origin))
        : new OriginalAudio(...args);
      // Intercept src property after construction
      const originalSrcDescriptor = Object.getOwnPropertyDescriptor(HTMLAudioElement.prototype, 'src');
      if (originalSrcDescriptor && originalSrcDescriptor.set) {
        const originalSetSrc = originalSrcDescriptor.set;
        Object.defineProperty(audio, 'src', {
          set: function(value) {
            const innerOrigin = getStoredOrigin();
            const rewritten = rewriteUrlForJs(value, innerOrigin);
            if (rewritten !== value) {
              log('Audio() constructor src rewritten:', value, '->', rewritten);
            }
            return originalSetSrc.call(this, rewritten);
          },
          get: originalSrcDescriptor.get || function() {
            return this.getAttribute('src');
          },
          configurable: true,
          enumerable: true
        });
      }
      return audio;
    };
    // Copy static properties
    Object.setPrototypeOf(window.Audio, OriginalAudio);
    Object.setPrototypeOf(window.Audio.prototype, OriginalAudio.prototype);
    log('Audio() constructor interception installed');
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
        const origin = getStoredOrigin();
        const rewritten = rewriteUrlForJs(srcValue, origin);
        if (rewritten !== srcValue) {
          log('Rewriting script src:', srcValue, '->', rewritten);
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
    // Only intercept if both getter and setter exist to avoid issues
    const innerHTMLDescriptor = Object.getOwnPropertyDescriptor(Element.prototype, 'innerHTML');
    if (innerHTMLDescriptor && innerHTMLDescriptor.set && innerHTMLDescriptor.get) {
      const originalSetInnerHTML = innerHTMLDescriptor.set;
      const originalGetInnerHTML = innerHTMLDescriptor.get;
      Object.defineProperty(Element.prototype, 'innerHTML', {
        set: function(value) {
          // Check if value contains script tags with src attributes
          if (typeof value === 'string' && /<script[^>]*src=["']([^"']+)["']/i.test(value)) {
            const origin = getStoredOrigin();
            const rewritten = value.replace(/<script([^>]*)src=["']([^"']+)["']/gi, (match, attrs, src) => {
              const rewrittenSrc = rewriteUrlForJs(src, origin);
              if (rewrittenSrc !== src) {
                log('innerHTML script src rewritten:', src, '->', rewrittenSrc);
              }
              return '<script' + attrs + 'src="' + rewrittenSrc + '"';
            });
            return originalSetInnerHTML.call(this, rewritten);
          }
          return originalSetInnerHTML.call(this, value);
        },
        get: function() {
          // Use the original getter to prevent infinite recursion
          return originalGetInnerHTML.call(this);
        },
        configurable: true
      });
    }
    
    // Intercept outerHTML for script tags
    const outerHTMLDescriptor = Object.getOwnPropertyDescriptor(Element.prototype, 'outerHTML');
    if (outerHTMLDescriptor && outerHTMLDescriptor.set && outerHTMLDescriptor.get) {
      const originalSetOuterHTML = outerHTMLDescriptor.set;
      const originalGetOuterHTML = outerHTMLDescriptor.get;
      Object.defineProperty(Element.prototype, 'outerHTML', {
        set: function(value) {
          // Check if value contains script tags with src attributes
          if (typeof value === 'string' && /<script[^>]*src=["']([^"']+)["']/i.test(value)) {
            const origin = getStoredOrigin();
            const rewritten = value.replace(/<script([^>]*)src=["']([^"']+)["']/gi, (match, attrs, src) => {
              const rewrittenSrc = rewriteUrlForJs(src, origin);
              if (rewrittenSrc !== src) {
                log('outerHTML script src rewritten:', src, '->', rewrittenSrc);
              }
              return '<script' + attrs + 'src="' + rewrittenSrc + '"';
            });
            return originalSetOuterHTML.call(this, rewritten);
          }
          return originalSetOuterHTML.call(this, value);
        },
        get: function() {
          // Use the original getter to prevent infinite recursion
          return originalGetOuterHTML.call(this);
        },
        configurable: true
      });
    }
    
    log('Script tag interception installed');
  }
  
  log('URL rewriting script initialization complete');
  } catch (e) {
    console.error('[PI-Proxy] Error in URL rewriting script:', e);
  }
})();
`;

  // Check if script is already injected to prevent duplicates
  // Check for script tag with data attribute (more specific check)
  const scriptTagRegex = /<script[^>]*data-pi-proxy=["']url-rewriting["'][^>]*>[\s\S]*?<\/script>/i;
  if (scriptTagRegex.test(html)) {
    console.log('[PI-Proxy] URL rewriting script tag already present in HTML, skipping injection');
    return html;
  }
  // Also check for just the opening tag
  if (/<script[^>]*data-pi-proxy=["']url-rewriting["'][^>]*>/i.test(html)) {
    console.log('[PI-Proxy] URL rewriting script opening tag found, skipping injection');
    return html;
  }
  // Check for runtime guard marker (in case script is already running)
  if (html.includes('__PI_PROXY_URL_REWRITING_INSTALLED')) {
    console.log('[PI-Proxy] URL rewriting script runtime guard detected, skipping injection');
    return html;
  }
  // Check for the guard variable name in the script content itself
  if (html.includes('window.__PI_PROXY_URL_REWRITING_INSTALLED')) {
    console.log('[PI-Proxy] URL rewriting script guard variable found in HTML, skipping injection');
    return html;
  }

  const scriptTag = `<script data-pi-proxy="url-rewriting">${scriptContent}</script>`;

  let output = html;

  // Inject script early in head, before other scripts
  if (/<head[^>]*>/i.test(output)) {
    // Try to inject right after <head> tag, before any existing scripts
    const headMatch = output.match(/<head([^>]*)>/i);
    if (headMatch) {
      const afterHead = output.indexOf('>', headMatch.index) + 1;
      output = output.slice(0, afterHead) + scriptTag + output.slice(afterHead);
      console.log('[PI-Proxy] Injected URL rewriting script after <head> tag');
    } else {
      output = output.replace(/<head([^>]*)>/i, `<head$1>${scriptTag}`);
      console.log('[PI-Proxy] Injected URL rewriting script in <head> tag');
    }
  } else {
    // If no head tag, inject at the very beginning
    output = scriptTag + output;
    console.log('[PI-Proxy] Injected URL rewriting script at document start (no <head> tag)');
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
  // Explicitly remove X-Frame-Options to allow iframe embedding
  // Remove it from response headers if present
  res.removeHeader('x-frame-options');

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
    } else {
      // Explicitly remove CSP header if it becomes empty
      res.removeHeader('content-security-policy');
    }
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
    } else {
      // Explicitly remove CSP-Report-Only header if it becomes empty
      res.removeHeader('content-security-policy-report-only');
    }
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

/**
 * Injects error handling script to catch Vue/Nuxt framework errors
 * that would otherwise cause the page to render blank.
 * This preserves the server-side rendered HTML even when client-side hydration fails.
 *
 * @param {string} html - The HTML content
 * @returns {string} HTML with framework error handling injected
 */
function injectFrameworkErrorHandler(html) {
  // Skip if already injected
  if (html.includes('data-pi-proxy="framework-error-handler"')) {
    return html;
  }

  const errorHandlerScript = `
<script data-pi-proxy="framework-error-handler">
(function() {
  'use strict';
  
  // Prevent multiple installations
  if (window.__PI_FRAMEWORK_ERROR_HANDLER_INSTALLED) return;
  window.__PI_FRAMEWORK_ERROR_HANDLER_INSTALLED = true;
  
  console.log('[PI-Proxy] Framework error handler installing...');
  
  // Store the original SSR content before any framework tries to manipulate it
  var ssrContentBackup = null;
  var appRoot = null;
  var isNuked = false; // Track if we've entered "nuke mode"
  var restoreCount = 0;
  
  // Common Nuxt/Vue app root selectors
  var appRootSelectors = ['#__nuxt', '#app', '#__layout', '[data-v-app]', '.nuxt-app'];
  
  function backupSSRContent() {
    if (ssrContentBackup) return; // Already backed up
    
    for (var i = 0; i < appRootSelectors.length; i++) {
      var root = document.querySelector(appRootSelectors[i]);
      if (root && root.innerHTML && root.innerHTML.trim().length > 100) {
        appRoot = root;
        ssrContentBackup = root.innerHTML;
        console.log('[PI-Proxy] Backed up SSR content from:', appRootSelectors[i]);
        break;
      }
    }
    
    // Also backup body content as fallback
    if (!ssrContentBackup && document.body && document.body.innerHTML) {
      ssrContentBackup = document.body.innerHTML;
      appRoot = document.body;
      console.log('[PI-Proxy] Backed up body content as fallback');
    }
  }
  
  // NUCLEAR OPTION: Stop all JavaScript from running
  function nukeAllScripts() {
    if (isNuked) return;
    isNuked = true;
    console.log('[PI-Proxy] NUKE MODE: Stopping all JavaScript execution');
    
    // 1. Remove all non-essential script tags
    var scripts = document.querySelectorAll('script:not([data-pi-proxy])');
    scripts.forEach(function(script) {
      if (script.src && !script.src.includes('pi-proxy')) {
        script.remove();
      }
    });
    
    // 2. Clear all intervals and timeouts (up to a high ID)
    var highestId = setTimeout(function(){}, 0);
    for (var i = 0; i < highestId; i++) {
      clearTimeout(i);
      clearInterval(i);
    }
    
    // 3. Stop any pending animations
    if (window.cancelAnimationFrame) {
      for (var j = 0; j < 1000; j++) {
        cancelAnimationFrame(j);
      }
    }
    
    // 4. Block future script injections
    var originalCreateElement = document.createElement.bind(document);
    document.createElement = function(tagName) {
      var el = originalCreateElement(tagName);
      if (tagName.toLowerCase() === 'script') {
        // Return a neutered script element
        Object.defineProperty(el, 'src', {
          set: function() { 
            console.log('[PI-Proxy] Blocked script injection');
            return ''; 
          },
          get: function() { return ''; }
        });
      }
      return el;
    };
    
    // 5. Override common framework entry points
    window.Vue = { createApp: function() { return { mount: function() {}, use: function() { return this; } }; } };
    window.__NUXT__ = null;
    window.__NUXT_DATA__ = null;
    
    // 6. Suppress all errors
    window.onerror = function() { return true; };
    window.addEventListener('error', function(e) { e.preventDefault(); e.stopPropagation(); }, true);
    window.addEventListener('unhandledrejection', function(e) { e.preventDefault(); }, true);
    
    console.log('[PI-Proxy] NUKE MODE: All scripts disabled');
  }
  
  function restoreSSRContent(force) {
    if (!ssrContentBackup || !appRoot) {
      console.log('[PI-Proxy] No SSR content to restore');
      return false;
    }
    
    // Check if current content is empty or very small (indicating failed hydration)
    var currentContent = appRoot.innerHTML || '';
    var needsRestore = force || currentContent.trim().length < 50;
    
    if (needsRestore) {
      restoreCount++;
      console.log('[PI-Proxy] Restoring SSR content (attempt ' + restoreCount + ')');
      
      // IMPORTANT: Nuke all scripts BEFORE restoring to prevent re-wiping
      nukeAllScripts();
      
      // Restore the content
      appRoot.innerHTML = ssrContentBackup;
      
      // Add indicator only once
      if (!document.querySelector('[data-pi-proxy="ssr-fallback-notice"]')) {
        var indicator = document.createElement('div');
        indicator.setAttribute('data-pi-proxy', 'ssr-fallback-notice');
        indicator.style.cssText = 'position:fixed;bottom:10px;right:10px;background:rgba(0,0,0,0.7);color:white;padding:8px 12px;border-radius:4px;font-size:12px;z-index:999999;font-family:system-ui,sans-serif;';
        indicator.textContent = 'Showing static preview (interactive features disabled)';
        document.body.appendChild(indicator);
        
        // Auto-hide after 5 seconds using a fresh timeout
        var hideTimeout = setTimeout(function() {
          if (indicator.parentNode) {
            indicator.style.opacity = '0';
            indicator.style.transition = 'opacity 0.5s';
            setTimeout(function() {
              if (indicator.parentNode) indicator.parentNode.removeChild(indicator);
            }, 500);
          }
        }, 5000);
      }
      
      // Set up continuous monitoring to ensure content stays restored
      if (restoreCount === 1) {
        setInterval(function() {
          if (appRoot && ssrContentBackup) {
            var content = appRoot.innerHTML || '';
            if (content.trim().length < 100) {
              console.log('[PI-Proxy] Content wiped again, re-restoring');
              appRoot.innerHTML = ssrContentBackup;
            }
          }
        }, 500);
      }
      
      return true;
    }
    return false;
  }
  
  // Backup SSR content IMMEDIATELY when this script runs
  // Don't wait for DOMContentLoaded - do it synchronously if possible
  if (document.body) {
    backupSSRContent();
  }
  
  // Also backup on DOMContentLoaded
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function() {
      backupSSRContent();
      setupMutationObserver();
    }, { once: true });
  } else {
    setTimeout(backupSSRContent, 0);
    setTimeout(setupMutationObserver, 0);
  }
  
  // Track framework errors
  var frameworkErrorCount = 0;
  var criticalErrorPatterns = [
    /Context conflict/i,
    /Cannot read properties of (undefined|null)/i,
    /Hydration.*mismatch/i,
    /beforeEach/i,
    /Vue.*error/i,
    /Nuxt.*error/i,
    /app.*initialization/i,
    /reading 'ce'/i
  ];
  
  // Global error handler - more aggressive
  var originalOnError = window.onerror;
  window.onerror = function(message, source, lineno, colno, error) {
    var messageStr = String(message || '');
    var isCriticalFrameworkError = criticalErrorPatterns.some(function(pattern) {
      return pattern.test(messageStr);
    });
    
    if (isCriticalFrameworkError) {
      frameworkErrorCount++;
      console.warn('[PI-Proxy] Caught framework error #' + frameworkErrorCount + ':', messageStr.substring(0, 100));
      
      // Immediately restore on first critical error
      if (frameworkErrorCount >= 1) {
        setTimeout(function() {
          restoreSSRContent(true);
        }, 100);
      }
      
      // Prevent error from propagating
      return true;
    }
    
    if (originalOnError) {
      return originalOnError.apply(this, arguments);
    }
    return false;
  };
  
  // Unhandled rejection handler
  window.addEventListener('unhandledrejection', function(event) {
    var reason = event.reason || {};
    var message = reason.message || String(reason);
    
    var isCriticalFrameworkError = criticalErrorPatterns.some(function(pattern) {
      return pattern.test(message);
    });
    
    if (isCriticalFrameworkError) {
      frameworkErrorCount++;
      console.warn('[PI-Proxy] Caught unhandled rejection #' + frameworkErrorCount + ':', message.substring(0, 100));
      event.preventDefault();
      
      setTimeout(function() {
        restoreSSRContent(true);
      }, 100);
    }
  });
  
  // Monitor for empty app root using MutationObserver
  function setupMutationObserver() {
    if (isNuked) return; // Don't set up observer if already nuked
    
    for (var i = 0; i < appRootSelectors.length; i++) {
      var root = document.querySelector(appRootSelectors[i]);
      if (root) {
        var observer = new MutationObserver(function(mutations) {
          if (isNuked) {
            observer.disconnect();
            return;
          }
          
          // Check if content was wiped
          var currentContent = root.innerHTML || '';
          var textContent = root.textContent || '';
          
          if (currentContent.length < 100 || textContent.trim().length < 30) {
            console.log('[PI-Proxy] MutationObserver detected empty app root');
            observer.disconnect();
            restoreSSRContent(true);
          }
        });
        
        observer.observe(root, { childList: true, subtree: true });
        console.log('[PI-Proxy] MutationObserver watching:', appRootSelectors[i]);
        break;
      }
    }
  }
  
  // Quick check - 500ms after page starts loading
  setTimeout(function() {
    backupSSRContent();
  }, 500);
  
  // Check at 1.5 seconds - this is when Nuxt usually starts hydrating
  setTimeout(function() {
    backupSSRContent();
    
    // Check if app appears empty
    for (var i = 0; i < appRootSelectors.length; i++) {
      var root = document.querySelector(appRootSelectors[i]);
      if (root) {
        var content = root.innerHTML || '';
        var textContent = root.textContent || '';
        
        if (content.length < 100 || textContent.trim().length < 30) {
          console.log('[PI-Proxy] Detected empty app root at 1.5s');
          restoreSSRContent(true);
          break;
        }
      }
    }
  }, 1500);
  
  // Check at 2.5 seconds - if errors have occurred, restore
  setTimeout(function() {
    if (frameworkErrorCount > 0) {
      console.log('[PI-Proxy] Framework errors detected at 2.5s, forcing restore');
      restoreSSRContent(true);
    }
  }, 2500);
  
  // Final aggressive check at 3.5 seconds
  setTimeout(function() {
    var bodyText = document.body ? (document.body.textContent || '').trim() : '';
    var visibleElements = document.querySelectorAll('body *:not(script):not(style):not(noscript)');
    var hasVisibleContent = false;
    
    for (var i = 0; i < Math.min(visibleElements.length, 50); i++) {
      var el = visibleElements[i];
      try {
        var rect = el.getBoundingClientRect();
        var style = window.getComputedStyle(el);
        if (rect.width > 10 && rect.height > 10 && 
            style.display !== 'none' && 
            style.visibility !== 'hidden' &&
            style.opacity !== '0') {
          hasVisibleContent = true;
          break;
        }
      } catch(e) {}
    }
    
    if (!hasVisibleContent || bodyText.length < 50 || frameworkErrorCount > 0) {
      console.log('[PI-Proxy] Page appears blank at 3.5s, forcing restore');
      restoreSSRContent(true);
    }
  }, 3500);
  
  console.log('[PI-Proxy] Framework error handler installed');
})();
</script>`;

  let output = html;

  // Inject VERY early - right after opening <head> or at document start
  // This must run before any framework scripts
  if (/<head[^>]*>/i.test(output)) {
    output = output.replace(/<head([^>]*)>/i, `<head$1>${errorHandlerScript}`);
  } else if (/<html[^>]*>/i.test(output)) {
    output = output.replace(/<html([^>]*)>/i, `<html$1>${errorHandlerScript}`);
  } else {
    output = errorHandlerScript + output;
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
