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
  '#cookie-banner',
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
 * @param {Response} response - The upstream response
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

export async function onRequest(context) {
  const { request, env } = context;
  const incoming = new URL(request.url);
  if (request.method === 'OPTIONS') {
    return buildPreflightResponse(request);
  }

  // Allow GET, POST, PUT, DELETE
  const allowedMethods = ['GET', 'POST', 'PUT', 'DELETE'];
  if (!allowedMethods.includes(request.method)) {
    return withCors(jsonResponse({ error: 'Method not allowed' }, { status: 405 }), request);
  }

  const targetRaw = incoming.searchParams.get('url');
  if (!targetRaw) {
    return withCors(jsonResponse({ error: 'Missing url query parameter' }, { status: 400 }), request);
  }

  // Check for malformed/double-encoded URLs early
  if (isMalformedUrl(targetRaw)) {
    console.warn('[PI-Proxy] Malformed URL detected, blocking request:', targetRaw.substring(0, 100));
    return withCors(
      jsonResponse({ 
        error: 'Invalid URL format detected',
        reason: 'malformed_url'
      }, { status: 400 }), 
      request
    );
  }

  // Default to wildcard (*) for ease of use - users can restrict via BACKGROUND_PROXY_ALLOWLIST
  // For production deployments, consider setting BACKGROUND_PROXY_ALLOWLIST to specific domains
  const allowlist = parseList(env.BACKGROUND_PROXY_ALLOWLIST, ['*']);
  const blocklist = parseList(env.BACKGROUND_PROXY_BLOCKLIST, ['localhost', '127.', '::1']);
  
  // Parse domain blocklist for demo (optional per-domain blocking)
  const domainBlocklist = parseDomainBlocklist(env.PROXY_DOMAIN_BLOCKLIST);

  let target;
  try {
    target = resolveTarget(targetRaw, allowlist, blocklist);
    
    // Check if domain is in blocklist
    if (shouldBlockDomain(target.hostname, domainBlocklist)) {
      console.log('[PI-Proxy] Domain blocked by blocklist:', target.hostname);
      return withCors(
        jsonResponse({ 
          error: `Domain ${target.hostname} is blocked`,
          reason: 'domain_blocklist'
        }, { status: 403 }), 
        request
      );
    }
  } catch (error) {
    return withCors(jsonResponse({ error: error.message }, { status: 400 }), request);
  }

  try {
    const upstreamHeaders = buildUpstreamHeaders(request.headers, target, env, request.method);
    
    // Prepare fetch options
    const fetchOptions = {
      method: request.method,
      headers: upstreamHeaders,
      redirect: 'follow'
    };
    
    // Forward request body for POST/PUT requests
    if (['POST', 'PUT'].includes(request.method)) {
      // Clone request to read body (request body can only be read once)
      const clonedRequest = request.clone();
      try {
        const body = await clonedRequest.arrayBuffer();
        fetchOptions.body = body;
      } catch (error) {
        // If body reading fails, continue without body
        console.error('[PI-Proxy] Failed to read request body:', error);
      }
    }
    
    const upstreamResponse = await fetch(target.toString(), fetchOptions);

    const responseHeaders = buildCorsHeaders(request.headers);
    copyPassthroughHeaders(upstreamResponse, responseHeaders);
    removeFrameBlockingHeaders(upstreamResponse, responseHeaders);
    
    // Forward CORS headers from upstream if present
    const corsHeaders = [
      'access-control-allow-origin',
      'access-control-allow-credentials',
      'access-control-expose-headers',
      'access-control-allow-methods',
      'access-control-allow-headers'
    ];
    corsHeaders.forEach(header => {
      const value = upstreamResponse.headers.get(header);
      if (value) {
        responseHeaders.set(header, value);
      }
    });

    const contentType = upstreamResponse.headers.get('content-type') || '';
    
    // Detect expected content type from request
    const accept = request.headers.get('accept') || '';
    const pathname = target.pathname || '';
    const extension = pathname.split('.').pop()?.toLowerCase() || '';
    
    let expectedContentType = { type: 'html', mimeType: 'text/html' };
    if (accept.includes('application/javascript') || accept.includes('text/javascript') || accept.includes('application/json')) {
      expectedContentType = { type: 'javascript', mimeType: 'application/javascript' };
    } else if (accept.includes('text/css')) {
      expectedContentType = { type: 'css', mimeType: 'text/css' };
    } else if (accept.includes('text/html')) {
      expectedContentType = { type: 'html', mimeType: 'text/html' };
    } else {
      // Fallback to file extension
      const jsExtensions = ['js', 'mjs', 'jsx', 'ts', 'tsx'];
      const cssExtensions = ['css', 'scss', 'sass', 'less'];
      if (jsExtensions.includes(extension)) {
        expectedContentType = { type: 'javascript', mimeType: 'application/javascript' };
      } else if (cssExtensions.includes(extension)) {
        expectedContentType = { type: 'css', mimeType: 'text/css' };
      }
    }
    
    if (contentType) {
      responseHeaders.set('content-type', contentType);
    }

    // Handle error responses - fix MIME type when upstream returns HTML error pages for JS/CSS requests
    if (upstreamResponse.status >= 400) {
      const errorBody = await upstreamResponse.text().catch(() => '');
      const isHtmlErrorPage = errorBody.trim().startsWith('<!') || errorBody.trim().startsWith('<html') || contentType.includes('text/html');
      
      // Parse passthrough allowlist and check if domain should bypass CF detection
      const cfPassthroughDomains = parseCfPassthroughDomains(env?.PROXY_CF_PASSTHROUGH_DOMAINS);
      const shouldPassthrough = shouldPassthroughCfChallenge(target.hostname, cfPassthroughDomains);
      
      // Check if this is a challenge script URL from a passthrough domain
      // Challenge scripts (e.g., cdn-cgi/challenge-platform/scripts/jsd/main.js) are legitimate
      // and should be allowed through even if they return 403, as they're needed for challenge resolution
      const urlLower = target.toString().toLowerCase();
      const isChallengeScriptUrl = urlLower.includes('cdn-cgi/challenge-platform') || 
                                   urlLower.includes('challenge-platform/scripts');
      const allowChallengeScript = shouldPassthrough && isChallengeScriptUrl;
      
      // Detect Cloudflare challenge/blocking (skip if domain is in passthrough allowlist)
      // Also skip if this is a challenge script URL from a passthrough domain
      const isChallenge = (shouldPassthrough || allowChallengeScript) ? false : isCloudflareChallenge(upstreamResponse, errorBody, target.toString());
      const isMismatch = allowChallengeScript ? false : isContentTypeMismatch(contentType, expectedContentType.type, upstreamResponse.status);
      
      if (isChallenge || isMismatch) {
        console.warn(`[PI-Proxy] Cloudflare challenge/block detected (status: ${upstreamResponse.status}, challenge: ${isChallenge}, mismatch: ${isMismatch}): ${target.toString()}`);
        
        // For HTML requests, return blocked page with banner
        if (expectedContentType.type === 'html') {
          const blockedHtml = generateBlockedSitePage(target, isChallenge ? 'cloudflare_challenge' : 'content_type_mismatch');
          responseHeaders.set('content-type', 'text/html');
          return new Response(blockedHtml, { status: 403, headers: responseHeaders });
        }
        
        // For JS/CSS/font requests, return empty/error response instead of HTML
        if (expectedContentType.type === 'javascript') {
          responseHeaders.set('content-type', 'application/javascript');
          return new Response(
            `// Error ${upstreamResponse.status}: Site blocked (Cloudflare challenge detected)\n// Resource: ${target.toString()}\n// This site is blocking automated access`,
            { status: 403, headers: responseHeaders }
          );
        } else if (expectedContentType.type === 'css') {
          responseHeaders.set('content-type', 'text/css');
          return new Response(
            `/* Error ${upstreamResponse.status}: Site blocked (Cloudflare challenge detected) */\n/* Resource: ${target.toString()} */`,
            { status: 403, headers: responseHeaders }
          );
        } else if (expectedContentType.type === 'font') {
          // For fonts, return empty response to allow fallback
          responseHeaders.set('content-type', 'application/octet-stream');
          return new Response('', { status: 403, headers: responseHeaders });
        }
      }
      
      // If upstream returned HTML error page but request expects JS/CSS, override Content-Type
      if (isHtmlErrorPage && expectedContentType.type !== 'html') {
        console.warn(`[PI-Proxy] Upstream returned HTML error page (${upstreamResponse.status}) for ${expectedContentType.type} request: ${target.toString()}`);
        
        if (expectedContentType.type === 'javascript') {
          responseHeaders.set('content-type', 'application/javascript');
          return new Response(
            `// Error ${upstreamResponse.status}: Failed to load module from ${target.toString()}\n// Upstream returned HTML error page`,
            { status: upstreamResponse.status, headers: responseHeaders }
          );
        } else if (expectedContentType.type === 'css') {
          responseHeaders.set('content-type', 'text/css');
          return new Response(
            `/* Error ${upstreamResponse.status}: Failed to load stylesheet from ${target.toString()} */`,
            { status: upstreamResponse.status, headers: responseHeaders }
          );
        }
      }
      
      // For HTML requests or when error body is not HTML, set Content-Type appropriately
      if (expectedContentType.type === 'html' || !isHtmlErrorPage) {
        if (contentType) {
          responseHeaders.set('content-type', contentType);
        }
        // Return HTML error page for HTML requests
        if (expectedContentType.type === 'html') {
          return new Response(errorBody, {
            status: upstreamResponse.status,
            headers: responseHeaders
          });
        }
      } else {
        // Non-HTML request with non-HTML error - use expected type
        responseHeaders.set('content-type', expectedContentType.mimeType);
      }
      
      // For non-HTML error responses that aren't HTML error pages, return as-is
      if (!isHtmlErrorPage) {
        return new Response(errorBody, {
          status: upstreamResponse.status,
          headers: responseHeaders
        });
      }
    }

    if (contentType.includes('text/html')) {
      // Parse analytics blocklist from environment
      const analyticsBlocklist = parseAnalyticsBlocklist(env?.PROXY_ANALYTICS_BLOCKLIST);
      
      let body = await upstreamResponse.text();
      
      // Parse passthrough allowlist and check if domain should bypass CF detection
      const cfPassthroughDomains = parseCfPassthroughDomains(env?.PROXY_CF_PASSTHROUGH_DOMAINS);
      const shouldPassthrough = shouldPassthroughCfChallenge(target.hostname, cfPassthroughDomains);
      
      // Check for Cloudflare challenge even in successful responses (skip if domain is in passthrough allowlist)
      const isChallenge = shouldPassthrough ? false : isCloudflareChallenge(upstreamResponse, body, target.toString());
      if (isChallenge) {
        console.warn(`[PI-Proxy] Cloudflare challenge detected in HTML response: ${target.toString()}`);
        const blockedHtml = generateBlockedSitePage(target, 'cloudflare_challenge');
        responseHeaders.set('content-type', 'text/html');
        return new Response(blockedHtml, { status: 403, headers: responseHeaders });
      }
      
      body = ensureBaseHref(body, target);
      body = rewriteResourceUrls(body, target, incoming, analyticsBlocklist);
      body = injectFrameworkErrorHandler(body);
      body = injectUrlRewritingScript(body, target, incoming, env, analyticsBlocklist);
      body = injectConsentCleanup(body);
      
      // Add 403 error messaging if applicable
      if (upstreamResponse.status === 403) {
        body = inject403Message(body, target);
      }
      
      return new Response(body, {
        status: upstreamResponse.status,
        headers: responseHeaders
      });
    }

    const buffer = await upstreamResponse.arrayBuffer();
    return new Response(buffer, {
      status: upstreamResponse.status,
      headers: responseHeaders
    });
  } catch (error) {
    console.error('Proxy fetch failed', targetRaw, error);
    
    // Detect expected content type for error response
    const accept = request.headers.get('accept') || '';
    const pathname = target.pathname || '';
    const extension = pathname.split('.').pop()?.toLowerCase() || '';
    
    let expectedContentType = { type: 'html', mimeType: 'text/html' };
    if (accept.includes('application/javascript') || accept.includes('text/javascript') || accept.includes('application/json')) {
      expectedContentType = { type: 'javascript', mimeType: 'application/javascript' };
    } else if (accept.includes('text/css')) {
      expectedContentType = { type: 'css', mimeType: 'text/css' };
    } else {
      const jsExtensions = ['js', 'mjs', 'jsx', 'ts', 'tsx'];
      const cssExtensions = ['css', 'scss', 'sass', 'less'];
      const fontExtensions = ['woff', 'woff2', 'ttf', 'otf', 'eot'];
      if (jsExtensions.includes(extension)) {
        expectedContentType = { type: 'javascript', mimeType: 'application/javascript' };
      } else if (cssExtensions.includes(extension)) {
        expectedContentType = { type: 'css', mimeType: 'text/css' };
      } else if (fontExtensions.includes(extension)) {
        expectedContentType = { type: 'font', mimeType: 'application/font-woff' };
      }
    }
    
    // Return appropriate Content-Type based on request type
    if (expectedContentType.type === 'javascript') {
      const headers = buildCorsHeaders(request.headers);
      headers.set('content-type', 'application/javascript');
      return new Response(
        `// Error: Failed to fetch ${target.toString()}: ${error.message}\n`,
        { status: 502, headers }
      );
    } else if (expectedContentType.type === 'css') {
      const headers = buildCorsHeaders(request.headers);
      headers.set('content-type', 'text/css');
      return new Response(
        `/* Error: Failed to fetch ${target.toString()}: ${error.message} */\n`,
        { status: 502, headers }
      );
    } else if (expectedContentType.type === 'font') {
      const headers = buildCorsHeaders(request.headers);
      headers.set('content-type', 'application/octet-stream');
      return new Response('', { status: 502, headers });
    } else {
      return withCors(
        jsonResponse({ error: `Failed to fetch ${target.toString()}: ${error.message}` }, { status: 502 }),
        request
      );
    }
  }
}

function parseList(value, fallback) {
  if (!value) return fallback.slice();
  return String(value)
    .split(',')
    .map((entry) => entry.trim())
    .filter(Boolean);
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
 * Validates that a string is a valid URL
 * @param {string} url - URL to validate
 * @returns {boolean} True if valid URL
 */
function validateUrl(url) {
  if (!url || typeof url !== 'string') return false;
  try {
    new URL(url);
    return true;
  } catch {
    return false;
  }
}

/**
 * Sanitizes cookies by removing sensitive cookie patterns
 * @param {string} cookieHeader - The Cookie header value
 * @param {string[]|null} sensitivePatterns - Patterns to filter (null uses defaults)
 * @returns {string|undefined} - Sanitized cookie header or undefined if empty
 */
function sanitizeCookies(cookieHeader, sensitivePatterns = null) {
  if (!cookieHeader) return undefined;
  
  // Default patterns if none provided or empty array passed
  const defaultPatterns = ['session', 'auth', 'token', 'csrf', 'jwt', 'secret', 'password', 'credential'];
  const patterns = (sensitivePatterns && sensitivePatterns.length > 0) ? sensitivePatterns : defaultPatterns;
  
  const cookies = cookieHeader.split(';').map(c => c.trim()).filter(Boolean);
  const filtered = cookies.filter(cookie => {
    const name = cookie.split('=')[0].toLowerCase();
    return !patterns.some(pattern => name.includes(pattern.toLowerCase()));
  });
  
  return filtered.length > 0 ? filtered.join('; ') : undefined;
}

function resolveTarget(raw, allowlist, blocklist) {
  let url;
  try {
    url = new URL(raw);
  } catch (_error) {
    throw new Error('Invalid URL');
  }

  if (!['http:', 'https:'].includes(url.protocol)) {
    throw new Error('Only http/https protocols supported');
  }

  if (!isHostAllowed(url.hostname, allowlist, blocklist)) {
    throw new Error(`Host not allowed: ${url.hostname}`);
  }

  return url;
}

function isHostAllowed(hostname, allowlist, blocklist) {
  if (!hostname) return false;
  const lower = hostname.toLowerCase();
  if (blocklist.some((blocked) => lower.startsWith(blocked.toLowerCase()))) {
    return false;
  }
  if (allowlist.includes('*')) return true;
  return allowlist.some((entry) => {
    const normalized = entry.toLowerCase();
    return lower === normalized || lower.endsWith(`.${normalized}`);
  });
}

function buildUpstreamHeaders(headers, target, env, method = 'GET') {
  const upstream = new Headers();
  // If env var is not set, pass null to use defaults in sanitizeCookies
  // If env var is set, parse it (empty string becomes empty array = no filtering)
  const sensitiveCookiePatterns = env?.PROXY_SENSITIVE_COOKIE_PATTERNS 
    ? parseList(env.PROXY_SENSITIVE_COOKIE_PATTERNS, [])
    : null;
  const headerPairs = [
    ['user-agent', headers.get('user-agent') || DEFAULT_USER_AGENT],
    ['accept', headers.get('accept') || '*/*'],
    ['accept-language', headers.get('accept-language') || 'en-US,en;q=0.9'],
    ['accept-encoding', headers.get('accept-encoding') || 'gzip, deflate, br'],
    ['referer', headers.get('referer') || target.origin],
    ['origin', headers.get('origin') || target.origin],
    ['cookie', sanitizeCookies(headers.get('cookie'), sensitiveCookiePatterns)],
    ['sec-fetch-dest', 'document'],
    ['sec-fetch-mode', 'navigate'],
    ['sec-fetch-site', 'cross-site'],
    ['sec-fetch-user', '?1'],
    ['upgrade-insecure-requests', '1']
  ];
  
  // Forward Content-Type for POST/PUT requests
  if (['POST', 'PUT'].includes(method)) {
    const contentType = headers.get('content-type');
    if (contentType) {
      headerPairs.push(['content-type', contentType]);
    }
  }

  headerPairs.forEach(([key, value]) => {
    if (value) {
      try {
        upstream.set(key, value);
      } catch (_error) {
        // Ignore restricted headers (e.g. user-agent in some environments).
      }
    }
  });

  const secHeaders = [
    ['sec-fetch-dest', headers.get('sec-fetch-dest') || 'document'],
    ['sec-fetch-mode', headers.get('sec-fetch-mode') || 'navigate'],
    ['sec-fetch-site', headers.get('sec-fetch-site') || 'cross-site'],
    ['sec-fetch-user', headers.get('sec-fetch-user') || '?1'],
    ['upgrade-insecure-requests', '1']
  ];

  secHeaders.forEach(([key, value]) => {
    if (value) {
      upstream.set(key, value);
    }
  });

  return upstream;
}

function buildPreflightResponse(request) {
  const headers = buildCorsHeaders(request.headers);
  headers.set('access-control-max-age', '86400');
  return new Response(null, { status: 204, headers });
}

function buildCorsHeaders(requestHeaders) {
  const headers = new Headers();
  headers.set('access-control-allow-origin', '*');
  // Allow credentials for JSONP and other requests that need it
  headers.set('access-control-allow-credentials', 'true');
  const allowHeaders =
    requestHeaders.get('access-control-request-headers') || 'Accept,Content-Type,User-Agent,Authorization';
  headers.set('access-control-allow-headers', allowHeaders);
  headers.set('access-control-allow-methods', 'GET,POST,PUT,DELETE,HEAD,OPTIONS');
  // Expose headers that might be needed by clients
  headers.set('access-control-expose-headers', 'content-type,content-length,content-encoding,cache-control,expires,pragma');
  return headers;
}

function withCors(response, request) {
  const headers = buildCorsHeaders(request.headers);
  const merged = new Headers(response.headers);
  headers.forEach((value, key) => {
    merged.set(key, value);
  });
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers: merged
  });
}

function copyPassthroughHeaders(upstreamResponse, headers) {
  ['cache-control', 'expires', 'pragma'].forEach((header) => {
    const value = upstreamResponse.headers.get(header);
    if (value) {
      headers.set(header, value);
    }
  });
}

/**
 * Removes headers that prevent iframe embedding.
 *
 * @param {Response} upstreamResponse - The upstream response
 * @param {Headers} headers - The response headers to modify
 */
function removeFrameBlockingHeaders(upstreamResponse, headers) {
  // Remove X-Frame-Options to allow iframe embedding
  const frameOptions = upstreamResponse.headers.get('x-frame-options');
  if (frameOptions) {
    headers.delete('x-frame-options');
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
      headers.set('content-security-policy', modifiedCsp);
    } else {
      headers.delete('content-security-policy');
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
      headers.set('content-security-policy-report-only', modifiedCsp);
    } else {
      headers.delete('content-security-policy-report-only');
    }
  }
}

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
 * @param {URL} proxyUrl - The proxy request URL (to determine proxy origin)
 * @param {string[]} analyticsBlocklist - List of analytics domains to block
 * @returns {string} HTML with rewritten URLs
 */
function rewriteResourceUrls(html, target, proxyUrl, analyticsBlocklist = []) {
  const proxyOrigin = `${proxyUrl.protocol}//${proxyUrl.host}`;
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
    processedOutput = processedOutput.replace(attrRegex, (match, prefix, url, suffix) => {
      const rewritten = rewriteUrl(url, targetOrigin, proxyBase, analyticsBlocklist);
      return `${prefix}${rewritten}${suffix}`;
    });

    // Also handle unquoted attributes (less common but possible)
    const unquotedRegex = new RegExp(
      `(${attr}\\s*=\\s*)([^\\s>]+)`,
      'gi'
    );
    processedOutput = processedOutput.replace(unquotedRegex, (match, prefix, url) => {
      const trimmed = url.trim();
      // Skip if it's clearly not a URL (data URLs, javascript:, etc. are handled by rewriteUrl)
      // But process relative paths and absolute URLs
      if (trimmed && !/^(data:|blob:|javascript:|mailto:|tel:|#|about:)/i.test(trimmed)) {
        const rewritten = rewriteUrl(trimmed, targetOrigin, proxyBase, analyticsBlocklist);
        return `${prefix}${rewritten}`;
      }
      return match;
    });
  });

  // Handle srcset attribute specially (can contain multiple URLs)
  // Parse each URL entry individually to avoid treating entire srcset as one URL
  const srcsetRegex = /srcset\s*=\s*["']([^"']+)["']/gi;
  processedOutput = processedOutput.replace(srcsetRegex, (match, srcsetValue) => {
    // srcset format: "url1 1x, url2 2x, url3 100w"
    // Split by comma, then parse each entry separately
    const rewritten = srcsetValue
      .split(',')
      .map((entry) => {
        const trimmed = entry.trim();
        if (!trimmed) return trimmed;
        // Split by whitespace - first part is URL, rest are descriptors
        const parts = trimmed.split(/\s+/);
        if (parts.length === 0) return trimmed;
        const url = parts[0];
        const descriptors = parts.slice(1).join(' ');
        const rewrittenUrl = rewriteUrl(url, targetOrigin, proxyBase, analyticsBlocklist);
        return descriptors ? `${rewrittenUrl} ${descriptors}` : rewrittenUrl;
      })
      .join(', ');
    return match.replace(srcsetValue, rewritten);
  });

  // Handle CSS url() references in style attributes and style tags
  // This includes @font-face and other CSS rules
  const cssUrlRegex = /url\s*\(\s*["']?([^"')]+)["']?\s*\)/gi;
  processedOutput = processedOutput.replace(cssUrlRegex, (match, url) => {
    const trimmed = url.trim();
    // Skip data URLs and other special schemes (handled by rewriteUrl)
    // But process relative paths and absolute URLs
    if (trimmed && !/^(data:|blob:|javascript:|mailto:|tel:|#|about:)/i.test(trimmed)) {
      const rewritten = rewriteUrl(trimmed, targetOrigin, proxyBase, analyticsBlocklist);
      return match.replace(url, rewritten);
    }
    return match;
  });

  // Restore JSON-LD blocks (unchanged)
  jsonLdPlaceholders.forEach((placeholder, index) => {
    processedOutput = processedOutput.replace(placeholder, jsonLdBlocks[index]);
  });

  return processedOutput;
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
 * @param {URL} proxyUrl - The proxy request URL (to determine proxy origin)
 * @param {object} env - Cloudflare Workers environment variables
 * @param {string[]} analyticsBlocklist - List of analytics domains to block
 * @returns {string} HTML with URL rewriting script injected
 */
function injectUrlRewritingScript(html, target, proxyUrl, env, analyticsBlocklist = []) {
  const proxyOrigin = `${proxyUrl.protocol}//${proxyUrl.host}`;
  const proxyBase = proxyOrigin.replace(/\/$/, '');
  const targetOrigin = target.origin;

  if (!proxyBase) return html;

  // Validate URLs before injection to prevent syntax errors
  if (!validateUrl(proxyBase) || !validateUrl(targetOrigin)) {
    console.error('[PI-Proxy] Invalid URLs for script injection:', { proxyBase, targetOrigin });
    return html; // Don't inject script if URLs are invalid
  }

  // Create URL rewriting function for JavaScript
  // This matches the logic in rewriteUrl() but runs in the browser context
  // Determine if debug logging should be enabled (default: true for development)
  // In Cloudflare Workers, NODE_ENV is not available, so default to false unless PROXY_DEBUG is set
  const isDebug = env && (env.PROXY_DEBUG === 'true' || env.PROXY_DEBUG === '1');
  
  // Serialize analytics blocklist for injection into script
  const analyticsBlocklistJson = JSON.stringify(analyticsBlocklist);
  
  const scriptContent = `
(function() {
  'use strict';
  
  try {
  // Conditional logging based on environment
  const DEBUG = ${JSON.stringify(isDebug)};
  function log(...args) {
    if (DEBUG) console.log('[PI-Proxy]', ...args);
  }
  
  // Prevent multiple installations - guard against race conditions
  if (window.__PI_PROXY_URL_REWRITING_INSTALLED) {
    log('URL rewriting script already installed, skipping');
    return;
  }
  window.__PI_PROXY_URL_REWRITING_INSTALLED = true;
  
  // Debug logging
  log('URL rewriting script starting...');
  
  // Validate URLs before using them
  const PROXY_BASE = ${JSON.stringify(proxyBase)};
  const TARGET_ORIGIN = ${JSON.stringify(targetOrigin)};
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
  
  // Validate URLs before using
  if (!PROXY_BASE || !TARGET_ORIGIN) {
    console.error('[PI-Proxy] Missing required URLs for script injection');
    return;
  }
  
  try {
    new URL(PROXY_BASE);
    new URL(TARGET_ORIGIN);
  } catch (e) {
    console.error('[PI-Proxy] Invalid URLs in script injection:', e);
    return;
  }
  
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
  
  log('Detection check:', {
    currentHref: currentHref.substring(0, 100),
    referrer: referrer.substring(0, 100),
    currentPageOrigin,
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
      log('[Bypass] Blocked analytics URL:', {
        url: trimmed.substring(0, 100),
        reason: 'analytics_blocklist',
        blocklistMatch: ANALYTICS_BLOCKLIST.find(pattern => trimmed.toLowerCase().includes(pattern.toLowerCase()))
      });
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
        log('Extracted origin from proxy URL:', baseOrigin);
        return baseOrigin;
      }
      
      // Method 2: Use document.baseURI if available
      if (document.baseURI) {
        try {
          const baseUrl = new URL(document.baseURI);
          const baseOrigin = baseUrl.origin + baseUrl.pathname.replace(/\\/[^/]*$/, '');
          log('Using document.baseURI:', baseOrigin);
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
            log('Extracted origin from referrer:', baseOrigin);
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
      log('Using current page origin fallback (may be incorrect):', baseOrigin);
      return baseOrigin;
    } catch (e) {
      console.error('[PI-Proxy] Error getting current origin:', e);
      // Final fallback
      return (window.location && window.location.origin) || '';
    }
  }
  
  const currentOrigin = getCurrentOrigin();
  log('Current origin for URL resolution:', currentOrigin);
  
  // Intercept fetch()
  if (typeof window.fetch !== 'undefined') {
    const originalFetch = window.fetch;
    window.fetch = function(input, init) {
      // Handle string URL
      if (typeof input === 'string') {
        const rewritten = rewriteUrlForJs(input, currentOrigin);
        if (rewritten !== input) {
          log('fetch() rewritten:', input, '->', rewritten);
        }
        return originalFetch.call(this, rewritten, init);
      }
      // Handle Request object
      if (input && typeof input === 'object') {
        if (input instanceof Request) {
          const rewritten = rewriteUrlForJs(input.url, currentOrigin);
          if (rewritten !== input.url) {
            log('fetch(Request) rewritten:', input.url, '->', rewritten);
            // Clone the Request with the new URL to preserve headers, body, method, etc.
            const newRequest = new Request(rewritten, input);
            return originalFetch.call(this, newRequest, init);
          }
          return originalFetch.call(this, input, init);
        } else if (input.url) {
          // Object with url property
          const rewritten = rewriteUrlForJs(input.url, currentOrigin);
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
      const rewritten = rewriteUrlForJs(url, currentOrigin);
      if (rewritten !== url) {
        log('XHR.open() rewritten:', url, '->', rewritten);
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
          const rewritten = rewriteUrlForJs(value, currentOrigin);
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
        const rewritten = rewriteUrlForJs(value, currentOrigin);
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
          const rewritten = rewriteUrlForJs(value, currentOrigin);
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
          const rewritten = rewriteUrlForJs(value, currentOrigin);
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
          const rewritten = rewriteUrlForJs(value, currentOrigin);
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
            const rewritten = rewriteUrlForJs(value, currentOrigin);
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
      const audio = args.length > 0 && typeof args[0] === 'string' 
        ? new OriginalAudio(rewriteUrlForJs(args[0], currentOrigin))
        : new OriginalAudio(...args);
      // Intercept src property after construction
      const originalSrcDescriptor = Object.getOwnPropertyDescriptor(HTMLAudioElement.prototype, 'src');
      if (originalSrcDescriptor && originalSrcDescriptor.set) {
        const originalSetSrc = originalSrcDescriptor.set;
        Object.defineProperty(audio, 'src', {
          set: function(value) {
            const rewritten = rewriteUrlForJs(value, currentOrigin);
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
        const rewritten = rewriteUrlForJs(srcValue, currentOrigin);
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
            const rewritten = value.replace(/<script([^>]*)src=["']([^"']+)["']/gi, (match, attrs, src) => {
              const rewrittenSrc = rewriteUrlForJs(src, currentOrigin);
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
    
    console.log('[PI-Proxy] Script tag interception installed');
  }
  
  log('URL rewriting script initialization complete');
  } catch (e) {
    console.error('[PI-Proxy] Error in URL rewriting script:', e);
  }
})();
`;

  // Check if script is already injected to prevent duplicates
  if (html.includes('data-pi-proxy="url-rewriting"') || html.includes('__PI_PROXY_URL_REWRITING_INSTALLED')) {
    console.log('[PI-Proxy] URL rewriting script already present in HTML, skipping injection');
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

/**
 * Injects a subtle 403 error message banner into HTML.
 * Informs users that the site blocked the proxy request.
 *
 * @param {string} html - The HTML content
 * @param {URL} target - The target URL that was blocked
 * @returns {string} HTML with 403 message injected
 */
function inject403Message(html, target) {
  const message = `This site (${target.hostname}) blocked the preview proxy request. Some sites block automated access for security reasons.`;
  
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
 * Injects JavaScript to catch Vue/Nuxt hydration errors and restore SSR content.
 * This prevents blank pages when framework hydration fails due to proxy modifications.
 *
 * @param {string} html - The HTML content
 * @returns {string} HTML with framework error handler injected
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
  var isNuked = false;
  var restoreCount = 0;
  
  // Common Nuxt/Vue app root selectors
  var appRootSelectors = ['#__nuxt', '#app', '#__layout', '[data-v-app]', '.nuxt-app'];
  
  function backupSSRContent() {
    if (ssrContentBackup) return;
    
    for (var i = 0; i < appRootSelectors.length; i++) {
      var root = document.querySelector(appRootSelectors[i]);
      if (root && root.innerHTML && root.innerHTML.trim().length > 100) {
        appRoot = root;
        ssrContentBackup = root.innerHTML;
        console.log('[PI-Proxy] Backed up SSR content from:', appRootSelectors[i]);
        break;
      }
    }
    
    if (!ssrContentBackup && document.body && document.body.innerHTML) {
      ssrContentBackup = document.body.innerHTML;
      appRoot = document.body;
      console.log('[PI-Proxy] Backed up body content as fallback');
    }
  }
  
  function nukeAllScripts() {
    if (isNuked) return;
    isNuked = true;
    console.log('[PI-Proxy] NUKE MODE: Stopping all JavaScript execution');
    
    var scripts = document.querySelectorAll('script:not([data-pi-proxy])');
    scripts.forEach(function(script) {
      if (script.src && !script.src.includes('pi-proxy')) {
        script.remove();
      }
    });
    
    var highestId = setTimeout(function(){}, 0);
    for (var i = 0; i < highestId; i++) {
      clearTimeout(i);
      clearInterval(i);
    }
    
    if (window.cancelAnimationFrame) {
      for (var j = 0; j < 1000; j++) {
        cancelAnimationFrame(j);
      }
    }
    
    var originalCreateElement = document.createElement.bind(document);
    document.createElement = function(tagName) {
      var el = originalCreateElement(tagName);
      if (tagName.toLowerCase() === 'script') {
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
    
    window.Vue = { createApp: function() { return { mount: function() {}, use: function() { return this; } }; } };
    window.__NUXT__ = null;
    window.__NUXT_DATA__ = null;
    
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
    
    var currentContent = appRoot.innerHTML || '';
    var needsRestore = force || currentContent.trim().length < 50;
    
    if (needsRestore) {
      restoreCount++;
      console.log('[PI-Proxy] Restoring SSR content (attempt ' + restoreCount + ')');
      
      nukeAllScripts();
      appRoot.innerHTML = ssrContentBackup;
      
      if (!document.querySelector('[data-pi-proxy="ssr-fallback-notice"]')) {
        var indicator = document.createElement('div');
        indicator.setAttribute('data-pi-proxy', 'ssr-fallback-notice');
        indicator.style.cssText = 'position:fixed;bottom:10px;right:10px;background:rgba(0,0,0,0.7);color:white;padding:8px 12px;border-radius:4px;font-size:12px;z-index:999999;font-family:system-ui,sans-serif;';
        indicator.textContent = 'Showing static preview (interactive features disabled)';
        document.body.appendChild(indicator);
        
        setTimeout(function() {
          if (indicator.parentNode) {
            indicator.style.opacity = '0';
            indicator.style.transition = 'opacity 0.5s';
            setTimeout(function() {
              if (indicator.parentNode) indicator.parentNode.removeChild(indicator);
            }, 500);
          }
        }, 5000);
      }
      
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
  
  if (document.body) {
    backupSSRContent();
  }
  
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function() {
      backupSSRContent();
      setupMutationObserver();
    }, { once: true });
  } else {
    setTimeout(backupSSRContent, 0);
    setTimeout(setupMutationObserver, 0);
  }
  
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
  
  var originalOnError = window.onerror;
  window.onerror = function(message, source, lineno, colno, error) {
    var messageStr = String(message || '');
    var isCriticalFrameworkError = criticalErrorPatterns.some(function(pattern) {
      return pattern.test(messageStr);
    });
    
    if (isCriticalFrameworkError) {
      frameworkErrorCount++;
      console.warn('[PI-Proxy] Caught framework error #' + frameworkErrorCount + ':', messageStr.substring(0, 100));
      
      if (frameworkErrorCount >= 1) {
        setTimeout(function() {
          restoreSSRContent(true);
        }, 100);
      }
      
      return true;
    }
    
    if (originalOnError) {
      return originalOnError.apply(this, arguments);
    }
    return false;
  };
  
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
  
  function setupMutationObserver() {
    if (isNuked) return;
    
    for (var i = 0; i < appRootSelectors.length; i++) {
      var root = document.querySelector(appRootSelectors[i]);
      if (root) {
        var observer = new MutationObserver(function(mutations) {
          if (isNuked) {
            observer.disconnect();
            return;
          }
          
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
  
  setTimeout(function() {
    backupSSRContent();
  }, 500);
  
  setTimeout(function() {
    backupSSRContent();
    
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
  
  setTimeout(function() {
    if (frameworkErrorCount > 0) {
      console.log('[PI-Proxy] Framework errors detected at 2.5s, forcing restore');
      restoreSSRContent(true);
    }
  }, 2500);
  
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

function jsonResponse(payload, init = {}) {
  const headers = new Headers(init.headers || {});
  headers.set('content-type', 'application/json');
  return new Response(JSON.stringify(payload), {
    ...init,
    headers
  });
}
