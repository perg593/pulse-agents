#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="${LOG_FILE:-/tmp/pulse-preview.log}"
export LOG_FILE

if [ ! -d "${ROOT_DIR}/theme-generator/node_modules" ]; then
  echo "➡️  Installing theme-generator dependencies (first run)…"
  (cd "${ROOT_DIR}/theme-generator" && npm install)
fi

if [ ! -d "${ROOT_DIR}/pi-master/node_modules" ]; then
  echo "➡️  Installing pi-master dependencies (first run)…"
  (cd "${ROOT_DIR}/pi-master" && npm install)
fi

echo "🚀  Launching Pulse demo preview (port ${SERVER_PORT:-8000})"
bash "${ROOT_DIR}/scripts/launch/services.sh"

echo "ℹ️  Preview running. Logs: ${LOG_FILE}"
echo "   Visit http://localhost:${SERVER_PORT:-8000}/preview/index.html (redirects to /preview/basic/)"
