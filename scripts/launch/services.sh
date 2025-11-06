#!/usr/bin/env bash

# Refreshes generated widget assets, rebuilds preview data,
# optionally re-runs theme exports/tests, and restarts the
# lightweight static server for manual QA.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Load port configuration from centralized config
if [[ -f "${ROOT_DIR}/config/ports.js" ]]; then
  # Extract port values from config file using Node.js
  PORTS_CONFIG=$(node -e "
    const config = require('${ROOT_DIR}/config/ports.js');
    const ports = config.getPorts('development');
    console.log('SERVER_PORT=' + ports.SERVER_PORT);
    console.log('STRIPE_DEMO_PORT=' + ports.STRIPE_DEMO_PORT);
    console.log('BACKGROUND_PROXY_PORT=' + ports.BACKGROUND_PROXY_PORT);
  ")
  eval "${PORTS_CONFIG}"
else
  # Fallback to default values if config not found
  SERVER_PORT="${SERVER_PORT:-8000}"
  STRIPE_DEMO_PORT="${STRIPE_DEMO_PORT:-4242}"
  BACKGROUND_PROXY_PORT="${BACKGROUND_PROXY_PORT:-3100}"
fi

LOG_FILE="${LOG_FILE:-/tmp/pulse-preview.log}"
RUN_WIDGETS="${RUN_WIDGETS:-1}"
RUN_DEMO_DATA="${RUN_DEMO_DATA:-1}"
RUN_EXAMPLES="${RUN_EXAMPLES:-1}"
RUN_PREVIEW_BUILD="${RUN_PREVIEW_BUILD:-1}"
RUN_TESTS="${RUN_TESTS:-1}"
RUN_STRIPE_DEMO_SERVER="${RUN_STRIPE_DEMO_SERVER:-1}"
RUN_BACKGROUND_PROXY="${RUN_BACKGROUND_PROXY:-1}"
STRIPE_DEMO_LOG="${STRIPE_DEMO_LOG:-/tmp/pulse-stripe-demo.log}"
BACKGROUND_PROXY_LOG="${BACKGROUND_PROXY_LOG:-/tmp/pulse-background-proxy.log}"
SERVER_PID=0
STRIPE_SERVER_PID=0
BACKGROUND_PROXY_PID=0

cleanup() {
  echo "🧹 Cleaning up processes..."
  local cleanup_timeout=10
  local start_time=$(date +%s)
  
  # Function to kill process with timeout
  kill_process() {
    local pid="$1"
    local name="$2"
    
    if [[ "${pid}" -ne 0 ]] && kill -0 "${pid}" >/dev/null 2>&1; then
      echo "  Stopping ${name} (PID: ${pid})..."
      
      # Try graceful shutdown first
      kill -TERM "${pid}" >/dev/null 2>&1 || true
      
      # Wait for process to terminate
      local wait_count=0
      while kill -0 "${pid}" >/dev/null 2>&1 && [[ ${wait_count} -lt 5 ]]; do
        sleep 1
        wait_count=$((wait_count + 1))
      done
      
      # Force kill if still running
      if kill -0 "${pid}" >/dev/null 2>&1; then
        echo "  Force killing ${name} (PID: ${pid})..."
        kill -KILL "${pid}" >/dev/null 2>&1 || true
        sleep 1
      fi
      
      # Verify process is gone
      if kill -0 "${pid}" >/dev/null 2>&1; then
        echo "  ⚠️  Warning: ${name} (PID: ${pid}) may still be running"
      else
        echo "  ✅ ${name} stopped successfully"
      fi
    fi
  }
  
  # Kill all processes
  kill_process "${SERVER_PID}" "Preview Server"
  kill_process "${STRIPE_SERVER_PID}" "Stripe Demo Server"
  kill_process "${BACKGROUND_PROXY_PID}" "Background Proxy"
  
  # Check cleanup timeout
  local end_time=$(date +%s)
  local cleanup_duration=$((end_time - start_time))
  if [[ ${cleanup_duration} -gt ${cleanup_timeout} ]]; then
    echo "  ⚠️  Warning: Cleanup took ${cleanup_duration}s (timeout: ${cleanup_timeout}s)"
  else
    echo "  ✅ Cleanup completed in ${cleanup_duration}s"
  fi
}
trap cleanup EXIT

ensure() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "❌  Missing required command: $1" >&2
    echo "    Please install $1 and try again" >&2
    exit 1
  fi
}

# Enhanced dependency checks
check_dependencies() {
  echo "🔍 Checking system dependencies..."
  
  # Check Node.js version
  if command -v node >/dev/null 2>&1; then
    local node_version=$(node --version | sed 's/v//')
    local major_version=$(echo "${node_version}" | cut -d. -f1)
    if [[ ${major_version} -lt 16 ]]; then
      echo "⚠️  Warning: Node.js version ${node_version} detected. Recommended: Node.js 16+"
    else
      echo "✅ Node.js ${node_version} detected"
    fi
  else
    echo "❌ Node.js not found. Please install Node.js 16+ from https://nodejs.org/"
    exit 1
  fi
  
  # Check npm
  if ! command -v npm >/dev/null 2>&1; then
    echo "❌ npm not found. Please install npm (usually comes with Node.js)"
    exit 1
  fi
  
  # Check Python version
  if command -v python3 >/dev/null 2>&1; then
    local python_version=$(python3 --version | sed 's/Python //')
    local major_version=$(echo "${python_version}" | cut -d. -f1)
    if [[ ${major_version} -lt 3 ]]; then
      echo "❌ Python 3 required, found Python ${python_version}"
      exit 1
    else
      echo "✅ Python ${python_version} detected"
    fi
  else
    echo "❌ Python 3 not found. Please install Python 3 from https://python.org/"
    exit 1
  fi
  
  # Check Git
  if ! command -v git >/dev/null 2>&1; then
    echo "⚠️  Warning: Git not found. Some features may not work properly"
  else
    echo "✅ Git detected"
  fi
  
  echo "✅ All required dependencies found"
  echo ""
}

# Run dependency checks
check_dependencies

# Basic command checks
ensure curl
ensure lsof
ensure python3
if [[ "${RUN_STRIPE_DEMO_SERVER}" == "1" ]]; then
  ensure node
fi
if [[ "${RUN_BACKGROUND_PROXY}" == "1" ]]; then
  ensure node
fi

ensure_node_modules() {
  local directory="$1"
  local description="$2"
  if [ -d "${directory}" ] && [ ! -d "${directory}/node_modules" ]; then
    echo "➡️  Installing ${description} dependencies…"
    (cd "${directory}" && npm install)
  fi
}

ensure_node_modules "${ROOT_DIR}" "root"
ensure_node_modules "${ROOT_DIR}/theme-generator/v1" "theme-generator"
ensure_node_modules "${ROOT_DIR}/pi-master" "pi-master"

run_step() {
  local message="$1"
  shift
  echo "➡️  ${message}"
  "$@"
}

cd "${ROOT_DIR}"

if [[ "${RUN_WIDGETS}" == "1" ]]; then
  if [ -d "${ROOT_DIR}/pi-master" ]; then
    run_step "Generating widget snapshots from pi-master..." node scripts/build/generate-widgets.js
  else
    echo "⚠️  Skipping widget generation - pi-master directory not found (optional)"
  fi
fi

if [[ "${RUN_DEMO_DATA}" == "1" ]]; then
  run_step "Building demo survey dataset..." node scripts/build/demo-data.js
fi

if [[ "${RUN_EXAMPLES}" == "1" ]]; then
  run_step "Exporting latest example themes..." bash -lc 'cd theme-generator/v1 && npm run examples:export'
fi

if [[ "${RUN_PREVIEW_BUILD}" == "1" ]]; then
  run_step "Rebuilding preview manifest and default CSS..." bash -lc 'cd theme-generator/v1 && npm run preview:build'
fi

if [[ "${RUN_TESTS}" == "1" ]]; then
  run_step "Running theme-generator unit tests..." bash -lc 'cd theme-generator/v1 && npm run test:unit'
fi

# Function to wait for service readiness with exponential backoff
wait_for_service() {
  local service_name="$1"
  local health_url="$2"
  local max_attempts="${3:-30}"
  local base_delay="${4:-1}"
  
  echo "  Checking ${service_name} readiness..."
  local attempt=1
  local delay=${base_delay}
  
  while [[ ${attempt} -le ${max_attempts} ]]; do
    if curl --silent --fail --max-time 2 "${health_url}" >/dev/null 2>&1; then
      echo "  ✅ ${service_name} is ready (attempt ${attempt})"
      return 0
    fi
    
    echo "  ⏳ ${service_name} not ready yet, waiting ${delay}s... (attempt ${attempt}/${max_attempts})"
    sleep ${delay}
    
    # Exponential backoff with max delay of 5 seconds
    delay=$((delay * 2))
    if [[ ${delay} -gt 5 ]]; then
      delay=5
    fi
    
    attempt=$((attempt + 1))
  done
  
  echo "  ❌ ${service_name} failed to become ready after ${max_attempts} attempts"
  return 1
}

# Function to start service with proper readiness check
start_service() {
  local service_name="$1"
  local port="$2"
  local start_command="$3"
  local health_url="$4"
  local log_file="$5"
  local pid_var="$6"
  
  # Stop existing service if running
  if lsof -tiTCP:${port} -sTCP:LISTEN >/dev/null 2>&1; then
    echo "↻  Stopping existing ${service_name} on port ${port}..."
    lsof -tiTCP:${port} -sTCP:LISTEN | xargs kill
    sleep 2  # Increased wait time for proper cleanup
  fi
  
  echo "➡️  Starting ${service_name} (port ${port})"
  eval "${start_command}"
  eval "${pid_var}=$!"
  
  # Wait for service to be ready
  if ! wait_for_service "${service_name}" "${health_url}" 30 2; then
    echo "❌ Failed to start ${service_name}"
    return 1
  fi
  
  return 0
}

if [[ "${RUN_BACKGROUND_PROXY}" == "1" ]]; then
  start_service "Background Proxy" "${BACKGROUND_PROXY_PORT}" \
    "nohup env BACKGROUND_PROXY_PORT=\"${BACKGROUND_PROXY_PORT}\" node preview/scripts/background-proxy-server.js >\"${BACKGROUND_PROXY_LOG}\" 2>&1 &" \
    "http://localhost:${BACKGROUND_PROXY_PORT}/background-proxy/health" \
    "${BACKGROUND_PROXY_LOG}" \
    "BACKGROUND_PROXY_PID"
fi

if [[ "${RUN_STRIPE_DEMO_SERVER}" == "1" ]]; then
  if [[ -z "${STRIPE_SECRET_KEY:-}" ]]; then
    echo "⚠️  Skipping Stripe Demo Server - STRIPE_SECRET_KEY not set (optional)"
    echo "   To enable: export STRIPE_SECRET_KEY='sk_test_...'"
    RUN_STRIPE_DEMO_SERVER=0
  else
    start_service "Stripe Demo Server" "${STRIPE_DEMO_PORT}" \
      "nohup env STRIPE_DEMO_PORT=\"${STRIPE_DEMO_PORT}\" STRIPE_SECRET_KEY=\"${STRIPE_SECRET_KEY}\" node preview/scripts/stripe-demo-server.js >\"${STRIPE_DEMO_LOG}\" 2>&1 &" \
      "http://localhost:${STRIPE_DEMO_PORT}/stripe-demo/health" \
      "${STRIPE_DEMO_LOG}" \
      "STRIPE_SERVER_PID"
  fi
fi

# Start main server last to ensure all dependencies are ready
if lsof -tiTCP:${SERVER_PORT} -sTCP:LISTEN >/dev/null 2>&1; then
  echo "↻  Stopping existing server on port ${SERVER_PORT}..."
  lsof -tiTCP:${SERVER_PORT} -sTCP:LISTEN | xargs kill
  sleep 2  # Increased wait time for proper cleanup
fi

echo "➡️  Starting python static server on http://localhost:${SERVER_PORT}/"
nohup python3 -m http.server "${SERVER_PORT}" >"${LOG_FILE}" 2>&1 &
SERVER_PID=$!

# Wait for main server to be ready
if ! wait_for_service "Preview Server" "http://localhost:${SERVER_PORT}/" 30 2; then
  echo "❌ Failed to start preview server"
  exit 1
fi

MANIFEST_URL="http://localhost:${SERVER_PORT}/theme-generator/output/preview-manifest.json"
DEFAULT_CSS_URL="http://localhost:${SERVER_PORT}/preview/dist/default.css"
BASIC_HTML_URL="http://localhost:${SERVER_PORT}/preview/basic/index.html"
STRIPE_BACKGROUND_URL="http://localhost:${SERVER_PORT}/preview/backgrounds/stripe-checkout/index.html"
STRIPE_HEALTH_URL="http://localhost:${STRIPE_DEMO_PORT}/stripe-demo/health"

echo "➡️  Performing final health checks..."

# Check preview assets
echo "  Checking preview assets..."
if ! wait_for_service "Preview Assets" "${MANIFEST_URL}" 20 1; then
  echo "❌ Preview assets not accessible"
  exit 1
fi

# Check additional assets
for asset_url in "${DEFAULT_CSS_URL}" "${BASIC_HTML_URL}" "${STRIPE_BACKGROUND_URL}"; do
  if ! curl --silent --fail --max-time 2 "${asset_url}" >/dev/null 2>&1; then
    echo "⚠️  Warning: Asset not accessible: ${asset_url}"
  fi
done

# Check Stripe demo server if running
if [[ "${RUN_STRIPE_DEMO_SERVER}" == "1" ]]; then
  echo "  Checking Stripe demo server..."
  if ! wait_for_service "Stripe Demo" "${STRIPE_HEALTH_URL}" 20 1; then
    echo "⚠️  Warning: Stripe demo server not responding"
  fi
fi

# Check background proxy if running
if [[ "${RUN_BACKGROUND_PROXY}" == "1" ]]; then
  echo "  Checking background proxy..."
  if ! wait_for_service "Background Proxy" "http://localhost:${BACKGROUND_PROXY_PORT}/background-proxy/health" 20 1; then
    echo "⚠️  Warning: Background proxy not responding"
  fi
fi

echo "✅  All services started successfully!"
echo "✅  Preview refreshed. Logs: ${LOG_FILE} (server pid ${SERVER_PID})"
if [[ "${RUN_STRIPE_DEMO_SERVER}" == "1" ]]; then
  echo "✅  Stripe demo server running. Logs: ${STRIPE_DEMO_LOG} (pid ${STRIPE_SERVER_PID})"
fi
if [[ "${RUN_BACKGROUND_PROXY}" == "1" ]]; then
  echo "✅  Background proxy running. Logs: ${BACKGROUND_PROXY_LOG} (pid ${BACKGROUND_PROXY_PID})"
fi

echo ""
echo "🌐 Preview URLs:"
echo "  Main: http://localhost:${SERVER_PORT}/preview/basic/"
if [[ "${RUN_STRIPE_DEMO_SERVER}" == "1" ]]; then
  echo "  Stripe: http://localhost:${STRIPE_DEMO_PORT}/"
fi
if [[ "${RUN_BACKGROUND_PROXY}" == "1" ]]; then
  echo "  Proxy: http://localhost:${BACKGROUND_PROXY_PORT}/"
fi

# Disable cleanup trap since everything started successfully
trap - EXIT
