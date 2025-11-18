#!/bin/bash
# ============================================================
#  populate-spec-content.sh
#  Reads specs_full.md and overwrites all phase files with full text
#  Author: Pablo Rojas
#  Repository: theme-specs
# ============================================================

set -e

BASE_DIR="/Users/projas/Library/Mobile Documents/com~apple~CloudDocs/Downloads/GitHub/theme-specs"
PACK_FILE="$BASE_DIR/specs_full.md"
DATESTAMP=$(date +"%Y-%m-%d")
echo "📦 Populating specs from $PACK_FILE ($DATESTAMP)…"

# Verify file exists
if [ ! -f "$PACK_FILE" ]; then
  echo "❌ specs_full.md not found in $BASE_DIR"
  exit 1
fi

# Create a temp directory
TMPDIR=$(mktemp -d)

# Split specs_full.md into individual phase blocks
# Each block begins with <!-- PHASE:X.Y --> and ends with <!-- /PHASE:X.Y -->
awk '/<!-- PHASE:/{phase=$2; sub("-->","",phase); outfile=sprintf("%s/%s.txt", "'"$TMPDIR"'", phase)} 
     phase && !/<!-- PHASE:/ && !/<!-- \/PHASE:/ {print > outfile} 
     /<!-- \/PHASE:/{phase=""}' "$PACK_FILE"

# Mapping of phase to file paths
declare -A FILE_MAP=(
  ["4.0"]="$BASE_DIR/02_PHASE_4_EDITOR_CORE/4.0_Canvas_Modes.md"
  ["4.1"]="$BASE_DIR/02_PHASE_4_EDITOR_CORE/4.1_Layer_System.md"
  ["4.2"]="$BASE_DIR/02_PHASE_4_EDITOR_CORE/4.2_Template_Registry.md"
  ["4.3"]="$BASE_DIR/02_PHASE_4_EDITOR_CORE/4.3_StyleGuide_2.0.md"
  ["4.4"]="$BASE_DIR/02_PHASE_4_EDITOR_CORE/4.4_Token_Manager.md"
  ["4.5"]="$BASE_DIR/02_PHASE_4_EDITOR_CORE/4.5_Visual_Polish.md"
  ["4.6"]="$BASE_DIR/03_PHASE_4_EXTENSIONS/4.6_Undo_Redo_Reset.md"
  ["4.7"]="$BASE_DIR/03_PHASE_4_EXTENSIONS/4.7_Typography_Layout.md"
  ["5.0"]="$BASE_DIR/04_PHASE_5_PULSE_INTEGRATION/5.0_Spec_Overview.md"
  ["5.0a"]="$BASE_DIR/04_PHASE_5_PULSE_INTEGRATION/5.0a_DockedDesktop_SingleChoice.md"
)

# Loop through extracted phase files and write them into place
for PHASE in "${!FILE_MAP[@]}"; do
  SRC_FILE="$TMPDIR/$PHASE.txt"
  DEST_FILE="${FILE_MAP[$PHASE]}"
  if [ -f "$SRC_FILE" ]; then
    echo "  ➜ Updating Phase $PHASE → $(basename "$DEST_FILE")"
    # Preserve YAML header (everything until the first '---' after front matter)
    awk -v f="$SRC_FILE" '
      BEGIN {infront=0}
      /^---/ {
        print
        if (infront==0) infront=1
        else {infront=2; next}
      }
      infront<2 {print; next}
      infront==2 {exit}
    ' "$DEST_FILE" > "$DEST_FILE.tmp"

    cat "$SRC_FILE" >> "$DEST_FILE.tmp"
    mv "$DEST_FILE.tmp" "$DEST_FILE"
  else
    echo "  ⚠️  No content for Phase $PHASE in specs_full.md"
  fi
done

echo ""
echo "✅ Specs populated successfully."
echo "Next steps:"
echo "  1. Review changes in GitHub Desktop."
echo "  2. Commit with message:"
echo "     Docs: populate full specs – $DATESTAMP"
echo ""

rm -rf "$TMPDIR"
