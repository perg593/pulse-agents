# Proxy Production Deployment Checklist

## Date: 2025-12-04

## Pre-Deployment Verification

### ✅ Code Changes Completed

- [x] Fixed early return check in script injection
- [x] Added multiple detection methods for proxied pages
- [x] Enhanced `getCurrentOrigin()` with multiple fallbacks
- [x] Implemented prototype-level script interception (`HTMLScriptElement.prototype.src`)
- [x] Added `setAttribute` interception for script tags
- [x] Added `appendChild`/`insertBefore` interception
- [x] Added `innerHTML` interception
- [x] Enhanced fetch/XHR interception
- [x] Fixed syntax error in innerHTML interception (template literal issue)
- [x] Added comprehensive debugging logs

### ✅ Testing Completed

- [x] Unit tests for URL rewriting (`tests/unit/proxy/url-rewriting.test.js`)
- [x] Unit tests for script interception (`tests/unit/proxy/script-interception.test.js`)
- [x] Integration tests for script injection (`tests/integration/preview/script-injection.test.mjs`)
- [x] Integration tests for script interception (`tests/integration/preview/script-interception.test.mjs`)
- [x] Integration tests for URL rewriting (`tests/integration/preview/url-rewriting.test.mjs`)
- [x] Demo proxy tests (`tests/integration/preview/demo-proxy.test.mjs`)
- [x] All tests passing

### ✅ Documentation Updated

- [x] URL rewriting documentation (`docs/proxy/url-rewriting.md`)
- [x] Known limitations documented (`docs/proxy/known-limitations.md`)
- [x] Test documentation (`tests/integration/preview/README-script-interception.md`)

## Files to Deploy

### Cloudflare Functions
- `functions/proxy.js` - Main proxy function (Cloudflare Workers)
- `functions/background-proxy/health.js` - Health check endpoint (if needed)

### Local Development
- `preview/scripts/background-proxy-server.js` - Local proxy server (Express)

### Configuration
- No configuration changes required
- Uses existing port configuration from `config/ports.js`

## Deployment Steps

### Cloudflare Workers (Production)

1. **Verify Function Export**:
   ```bash
   # Check that proxy.js exports onRequest correctly
   grep -n "export.*onRequest" functions/proxy.js
   ```

2. **Deploy via Wrangler** (if using Cloudflare Workers):
   ```bash
   wrangler deploy functions/proxy.js
   ```

3. **Or deploy via Cloudflare Dashboard**:
   - Upload `functions/proxy.js` as a Worker
   - Ensure route matches `/proxy*`

### Local Development Server

1. **No deployment needed** - runs locally via `npm start`
2. **Verify server starts**:
   ```bash
   npm start
   curl http://localhost:3100/background-proxy/health
   ```

## Post-Deployment Verification

### Health Checks

1. **Cloudflare Function** (if deployed):
   ```bash
   curl https://your-domain.com/proxy?url=https://www.example.com/
   ```

2. **Local Proxy Server**:
   ```bash
   curl http://localhost:3100/background-proxy/health
   curl http://localhost:3100/proxy?url=https://www.example.com/
   ```

### Functional Tests

1. **Test script injection**:
   ```bash
   npm run test:script-injection
   ```

2. **Test script interception**:
   ```bash
   npm run test:script-interception
   ```

3. **Test URL rewriting**:
   ```bash
   npm run test:url-rewriting
   ```

4. **Test demo proxy**:
   ```bash
   npm run test:demo-proxy
   ```

### Browser Testing

1. **Open preview**:
   ```
   http://localhost:8000/preview/basic/?present=8092
   ```

2. **Check browser console** for `[PI-Proxy]` logs:
   - Should see "URL rewriting script starting..."
   - Should see "Detection check:" with proxied status
   - Should see "Script tag interception installed"
   - Should see URL rewriting logs when resources are loaded

3. **Verify resources are proxied**:
   - Check Network tab - resources should have `/proxy?url=` in URL
   - Check that relative paths are rewritten
   - Check that dynamic scripts are intercepted

## Known Issues

### Uncommongoods.com
- **Status**: Not working - dynamic webpack chunks not being proxied
- **Impact**: Low - only affects this one site
- **Documentation**: See `docs/proxy/known-limitations.md`
- **Action**: Monitor, may need site-specific handling

## Rollback Plan

If issues occur in production:

1. **Cloudflare Workers**: Revert to previous version via dashboard
2. **Local Server**: Restart with previous code version
3. **No database changes** - no rollback needed for data

## Monitoring

### Metrics to Watch

1. **404 Errors**: Monitor for increase in 404s (may indicate interception failing)
2. **Script Injection**: Verify script is present in HTML responses
3. **Console Errors**: Check browser console for `[PI-Proxy]` errors
4. **Performance**: Monitor proxy response times

### Logs to Check

1. **Cloudflare Workers**: Check Workers logs in dashboard
2. **Local Server**: Check `/tmp/pulse-background-proxy.log`
3. **Browser Console**: Check for `[PI-Proxy]` debug messages

## Success Criteria

✅ Script injection working (verified in tests)  
✅ Prototype-level interception installed (verified in tests)  
✅ URL rewriting working (verified in tests)  
✅ All tests passing  
✅ Documentation complete  
⚠️ Uncommongoods.com limitation documented  

## Next Steps

1. Deploy to production
2. Monitor for issues
3. Collect feedback on uncommongoods.com if it becomes critical
4. Consider future improvements (Service Workers, native imports, etc.)

