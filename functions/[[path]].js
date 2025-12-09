/**
 * @fileoverview Catch-all proxy for ES module dynamic imports.
 *
 * When a proxied page uses dynamic imports like `import("/_nuxt/foo.js")`,
 * the browser resolves these relative to the document origin (preview domain)
 * rather than the original site. This function catches those requests and
 * proxies them to the correct origin based on the Referer header.
 *
 * Cloudflare Pages Functions routing:
 * - [[path]].js is a catch-all that runs for unmatched routes
 * - context.next() passes to static asset serving or 404
 * - /proxy routes are handled by proxy.js (higher priority)
 */

// Patterns that indicate a request is for a proxied site's assets or pages
const PROXY_ASSET_PATTERNS = [
  /^\/_nuxt\//,          // NuxtJS assets
  /^\/_next\//,          // Next.js assets
  /^\/static\//,         // Common static folder
  /^\/assets\//,         // Common assets folder
  /^\/cdn-cgi\//,        // Cloudflare scripts
  /^\/api\//,            // API routes (may need proxying)
  /\.(js|mjs|css|woff2?|ttf|eot|svg|png|jpg|jpeg|gif|webp|ico|json)$/i, // Asset file extensions
];

// Known NJ Transit routes that should be proxied (client-side navigation)
const NJTRANSIT_ROUTES = [
  /^\/train-to/,
  /^\/bus-to/,
  /^\/light-rail-to/,
  /^\/services/,
  /^\/status/,
  /^\/tickets/,
  /^\/destinations/,
  /^\/maps/,
  /^\/travel-alerts/,
  /^\/accessibility/,
  /^\/about-us/,
  /^\/careers/,
  /^\/contact/,
  /^\/subscribe/,
  /^\/privacy/,
  /^\/sitemap/,
];

// Paths that should NEVER be proxied (preview app paths)
const PREVIEW_PATHS = [
  '/preview/',
  '/index.html',
  '/favicon.ico',
  '/robots.txt',
  '/_headers',
  '/_redirects',
  '/config/',
  '/tests/',
  '/lib/',
  '/docs/',
];

/**
 * Cloudflare Pages catch-all function.
 * @param {Object} context - Pages Functions context
 * @returns {Response} Proxied response or pass-through
 */
export async function onRequest(context) {
  const { request } = context;
  const url = new URL(request.url);
  const pathname = url.pathname;

  // Skip root path - always serve preview app
  if (pathname === '/' || pathname === '') {
    return context.next();
  }

  // Skip explicit preview app paths
  if (PREVIEW_PATHS.some((p) => pathname.startsWith(p) || pathname === p.replace(/\/$/, ''))) {
    return context.next();
  }

  // Check if this looks like a proxied site asset
  const looksLikeProxyAsset = PROXY_ASSET_PATTERNS.some((pattern) => pattern.test(pathname));

  // Check if this is a known NJ Transit route (for client-side navigation)
  const looksLikeNjtransitRoute = NJTRANSIT_ROUTES.some((pattern) => pattern.test(pathname));

  // If it doesn't look like a proxy asset or NJ Transit route, pass through
  if (!looksLikeProxyAsset && !looksLikeNjtransitRoute) {
    return context.next();
  }

  // Check Referer header to determine which proxied site this request belongs to
  const referer = request.headers.get('Referer') || '';
  let targetOrigin = null;

  // Try to extract target origin from referer's proxy URL
  const proxyMatch = referer.match(/\/proxy\?url=([^&]+)/);
  if (proxyMatch) {
    try {
      const decodedUrl = decodeURIComponent(proxyMatch[1]);
      const targetUrl = new URL(decodedUrl);
      targetOrigin = targetUrl.origin;
    } catch (e) {
      // Ignore parsing errors
    }
  }

  // If no target origin from referer, check for stored origin in cookie
  if (!targetOrigin) {
    const cookies = request.headers.get('Cookie') || '';
    const originMatch = cookies.match(/__pi_proxy_origin=([^;]+)/);
    if (originMatch) {
      try {
        targetOrigin = decodeURIComponent(originMatch[1]);
      } catch (e) {
        // Ignore parsing errors
      }
    }
  }

  // If we couldn't determine the target origin, pass through
  // This will serve static files if they exist, or 404
  if (!targetOrigin) {
    return context.next();
  }

  // Fix NuxtJS asset paths - chunks without /_nuxt/ prefix need it added
  // NuxtJS chunks have hash-like names (e.g., BhYfDVsa.js, Thumbnail.CzOzmLo0.css)
  let fixedPathname = pathname;
  const isNuxtChunk = /^\/[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.(js|css|mjs)$/i.test(pathname);
  if (isNuxtChunk && !pathname.startsWith('/_nuxt/')) {
    fixedPathname = `/_nuxt${pathname}`;
    console.log('[PI-Proxy] Fixed NuxtJS chunk path:', { from: pathname, to: fixedPathname });
  }

  // Build the proxied URL
  const targetUrl = `${targetOrigin}${fixedPathname}${url.search}`;

  // For HTML page navigation (not assets), redirect to the main proxy
  // This ensures the page gets proper HTML rewriting, base href, etc.
  if (looksLikeNjtransitRoute) {
    const proxyUrl = `/proxy?url=${encodeURIComponent(targetUrl)}`;
    console.log('[PI-Proxy] Catch-all redirecting navigation:', {
      from: pathname,
      to: proxyUrl,
    });
    return Response.redirect(new URL(proxyUrl, url.origin).toString(), 302);
  }

  console.log('[PI-Proxy] Catch-all proxying asset:', {
    from: pathname,
    to: targetUrl,
    referer: referer.substring(0, 100),
  });

  try {
    // Create headers for the proxy request
    const proxyHeaders = new Headers();

    // Copy safe headers from original request
    const safeHeaders = ['accept', 'accept-encoding', 'accept-language', 'cache-control', 'if-modified-since', 'if-none-match'];
    for (const header of safeHeaders) {
      const value = request.headers.get(header);
      if (value) {
        proxyHeaders.set(header, value);
      }
    }

    // Set correct host for target
    proxyHeaders.set('Host', new URL(targetOrigin).host);

    // Fetch from the target origin
    const proxyRequest = new Request(targetUrl, {
      method: request.method,
      headers: proxyHeaders,
      body: request.method !== 'GET' && request.method !== 'HEAD' ? request.body : null,
      redirect: 'manual',
    });

    const response = await fetch(proxyRequest);

    // Create new response with modified headers
    const newHeaders = new Headers(response.headers);

    // Remove headers that might cause issues
    newHeaders.delete('x-frame-options');
    newHeaders.delete('content-security-policy');

    // Set CORS headers to allow loading from preview domain
    newHeaders.set('Access-Control-Allow-Origin', '*');
    newHeaders.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');

    // Store target origin in cookie for subsequent requests (if not already set)
    if (!request.headers.get('Cookie')?.includes('__pi_proxy_origin=')) {
      const cookieValue = encodeURIComponent(targetOrigin);
      newHeaders.append('Set-Cookie', `__pi_proxy_origin=${cookieValue}; Path=/; SameSite=Lax; Max-Age=3600`);
    }

    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers: newHeaders,
    });
  } catch (error) {
    console.error('[PI-Proxy] Catch-all proxy error:', {
      pathname,
      targetUrl,
      error: error.message,
    });
    // On error, pass through to next handler (will 404)
    return context.next();
  }
}
