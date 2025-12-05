# Script Interception Integration Tests

Tests that verify the JavaScript interception script is correctly injected and contains all required functionality for intercepting dynamic URL creation.

## Prerequisites

1. **Proxy server must be running** on port 3100 (default)
   ```bash
   npm start
   # or
   node preview/scripts/background-proxy-server.js
   ```

2. **Node.js 18+** (for native fetch support)

## Running the Test

### Standalone
```bash
node tests/integration/preview/script-interception.test.mjs
```

### With Custom Proxy URL
```bash
PROXY_BASE_URL=http://localhost:3100 node tests/integration/preview/script-interception.test.mjs
```

### As Part of Full Test Suite
```bash
npm test
# or
npm run test:script-interception
```

## What It Tests

1. **Script Interception Features**: Verifies all interception methods are present:
   - Multiple detection methods (URL pattern, referrer, origin)
   - `setAttribute` interception for script tags
   - `appendChild` interception
   - `insertBefore` interception
   - `innerHTML` interception
   - Enhanced `getCurrentOrigin()` with multiple fallbacks
   - Debug logging

2. **Webpack Code Splitting**: Tests that webpack-style dynamic script creation is intercepted:
   - Script tag creation interception
   - `appendChild`/`insertBefore` support
   - Script `src` property setter interception

3. **Relative Path Resolution**: Verifies that relative paths are correctly resolved:
   - Relative path handling (`./path`, `../path`, `path`)
   - Root-relative path handling (`/path`)
   - Protocol-relative URL handling (`//example.com`)

4. **Script Detection Logic**: Tests that the script correctly detects proxied pages:
   - URL pattern check (`/proxy?url=`)
   - URL-encoded pattern check (`proxy%3Furl%3D`)
   - Referrer check
   - Origin check
   - Proper early return logic

5. **Fetch Interception**: Verifies that `fetch()` interception handles all input types:
   - String URL handling
   - `Request` object handling
   - Object with `url` property handling

6. **Script Tag Interception**: Tests that script tag creation is intercepted:
   - `createElement` interception
   - `src` property setter interception
   - `setAttribute('src')` interception
   - `rewriteScriptSrc` helper function

## Expected Output

```
🧪 Script Interception Integration Tests
========================================

✅ Proxy server is running at http://localhost:3100

Testing script interception features...
  ✓ Multiple detection methods
  ✓ setAttribute interception
  ✓ appendChild interception
  ✓ insertBefore interception
  ✓ innerHTML interception
  ✓ Enhanced getCurrentOrigin
  ✓ Debug logging

Testing webpack code splitting interception...
  ✓ Script interception present
  ✓ Webpack support (appendChild/insertBefore)
  ✓ Script src property interception

Testing relative path resolution...
  ✓ Relative path handling
  ✓ Root-relative path handling
  ✓ Protocol-relative URL handling

Testing script detection logic...
  ✓ URL pattern check
  ✓ Referrer check
  ✓ Origin check
  ✓ Proper early return logic

Testing fetch interception...
  ✓ String URL handling
  ✓ Request object handling
  ✓ Object with url property handling

Testing script tag interception...
  ✓ createElement interception
  ✓ src property setter interception
  ✓ setAttribute('src') interception
  ✓ rewriteScriptSrc helper function

📊 Test Summary
===============
Total tests: 6
✅ Passed: 6
❌ Failed: 0

✅ All tests passed!
```

## Troubleshooting

### Test Fails: "Proxy server not running"
- Start the proxy server: `npm start`
- Verify it's running: `curl http://localhost:3100/background-proxy/health`

### Test Fails: "Script interception features missing"
- Check that the proxy server is using the latest code
- Verify `injectUrlRewritingScript()` is being called in the proxy
- Check the HTML response contains the script tag

### Test Fails: "Webpack code splitting not supported"
- Verify `appendChild` and `insertBefore` interception are present
- Check that `setAttribute` interception is implemented
- Ensure script `src` property setter is intercepted

### Test Fails: "Relative path resolution incorrect"
- Verify `rewriteUrlForJs()` function handles relative paths
- Check that `getCurrentOrigin()` returns correct base URL
- Ensure `new URL()` is used correctly for path resolution

## Related Tests

- **Unit Tests**: `tests/unit/proxy/script-interception.test.js` - Tests script syntax and structure
- **Script Injection Tests**: `tests/integration/preview/script-injection.test.mjs` - Tests script is injected
- **URL Rewriting Tests**: `tests/integration/preview/url-rewriting.test.mjs` - Tests URL rewriting functionality
- **Demo Proxy Tests**: `tests/integration/preview/demo-proxy.test.mjs` - Tests end-to-end proxy functionality

