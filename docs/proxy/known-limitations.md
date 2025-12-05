# Proxy Known Limitations

## Date: 2025-12-05

## Fixed Issues

### Race Conditions
- ✅ **Fixed**: Multiple script installations now prevented with guard mechanism
- ✅ **Fixed**: Server-side duplicate script tag detection
- ✅ **Fixed**: Request object handling in fetch interception (now preserves headers/body)

### Missing Interceptions
- ✅ **Fixed**: Added `outerHTML` interception for script tags
- ✅ **Fixed**: Added `HTMLLinkElement.prototype.href` interception (stylesheets)
- ✅ **Fixed**: Added `HTMLIFrameElement.prototype.src` interception (nested iframes)
- ✅ **Fixed**: Added `HTMLImageElement.prototype.src` interception (images)
- ✅ **Fixed**: Added `Image()` constructor interception
- ✅ **Fixed**: Added `Audio()` constructor interception

## Uncommongoods.com - Dynamic Script Loading

**Status**: Known Issue - Site may be blocking proxy in ways we cannot intercept

**Problem**: 
- Dynamic webpack chunks (e.g., `/js/20251203154408-374/ug-spa/dist/4352.js`) are not being proxied
- These chunks return 404 errors when accessed directly
- Script interception is injected and running, but chunks are still not being rewritten

**What We've Tried**:
1. ✅ Script injection with URL rewriting
2. ✅ Prototype-level interception (`HTMLScriptElement.prototype.src`)
3. ✅ `setAttribute` interception
4. ✅ `appendChild`/`insertBefore` interception
5. ✅ Multiple detection methods for proxied pages
6. ✅ Enhanced `getCurrentOrigin()` with fallbacks

**Possible Causes**:
- Webpack may be using a method we haven't intercepted (e.g., `document.write`, Service Workers, or native module loading)
- Site may have Content Security Policy that blocks our interception
- Site may be detecting proxy and blocking dynamically loaded resources
- Timing issue - chunks may be loaded before our script executes

**Workaround**:
- Site may need to be added to a blocklist or handled specially
- Consider contacting site owner if this is a critical demo URL

**Impact**:
- Low - Only affects uncommongoods.com specifically
- Other sites with webpack code splitting work correctly
- Static resources and initial page load work fine

## Other Known Limitations

### Service Workers
- Service Workers may bypass our URL interception
- Service Worker requests are not intercepted by our script

### WebSockets
- WebSocket connections are not proxied
- This is intentional - WebSockets require persistent connections

### Native Module Loading
- Native ES module `import()` may bypass interception in some browsers
- We intercept script tag creation, but native imports may use different mechanisms

### Content Security Policy
- Sites with strict CSP may block our injected script
- CSP violations may prevent script execution

### Timing Issues
- Scripts loaded synchronously before our interception may not be caught
- We inject early in `<head>`, but some sites load scripts immediately

## Security Features

### Rate Limiting
- ✅ **Implemented**: Express server uses `express-rate-limit` (100 requests/minute default)
- ✅ **Implemented**: Cloudflare Workers uses in-memory rate limiting (100 requests/minute default)
- Configurable via `PROXY_RATE_LIMIT_MAX` environment variable

### Cookie Sanitization
- ✅ **Implemented**: Sensitive cookies are filtered before forwarding
- Default patterns: `session`, `auth`, `token`, `csrf`, `jwt`, `secret`, `password`, `credential`
- Configurable via `PROXY_SENSITIVE_COOKIE_PATTERNS` environment variable

### Secure Defaults
- ✅ **Implemented**: Default allowlist remains `*` (all) for ease of use
- Users can restrict by setting `BACKGROUND_PROXY_ALLOWLIST` environment variable for production
- Rate limiting and cookie sanitization provide security even with wildcard allowlist

## HTTP Method Support

### Supported Methods
- ✅ **GET**: Fully supported (original implementation)
- ✅ **POST**: Fully supported (added 2025-12-05)
- ✅ **PUT**: Fully supported (added 2025-12-05)
- ✅ **DELETE**: Fully supported (added 2025-12-05)
- ✅ **OPTIONS**: Supported for CORS preflight requests

### POST/PUT Request Body Handling
- Request body is forwarded to upstream server
- Content-Type header is preserved
- Body is read as ArrayBuffer and forwarded as-is
- Supports JSON, form data, and binary payloads

### CORS Support
- ✅ **Implemented**: Full CORS support for all HTTP methods
- Preflight (OPTIONS) requests are handled automatically
- CORS headers are forwarded from upstream when present
- Credentials are allowed (`access-control-allow-credentials: true`)

## Error Handling

### Improved Error Responses
- ✅ **Implemented**: JavaScript/JSON requests receive JSON error responses (not HTML)
- ✅ **Implemented**: HTML requests receive HTML error pages
- ✅ **Implemented**: Proper Content-Type detection for error responses
- Prevents MIME type errors when JavaScript modules fail to load

### HTML Entity Decoding
- ✅ **Implemented**: HTML entities in URLs are decoded before processing
- Supports common entities: `&#x27;`, `&#39;`, `&quot;`, `&amp;`, `&lt;`, `&gt;`, `&#x2F;`, `&#47;`
- Prevents malformed URLs from causing 404 errors

## Future Improvements

1. **Service Worker Interception**: Intercept `navigator.serviceWorker.register()` to proxy worker scripts
2. **Native Import Interception**: Better support for dynamic `import()` statements
3. **CSP Bypass**: Detect and handle CSP violations more gracefully
4. **Earlier Injection**: Use MutationObserver to catch scripts created before our script runs
5. **Webpack-Specific Interception**: Detect webpack runtime and intercept `__webpack_require__.e()`
6. **document.write() Interception**: Intercept `document.write()` and `document.writeln()` for script injection

