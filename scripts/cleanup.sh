#!/usr/bin/env bash

# Cleanup script for Pulse Widgets
# Removes log files, temporary files, and optionally build artifacts

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

CLEAN_LOGS="${CLEAN_LOGS:-1}"
CLEAN_TEMP="${CLEAN_TEMP:-1}"
CLEAN_BUILD="${CLEAN_BUILD:-0}"
CLEAN_NODE_MODULES="${CLEAN_NODE_MODULES:-0}"
STOP_SERVICES="${STOP_SERVICES:-1}"

echo "🧹 Pulse Widgets Cleanup"
echo "========================"
echo ""

# Stop running services
if [[ "${STOP_SERVICES}" == "1" ]]; then
  echo "🛑 Stopping services..."
  
  if pkill -f "python3 -m http.server" >/dev/null 2>&1; then
    echo "  ✅ Stopped preview server"
  fi
  
  if pkill -f "background-proxy-server.js" >/dev/null 2>&1; then
    echo "  ✅ Stopped background proxy"
  fi
  
  if pkill -f "stripe-demo-server.js" >/dev/null 2>&1; then
    echo "  ✅ Stopped Stripe demo server"
  fi
  
  sleep 2
  echo ""
fi

# Clean log files
if [[ "${CLEAN_LOGS}" == "1" ]]; then
  echo "📋 Cleaning log files..."
  
  LOG_FILES=(
    "/tmp/pulse-preview.log"
    "/tmp/pulse-preview-basic.log"
    "/tmp/pulse-background-proxy.log"
    "/tmp/pulse-stripe-demo.log"
  )
  
  REMOVED=0
  for log_file in "${LOG_FILES[@]}"; do
    if [[ -f "${log_file}" ]]; then
      rm -f "${log_file}"
      echo "  ✅ Removed ${log_file}"
      REMOVED=$((REMOVED + 1))
    fi
  done
  
  # Also clean any pulse-*.log files
  if ls /tmp/pulse-*.log >/dev/null 2>&1; then
    rm -f /tmp/pulse-*.log
    echo "  ✅ Removed additional pulse log files"
    REMOVED=$((REMOVED + 1))
  fi
  
  if [[ ${REMOVED} -eq 0 ]]; then
    echo "  ℹ️  No log files found"
  fi
  echo ""
fi

# Clean temporary files
if [[ "${CLEAN_TEMP}" == "1" ]]; then
  echo "🗑️  Cleaning temporary files..."
  
  TEMP_DIRS=(
    "tmp"
    "temp"
    ".tmp"
  )
  
  REMOVED=0
  for temp_dir in "${TEMP_DIRS[@]}"; do
    if [[ -d "${temp_dir}" ]]; then
      rm -rf "${temp_dir}"
      echo "  ✅ Removed ${temp_dir}/"
      REMOVED=$((REMOVED + 1))
    fi
  done
  
  # Remove OS files
  if find . -name ".DS_Store" -type f | head -1 | grep -q .; then
    find . -name ".DS_Store" -delete
    echo "  ✅ Removed .DS_Store files"
    REMOVED=$((REMOVED + 1))
  fi
  
  if find . -name "Thumbs.db" -type f | head -1 | grep -q .; then
    find . -name "Thumbs.db" -delete
    echo "  ✅ Removed Thumbs.db files"
    REMOVED=$((REMOVED + 1))
  fi
  
  if [[ ${REMOVED} -eq 0 ]]; then
    echo "  ℹ️  No temporary files found"
  fi
  echo ""
fi

# Clean build artifacts
if [[ "${CLEAN_BUILD}" == "1" ]]; then
  echo "🏗️  Cleaning build artifacts..."
  
  BUILD_DIRS=(
    "theme-generator/v1/output"
    "theme-generator/v2/output"
    "preview/dist"
  )
  
  REMOVED=0
  for build_dir in "${BUILD_DIRS[@]}"; do
    if [[ -d "${build_dir}" ]]; then
      rm -rf "${build_dir}"
      echo "  ✅ Removed ${build_dir}/"
      REMOVED=$((REMOVED + 1))
    fi
  done
  
  if [[ ${REMOVED} -eq 0 ]]; then
    echo "  ℹ️  No build artifacts found"
  fi
  echo ""
fi

# Clean node_modules (optional, aggressive)
if [[ "${CLEAN_NODE_MODULES}" == "1" ]]; then
  echo "📦 Cleaning node_modules (will require npm install)..."
  
  NODE_MODULES_DIRS=(
    "node_modules"
    "theme-generator/v1/node_modules"
    "theme-generator/v2/node_modules"
    "pi-master/node_modules"
  )
  
  REMOVED=0
  for node_modules_dir in "${NODE_MODULES_DIRS[@]}"; do
    if [[ -d "${node_modules_dir}" ]]; then
      rm -rf "${node_modules_dir}"
      echo "  ✅ Removed ${node_modules_dir}/"
      REMOVED=$((REMOVED + 1))
    fi
  done
  
  if [[ ${REMOVED} -eq 0 ]]; then
    echo "  ℹ️  No node_modules found"
  else
    echo "  ⚠️  Run 'npm install' to restore dependencies"
  fi
  echo ""
fi

echo "✅ Cleanup complete!"
echo ""
echo "To restart services:"
echo "  npm start"
echo ""
echo "To reinstall dependencies:"
echo "  npm install"

