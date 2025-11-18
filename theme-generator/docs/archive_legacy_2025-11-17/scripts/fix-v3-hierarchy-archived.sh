#!/bin/bash
# ============================================================
#  fix-v3-hierarchy.sh
#  Normalizes Markdown heading levels in theme-generator-v3-design-updated.md
#  Author: Pablo Rojas
#  Repository: theme-specs
#  This script is NON-DESTRUCTIVE — keeps all text content intact
# ============================================================

set -e
BASE_DIR="/Users/projas/Library/Mobile Documents/com~apple~CloudDocs/Downloads/GitHub/theme-specs/01_FOUNDATION_AND_ARCHITECTURE"
SRC="$BASE_DIR/theme-generator-v3-design-updated.md"
OUT="$BASE_DIR/01_FOUNDATION_AND_ARCHITECTURE/00_THEME_GENERATOR_V3_DESIGN_UPDATED_normalized.md"

if [ ! -f "$SRC" ]; then
  echo "❌  Source file not found: $SRC"
  exit 1
fi

mkdir -p "$(dirname "$OUT")"

echo "📐  Normalizing heading hierarchy in:"
echo "    $SRC"
echo ""

# Rules:
#   - Ensure exactly one H1 for the title
#   - Force major numbered sections (0-11 etc.) to H2
#   - Force sub-sections like 11.1, 11.2 → H3
#   - Sub-sub-sections (11.9.1 etc.) → H4
#   - Preserve all text lines

awk '
BEGIN {
  title_seen = 0
}
{
  line=$0
  # Detect Markdown headers
  if (match(line, /^#+[[:space:]]*[0-9]+\./)) {
    # Remove existing #s
    sub(/^#+[[:space:]]*/, "", line)
    # Get numeric prefix (e.g., 11.9.9)
    prefix=$1
    split(prefix, parts, ".")
    depth=length(parts)
    if (depth==1) {
      hashes="## "
    } else if (depth==2) {
      hashes="### "
    } else if (depth>=3) {
      hashes="#### "
    }
    print hashes line
  }
  else if (match(line, /^#[[:space:]]*[A-Za-z]/)) {
    # Keep only one top-level title
    if (title_seen==0) {
      print "# " substr($0,2)
      title_seen=1
    } else {
      sub(/^#+/, "##", $0); print
    }
  }
  else {
    print $0
  }
}' "$SRC" > "$OUT"

echo ""
echo "✅  Normalized hierarchy written to:"
echo "    $OUT"
echo ""
echo "Open it in VS Code or GitHub to confirm the heading structure looks correct."
echo "No text has been removed or rewritten."
