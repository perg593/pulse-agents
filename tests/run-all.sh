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

# Integration tests
echo ""
echo "🔗 Integration Tests"
echo "-------------------"

echo "Testing preview bridge contract..."
node tests/integration/preview/bridge.contract.test.mjs

echo "Testing preview survey bridge integration..."
node tests/integration/preview/surveyBridge.integration.test.mjs

echo ""
echo "✅ All tests completed"

