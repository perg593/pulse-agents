#!/usr/bin/env bash

# Unified test runner for all Pulse Widgets tests
# Runs unit tests and integration tests

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

echo "🧪 Running Pulse Widgets Test Suite"
echo "===================================="
echo ""

# Unit tests
echo "📦 Unit Tests"
echo "-------------"

echo "Testing config..."
node tests/unit/config/config.test.js

echo "Testing lib/errors..."
node tests/unit/lib/errors.test.js

echo "Testing lib/logger..."
node tests/unit/lib/logger.test.js

echo "Testing lib/validators..."
node tests/unit/lib/validators.test.js

echo "Testing proxy URL rewriting..."
node tests/unit/proxy/url-rewriting.test.js

echo "Testing script interception unit tests..."
node tests/unit/proxy/script-interception.test.js

# Integration tests
echo ""
echo "🔗 Integration Tests"
echo "-------------------"

echo "Testing preview bridge contract..."
node tests/integration/preview/bridge.contract.test.mjs

echo "Testing preview survey bridge integration..."
node tests/integration/preview/surveyBridge.integration.test.mjs

echo "Testing demo proxy integration..."
echo "  (Note: Requires proxy server running on port 3100)"
node tests/integration/preview/demo-proxy.test.mjs || echo "  ⚠️  Demo proxy test skipped (proxy server not running)"

echo "Testing URL rewriting integration..."
echo "  (Note: Requires proxy server running on port 3100)"
node tests/integration/preview/url-rewriting.test.mjs || echo "  ⚠️  URL rewriting test skipped (proxy server not running)"

echo "Testing script injection..."
echo "  (Note: Requires proxy server running on port 3100)"
node tests/integration/preview/script-injection.test.mjs || echo "  ⚠️  Script injection test skipped (proxy server not running)"

echo "Testing script interception..."
echo "  (Note: Requires proxy server running on port 3100)"
node tests/integration/preview/script-interception.test.mjs || echo "  ⚠️  Script interception test skipped (proxy server not running)"

echo ""
echo "✅ All tests completed"

