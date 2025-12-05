# saasrise.com Redirect and Server Activity Analysis

## Overview

This document analyzes the underlying redirects and server activities that occur when loading `saasrise.com` through the preview tool at `https://pulse-agents-demo.pages.dev/?present=8090`.

## Key Finding: Server-Side Proxy Handling

The preview tool uses a **Cloudflare Functions proxy** (`/proxy?url=...`) that handles all redirects server-side. This means:

1. **Browser HAR files don't capture the proxy's internal redirect chain** - The proxy request happens server-side, so browser devtools only see the final HTML response
2. **All HTTP redirects are automatically followed** - The proxy uses `redirect: 'follow'` which means intermediate redirects (301, 302, etc.) are handled transparently
3. **The browser receives the final response** - After following all redirects, the proxy returns the final HTML content

## Proxy Implementation Details

### Redirect Handling

```52:57:functions/proxy.js
  try {
    const upstreamHeaders = buildUpstreamHeaders(request.headers, target);
    const upstreamResponse = await fetch(target.toString(), {
      headers: upstreamHeaders,
      redirect: 'follow'
    });
```

The `redirect: 'follow'` option means:
- **301 (Permanent Redirect)**: Automatically followed
- **302 (Temporary Redirect)**: Automatically followed  
- **307/308**: Automatically followed
- **Redirect loops**: Would cause fetch to fail (not observed)

### Headers Sent to saasrise.com

The proxy forwards these headers to the upstream server:

```131:166:functions/proxy.js
function buildUpstreamHeaders(headers, target) {
  const upstream = new Headers();
  const headerPairs = [
    ['user-agent', headers.get('user-agent') || DEFAULT_USER_AGENT],
    ['accept', headers.get('accept') || '*/*'],
    ['accept-language', headers.get('accept-language') || 'en-US,en;q=0.9'],
    ['accept-encoding', headers.get('accept-encoding') || 'gzip, deflate, br'],
    ['referer', headers.get('referer') || target.origin],
    ['origin', headers.get('origin') || target.origin],
    ['cookie', headers.get('cookie')]
  ];

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
    ['sec-fetch-site', headers.get('sec-fetch-site') || 'none']
  ];

  secHeaders.forEach(([key, value]) => {
    if (value) {
      upstream.set(key, value);
    }
  });

  return upstream;
}
```

**Default User-Agent**:
```
Mozilla/5.0 (Macintosh; Intel Mac OS X 14_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 PulsePreviewProxy/1.0
```

## Expected Redirect Chain for saasrise.com

Based on common web server configurations and the proxy's behavior, here's what likely happens:

### Step 1: Initial Request
- **URL**: `https://saasrise.com/` (or `https://www.saasrise.com/`)
- **Method**: GET
- **Headers**: As specified above (User-Agent, Accept, Referer, etc.)

### Step 2: Possible Redirects (Server-Side, Not Visible in Browser)

Common redirect patterns for saasrise.com:

1. **www → non-www** (or vice versa)
   - `https://www.saasrise.com/` → `https://saasrise.com/`
   - Status: 301 Moved Permanently
   - Header: `Location: https://saasrise.com/`

2. **HTTP → HTTPS** (if HTTP was requested)
   - `http://saasrise.com/` → `https://saasrise.com/`
   - Status: 301 Moved Permanently
   - Header: `Location: https://saasrise.com/`

3. **Trailing Slash Normalization**
   - `https://saasrise.com` → `https://saasrise.com/`
   - Status: 301 Moved Permanently
   - Header: `Location: https://saasrise.com/`

4. **Subdomain Redirects**
   - Various subdomains might redirect to main domain
   - Status: 301/302

### Step 3: Final Response
- **Status**: 200 OK
- **Content-Type**: `text/html`
- **Body**: HTML content from saasrise.com

## HTML Content Modifications

After fetching the final HTML, the proxy modifies it:

```67:74:functions/proxy.js
    if (contentType.includes('text/html')) {
      let body = await upstreamResponse.text();
      body = ensureBaseHref(body, target);
      body = injectConsentCleanup(body);
      return new Response(body, {
        status: upstreamResponse.status,
        headers: responseHeaders
      });
    }
```

### Modifications Applied:

1. **Base Href Injection** (`ensureBaseHref`)
   - Adds `<base href="...">` tag if missing
   - Ensures relative URLs resolve correctly
   - Uses the **final URL** after redirects

2. **Consent Banner Cleanup** (`injectConsentCleanup`)
   - Injects CSS to hide cookie consent banners
   - Injects JavaScript to remove consent elements
   - Targets common consent banner selectors:
     - `#onetrust-banner-sdk`
     - `.onetrust-pc-dark-filter`
     - `.cc-window`, `.cc-banner`
     - `.cookie-consent`
     - And many more (see `CONSENT_BANNER_SELECTORS`)

## Evidence from HAR File

The HAR file (`pulse-agents-demo.pages.dev.txt`) shows:

1. **No direct proxy request entry** - The proxy request happens server-side (Cloudflare Functions), so it's not captured in browser HAR files

2. **Third-party scripts reference the proxy URL** - Various tracking scripts (AdRoll, Google Ads, 33Across) include the proxy URL in their referrer parameters:
   ```
   arrfrr=https%3A%2F%2Fpulse-agents-demo.pages.dev%2Fproxy%3Furl%3Dhttps%253A%252F%252Fsaasrise.com%252F
   ```

3. **Multiple resource requests** - The proxied HTML triggers many subresource requests (scripts, stylesheets, images, etc.)

## Why It's "More Complicated"

The complexity comes from:

1. **Multiple Redirect Layers**:
   - DNS-level redirects
   - HTTP server redirects (301/302)
   - Application-level redirects (meta refresh, JavaScript)
   - CDN/proxy redirects

2. **Server-Side Processing**:
   - The proxy follows redirects automatically
   - Browser never sees intermediate redirects
   - Only final HTML is delivered

3. **Content Modifications**:
   - Base href injection changes relative URL resolution
   - Consent cleanup modifies DOM structure
   - These modifications happen after redirects are followed

4. **Third-Party Script Interactions**:
   - Tracking scripts receive the proxy URL as referrer
   - Some scripts may perform additional redirects
   - Cross-origin resource loading adds complexity

## How to Investigate Actual Redirects

To see the actual redirect chain for saasrise.com:

### Option 1: Server-Side Logging
Add logging to the proxy function to capture redirect chains:

```javascript
const response = await fetch(target.toString(), {
  headers: upstreamHeaders,
  redirect: 'follow'
});

// Log final URL (after redirects)
console.log(`Final URL after redirects: ${response.url}`);
```

### Option 2: Use `redirect: 'manual'`
Temporarily change to manual redirect handling to see intermediate responses:

```javascript
const response = await fetch(target.toString(), {
  headers: upstreamHeaders,
  redirect: 'manual'  // Don't follow automatically
});

if (response.status >= 300 && response.status < 400) {
  const location = response.headers.get('location');
  console.log(`Redirect ${response.status} to: ${location}`);
}
```

### Option 3: External Tools
Use curl or similar tools to trace redirects:

```bash
curl -I -L https://saasrise.com/
# -I: HEAD request (headers only)
# -L: Follow redirects
```

Or with verbose output:
```bash
curl -v -L https://saasrise.com/ 2>&1 | grep -i "location\|301\|302"
```

## Summary

When loading `saasrise.com` through the preview tool:

1. **Request Flow**:
   - Browser → Cloudflare Functions Proxy (`/proxy?url=https://saasrise.com/`)
   - Proxy → saasrise.com (with headers)
   - saasrise.com → Redirects (301/302) → Final URL
   - Proxy follows redirects automatically
   - Proxy modifies HTML (base href, consent cleanup)
   - Proxy → Browser (final HTML)

2. **Redirects**: Handled server-side, not visible in browser HAR files

3. **Complexity**: Multiple layers (DNS, HTTP, application) plus content modifications

4. **Evidence**: Third-party scripts in HAR file reference the proxy URL, confirming the proxy is used

## Recommendations

1. **Add redirect logging** to the proxy function to capture actual redirect chains
2. **Document expected redirects** for known sites like saasrise.com
3. **Consider caching redirect chains** to avoid repeated lookups
4. **Monitor redirect loops** which could cause proxy failures

