# Demo Proxy Integration Test

Tests that all demo URLs from the Google Sheet load correctly through the proxy server.

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
node tests/integration/preview/demo-proxy.test.mjs
```

### With Custom Proxy URL
```bash
PROXY_BASE_URL=http://localhost:3100 node tests/integration/preview/demo-proxy.test.mjs
```

### As Part of Full Test Suite
```bash
npm test
```

## What It Tests

1. **Proxy Health Check**: Verifies the proxy server is running
2. **403 Error Handling**: Tests known URLs that return 403 to verify banner injection
3. **Demo Data Loading**: Loads demo URLs from Google Sheet CSV or fallback JSON
4. **URL Extraction**: Extracts unique URLs from demo records
5. **Proxy Functionality**: Tests each URL through the proxy:
   - Verifies HTTP 200 responses
   - Checks that HTML content loads
   - Validates URL rewriting (for HTML pages)
   - Verifies 403 responses have banner injection
6. **Success Rate**: Requires 80%+ success rate to pass

## Expected Output

```
🧪 Demo Proxy Integration Test
==============================

🔍 Checking proxy server at http://localhost:3100...
✅ Proxy server is running

🔒 Testing 403 error handling...
  ✅ https://www.waterworks.com/us_en/fixtures-bathtubs-sinks/kitchen/sinks
     Status 403 with banner injection
  ✅ https://www.xfinity.com
     Status 403 with banner injection

📥 Loading demo data from Google Sheet...
✅ Loaded 25 demos from Google Sheet

📋 Found 15 unique demo URLs to test

Testing batch 1/5...
  ✅ https://www.example.com
     Status 200 (URLs rewritten)
  ✅ https://www.bobcat.com/na/en/attachments
     Status 200 (URLs rewritten)
  ...

📊 Test Summary
===============
Total URLs tested: 15
✅ Successful: 14
❌ Failed: 1

🔒 403 Handling Test: 2/2 URLs with proper banner injection

🔒 URLs with 403 responses: 2
  ✅ With 403 banner: 2

✅ Test passed! Success rate: 93.3%
```

## Troubleshooting

### Proxy Server Not Running
```
❌ Proxy server not running: connect ECONNREFUSED

💡 Start the proxy server with: npm start
```

### Some URLs Fail
- Check if the URLs are still valid
- Some sites may block automated requests
- DNS failures are expected for some third-party domains
- Test requires 80% success rate (configurable in code)

### 403 Responses
- 403 responses are considered successful if they have banner injection
- The test verifies that HTML 403 responses include the `.pi-proxy-403-banner` element
- Known 403 URLs are tested separately to verify banner injection works
- If a 403 response doesn't have a banner, a warning is shown but the test doesn't fail

### Timeout Errors
- Increase timeout in test code (default: 10 seconds)
- Some sites may be slow to respond

## Test Configuration

Edit `tests/integration/preview/demo-proxy.test.mjs` to adjust:
- `timeout`: Request timeout (default: 10000ms)
- `concurrency`: Parallel requests (default: 3)
- `minSuccessRate`: Minimum pass rate (default: 0.8)

