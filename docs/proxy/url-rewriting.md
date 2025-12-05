# URL Rewriting Functionality

## Overview

The proxy server automatically rewrites URLs in HTML content and intercepts JavaScript network requests to ensure all resources are loaded through the proxy. This enables external websites to be displayed in iframes while maintaining functionality.

## How It Works

### Phase 1: HTML Processing

When HTML content is fetched through the proxy, it undergoes several transformations:

1. **Base Href Injection**: A `<base href>` tag is injected to ensure relative URLs resolve correctly
2. **HTML Attribute Rewriting**: URLs in HTML attributes are rewritten to go through the proxy
3. **JavaScript Interception**: A script is injected to intercept runtime URL requests
4. **Consent Cleanup**: Cookie consent banners are hidden (if applicable)

### Phase 2: JavaScript Interception

A JavaScript script is injected early in the page load to intercept:

- **`fetch()` API calls**: All fetch requests are intercepted and URLs are rewritten
- **`XMLHttpRequest`**: XHR open() calls are intercepted
- **Dynamic script tags**: Script tags with `type="module"` have their `src` attributes intercepted

## What Gets Rewritten

### HTML Attributes

The following HTML attributes are scanned and rewritten:

- `src` - Images, scripts, iframes, etc.
- `href` - Links, stylesheets, etc.
- `srcset` - Responsive images
- `data-src` - Lazy-loaded images
- `data-href` - Data attributes for links
- `data-srcset` - Lazy-loaded responsive images
- `action` - Form actions
- `formaction` - Form button actions
- `cite` - Citation URLs
- `poster` - Video poster images
- `background` - Background images (deprecated but supported)
- `content` - Meta tag content URLs

### CSS `url()` References

URLs in CSS `url()` functions are rewritten, including:

- `background-image: url(...)`
- `@import url(...)`
- Inline styles and `<style>` tags

### JavaScript-Generated URLs

The following JavaScript APIs are intercepted:

- **`fetch(url)`** - All fetch requests (including Request objects with preserved headers/body)
- **`XMLHttpRequest.open(method, url)`** - XHR requests
- **`<script type="module" src="...">`** - ES module imports
- **`HTMLLinkElement.prototype.href`** - Dynamic stylesheet loading
- **`HTMLIFrameElement.prototype.src`** - Dynamic iframe creation
- **`HTMLImageElement.prototype.src`** - Dynamic image loading
- **`Image()` constructor** - Image object creation
- **`Audio()` constructor** - Audio object creation
- **`Element.prototype.innerHTML`** - Script tags in innerHTML
- **`Element.prototype.outerHTML`** - Script tags in outerHTML

## URL Types Handled

### Absolute URLs

```
https://example.com/file.js
→ http://localhost:3100/proxy?url=https%3A%2F%2Fexample.com%2Ffile.js
```

### Protocol-Relative URLs

```
//cdn.example.com/file.js
→ http://localhost:3100/proxy?url=https%3A%2F%2Fcdn.example.com%2Ffile.js
```

### Root-Relative Paths

```
/js/file.js
→ http://localhost:3100/proxy?url=https%3A%2F%2Fwww.example.com%2Fjs%2Ffile.js
```

### Relative Paths

```
./file.js
../images/logo.png
file.js
→ All resolved against the target page's origin and rewritten
```

## What Does NOT Get Rewritten

The following URL types are intentionally skipped:

- **Data URLs**: `data:image/png;base64,...`
- **Blob URLs**: `blob:http://localhost/uuid`
- **JavaScript URLs**: `javascript:void(0)`
- **Mailto/Tel**: `mailto:test@example.com`, `tel:+1234567890`
- **Anchors/Fragments**: `#section`
- **About URLs**: `about:blank`
- **Already Proxied URLs**: URLs that already contain `/proxy?url=`
- **Same-Origin URLs**: URLs on the proxy origin itself

## Implementation Details

### Server-Side Rewriting

**Files**: `functions/proxy.js`, `preview/scripts/background-proxy-server.js`

- `rewriteResourceUrls()`: Scans HTML and rewrites URLs in attributes
- `rewriteUrl()`: Core URL rewriting logic
- `ensureBaseHref()`: Injects base href tag
- `injectUrlRewritingScript()`: Injects JavaScript interception code

### Client-Side Interception

The injected JavaScript:

1. Runs immediately when the page loads (before other scripts)
2. Intercepts `fetch()`, `XMLHttpRequest`, and script tag creation
3. Rewrites URLs before they're sent to the network
4. Preserves original functionality while routing through proxy

## Edge Cases and Limitations

### Known Limitations

1. **Native `import()`**: The native dynamic `import()` function cannot be intercepted directly. However, script tags with `type="module"` are intercepted.

2. **Service Workers**: Service Workers may bypass interception if they're already registered. The proxy attempts to intercept before SW registration.

3. **WebSockets**: WebSocket connections are not proxied (by design, as they require persistent connections).

4. **WebAssembly**: WASM modules loaded via `fetch()` will be intercepted, but direct WASM instantiation may not be.

5. **Content Security Policy**: Some CSP headers may conflict with the injected script. The proxy removes CSP headers that block iframe embedding.

### Error Handling

### Content-Type Aware Error Responses

The proxy intelligently handles error responses based on the request type:

- **HTML requests**: Return HTML error pages (for display in browser)
- **JavaScript/JSON requests**: Return JSON error responses (prevents MIME type errors)
- **Other requests**: Return original error response from upstream

This prevents issues where JavaScript modules receive HTML error pages, which would cause:
```
Failed to load module script: Expected a JavaScript-or-Wasm module script 
but the server responded with a MIME type of "text/html"
```

### HTML Entity Decoding

URLs containing HTML entities are automatically decoded before processing:

- `&#x27;` → `'`
- `&#39;` → `'`
- `&quot;` → `"`
- `&amp;` → `&`
- `&lt;` → `<`
- `&gt;` → `>`
- `&#x2F;` → `/`
- `&#47;` → `/`

This prevents malformed URLs that would cause 404 errors.

## Edge Cases Handled

- **Query Parameters**: Preserved in rewritten URLs
- **Fragments/Hashes**: Preserved in rewritten URLs
- **Redirects**: Base href uses the final URL after redirects
- **Multiple Base Tags**: Existing base tags are detected and not duplicated
- **Malformed URLs**: Invalid URLs are returned unchanged to avoid breaking pages
- **Race Conditions**: Script guard prevents multiple installations
- **Request Objects**: Fetch Request objects are properly cloned with new URL while preserving headers/body
- **srcset Attributes**: Multiple URLs in srcset are individually rewritten
- **CSS url()**: URLs in CSS url() functions are rewritten

## HTTP Method Support

The proxy supports multiple HTTP methods for proxying requests:

- **GET**: Standard page and resource requests
- **POST**: Form submissions, API calls, analytics tracking
- **PUT**: Resource updates
- **DELETE**: Resource deletion
- **OPTIONS**: CORS preflight requests (handled automatically)

### POST/PUT Request Handling

When proxying POST or PUT requests:

1. The request method is forwarded to the upstream server
2. The request body is read and forwarded as-is
3. Content-Type header is preserved
4. All other headers are forwarded normally

Example:
```javascript
// POST request through proxy
fetch('/proxy?url=https://api.example.com/endpoint', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ data: 'value' })
});
```

### CORS Support

The proxy includes full CORS support:

- Preflight (OPTIONS) requests are handled automatically
- CORS headers are set appropriately for all methods
- Credentials are allowed (`access-control-allow-credentials: true`)
- CORS headers from upstream are forwarded when present

## Security Features

### Rate Limiting
- Default: 100 requests per minute per IP
- Configurable via `PROXY_RATE_LIMIT_MAX` environment variable
- Express server uses `express-rate-limit` middleware
- Cloudflare Workers uses in-memory rate limiting

### Cookie Sanitization
- Sensitive cookies are automatically filtered before forwarding to target sites
- Default patterns: `session`, `auth`, `token`, `csrf`, `jwt`, `secret`, `password`, `credential`
- Configurable via `PROXY_SENSITIVE_COOKIE_PATTERNS` environment variable (comma-separated)

### Secure Defaults
- **Allowlist**: Default is `*` (all hosts) for ease of use
- For production deployments, restrict by setting `BACKGROUND_PROXY_ALLOWLIST` environment variable
- Example: `BACKGROUND_PROXY_ALLOWLIST=example.com,*.example.com`
- Rate limiting and cookie sanitization provide additional security even with wildcard allowlist

### Production Logging
- Debug logging is disabled in production by default
- Set `PROXY_DEBUG=true` to enable debug logging in production
- Logging controlled by `NODE_ENV` environment variable

## Testing

### Unit Tests

**File**: `tests/unit/proxy/url-rewriting.test.js`

Tests cover:
- Absolute URLs
- Protocol-relative URLs
- Root-relative paths
- Relative paths
- Special URLs (data:, blob:, etc.)
- Edge cases (empty strings, null, etc.)
- srcset attribute rewriting
- CSS url() rewriting
- outerHTML handling
- Request object preservation

### Integration Tests

**File**: `tests/integration/preview/url-rewriting.test.mjs`

Tests verify:
- Relative path rewriting in HTML
- JavaScript interception script injection
- Base href injection
- Real-world scenarios (uncommongoods.com)
- Rate limiting behavior
- Cookie sanitization

### Race Condition Tests

**File**: `tests/unit/proxy/race-condition.test.js`

Tests verify:
- Single script execution succeeds
- Multiple executions are blocked
- Concurrent execution attempts only allow one
- Server-side duplicate detection
- Flag persistence across page reloads

### Demo Proxy Test

**File**: `tests/integration/preview/demo-proxy.test.mjs`

Enhanced to check for:
- URL rewriting in HTML
- JavaScript interception presence
- Relative path rewriting

## Performance Considerations

- **Minimal Overhead**: URL rewriting happens once during HTML processing
- **Early Injection**: JavaScript interception runs before page scripts to catch early requests
- **No Runtime Overhead**: Once URLs are rewritten, no additional processing is needed
- **Caching**: Rewritten URLs can be cached normally by the browser

## Troubleshooting

### Resources Not Loading

1. **Check if URL is being rewritten**: Look for `/proxy?url=` in the HTML source
2. **Check JavaScript interception**: Verify `data-pi-proxy="url-rewriting"` script is present
3. **Check browser console**: Look for CORS errors or network failures
4. **Verify proxy server**: Ensure proxy server is running and accessible

### Relative Paths Not Working

1. **Check base href**: Verify `<base href>` tag is present and correct
2. **Check JavaScript interception**: Ensure fetch/XHR interception is working
3. **Check browser console**: Look for errors in URL resolution

### JavaScript Errors

1. **Check script injection**: Verify the rewriting script is injected correctly
2. **Check for conflicts**: Some page scripts may conflict with interception
3. **Check CSP**: Content Security Policy may block the injected script

## Examples

### Example 1: Simple Image

```html
<!-- Original -->
<img src="/images/logo.png">

<!-- After rewriting -->
<img src="http://localhost:3100/proxy?url=https%3A%2F%2Fwww.example.com%2Fimages%2Flogo.png">
```

### Example 2: JavaScript Fetch

```javascript
// Original code
fetch('/api/data.json')
  .then(response => response.json())
  .then(data => console.log(data));

// After interception (transparent to code)
// Internally rewritten to:
// fetch('http://localhost:3100/proxy?url=https%3A%2F%2Fwww.example.com%2Fapi%2Fdata.json')
```

### Example 3: Dynamic Import

```javascript
// Original code
import('./module.js').then(module => {
  // Use module
});

// Script tag interception catches:
// <script type="module" src="./module.js">
// And rewrites to:
// <script type="module" src="http://localhost:3100/proxy?url=...">
```

## Related Documentation

- [Proxy Server Overview](../deployment/proxy-server.md)
- [403 Error Handling](403-error-handling.md)
- [Consent Banner Cleanup](consent-cleanup.md)

