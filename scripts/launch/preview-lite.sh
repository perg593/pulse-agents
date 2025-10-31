#!/usr/bin/env bash

# Lightweight launcher for the Pulse basic preview.
# Skips theme generation and long-running build steps, but keeps
# the background proxy and static preview server online.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load port configuration (falls back to sensible defaults)
SERVER_PORT="${SERVER_PORT:-8000}"
BACKGROUND_PROXY_PORT="${BACKGROUND_PROXY_PORT:-3100}"

if [[ -f "${ROOT_DIR}/config/ports.js" ]]; then
  PORTS=$(
    node -e "
      try {
        const config = require('${ROOT_DIR}/config/ports.js');
        const ports = config.getPorts('development');
        console.log('SERVER_PORT=' + ports.SERVER_PORT);
        console.log('BACKGROUND_PROXY_PORT=' + ports.BACKGROUND_PROXY_PORT);
      } catch (error) {
        console.error(error);
        process.exit(1);
      }
    "
  )
  eval "${PORTS}"
fi

LOG_FILE="${LOG_FILE:-/tmp/pulse-preview-basic.log}"
BACKGROUND_PROXY_LOG="${BACKGROUND_PROXY_LOG:-/tmp/pulse-preview-proxy.log}"

SERVER_PID=0
BACKGROUND_PROXY_PID=0

cleanup() {
  echo "🧹 Cleaning up preview processes..."
  if [[ ${SERVER_PID} -ne 0 ]] && kill -0 "${SERVER_PID}" >/dev/null 2>&1; then
    echo "  Stopping preview server (PID ${SERVER_PID})"
    kill "${SERVER_PID}" >/dev/null 2>&1 || true
  fi
  if [[ ${BACKGROUND_PROXY_PID} -ne 0 ]] && kill -0 "${BACKGROUND_PROXY_PID}" >/dev/null 2>&1; then
    echo "  Stopping background proxy (PID ${BACKGROUND_PROXY_PID})"
    kill "${BACKGROUND_PROXY_PID}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

ensure_command() {
  local cmd="$1"
  local hint="${2:-Install ${cmd}}"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "❌ Missing required command: ${cmd}"
    echo "   ${hint}"
    exit 1
  fi
}

ensure_command python3 "Install Python 3 from https://python.org/"
ensure_command node "Install Node.js 16+ from https://nodejs.org/"
ensure_command npm "Install npm (ships with Node.js)"
ensure_command curl "Install curl (required for health checks)"
lsof >/dev/null 2>&1 || { echo "❌ Missing required command: lsof"; exit 1; }

ensure_node_modules() {
  local directory="$1"
  local label="$2"
  if [[ ! -d "${directory}/node_modules" ]]; then
    echo "➡️  Installing ${label} dependencies…"
    (cd "${directory}" && npm install)
  fi
}

ensure_node_modules "${ROOT_DIR}" "root"

wait_for_service() {
  local name="$1"
  local url="$2"
  local attempts="${3:-30}"
  local delay="${4:-1}"
  local try=1
  while [[ ${try} -le ${attempts} ]]; do
    if curl --silent --fail --max-time 2 "${url}" >/dev/null 2>&1; then
      echo "✅ ${name} ready (${url})"
      return 0
    fi
    echo "⏳ Waiting for ${name}… (${try}/${attempts})"
    sleep "${delay}"
    try=$((try + 1))
  done
  echo "❌ ${name} did not become ready (${url})"
  return 1
}

stop_if_listening() {
  local port="$1"
  local label="$2"
  if lsof -tiTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "↻  Stopping existing ${label} on port ${port}"
    lsof -tiTCP:"${port}" -sTCP:LISTEN | xargs kill >/dev/null 2>&1 || true
    sleep 2
  fi
}

stop_if_listening "${BACKGROUND_PROXY_PORT}" "background proxy"
echo "🚀 Starting background proxy on http://localhost:${BACKGROUND_PROXY_PORT}/"
nohup env BACKGROUND_PROXY_PORT="${BACKGROUND_PROXY_PORT}" \
  node "${ROOT_DIR}/preview/scripts/background-proxy-server.js" \
  >"${BACKGROUND_PROXY_LOG}" 2>&1 &
BACKGROUND_PROXY_PID=$!

wait_for_service "Background proxy" "http://localhost:${BACKGROUND_PROXY_PORT}/background-proxy/health" 20 1

stop_if_listening "${SERVER_PORT}" "preview server"
echo "🚀 Starting preview server on http://localhost:${SERVER_PORT}/"
PREV_DIR="$(pwd)"
cd "${ROOT_DIR}"
nohup python3 -m http.server "${SERVER_PORT}" >"${LOG_FILE}" 2>&1 &
SERVER_PID=$!
cd "${PREV_DIR}"

wait_for_service "Preview server" "http://localhost:${SERVER_PORT}/preview/index.html" 20 1

trap - EXIT

echo ""
echo "✅ Preview ready!"
echo "  Main preview:  http://localhost:${SERVER_PORT}/preview/index.html"
echo "  Basic preview: http://localhost:${SERVER_PORT}/index.html"
echo "  Proxy health:  http://localhost:${BACKGROUND_PROXY_PORT}/background-proxy/health"
echo ""
echo "Logs:"
echo "  Preview server → ${LOG_FILE}"
echo "  Proxy server   → ${BACKGROUND_PROXY_LOG}"
echo ""
echo "To stop both services:"
echo "  kill ${SERVER_PID} ${BACKGROUND_PROXY_PID}"
