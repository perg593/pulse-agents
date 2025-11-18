#!/bin/bash
# ============================================================
#  build-index.sh
#  Rebuilds 00_INDEX.md dynamically by scanning repo structure
#  Author: Pablo Rojas
#  Repository: theme-specs
#    To run:
#      chmod +x build-index.sh
#      bash build-index.sh
# ============================================================

set -e
BASE_DIR="/Users/projas/Library/Mobile Documents/com~apple~CloudDocs/Downloads/GitHub/theme-specs"
INDEX_FILE="$BASE_DIR/00_INDEX.md"
DATESTAMP=$(date +"%Y-%m-%d")

echo "🧭 Rebuilding Theme Designer index ($DATESTAMP)..."
echo ""

# Write header
cat > "$INDEX_FILE" <<EOF
# Theme Designer – Design Index
*(auto-generated on $DATESTAMP)*

---

## 📚 Foundation and Architecture (Phases 0 – 3.9)
| Phase | Title | Path |
|:------|:-------|:-----|
EOF

# Add foundation doc if it exists
if [ -f "$BASE_DIR/01_FOUNDATION_AND_ARCHITECTURE/00_THEME_GENERATOR_V3_DESIGN_UPDATED_normalized.md" ]; then
  echo "| 0 – 11.9.9 | **Theme Generator V3 Design Document (Foundation)** | [00_THEME_GENERATOR_V3_DESIGN_UPDATED_normalized.md](01_FOUNDATION_AND_ARCHITECTURE/00_THEME_GENERATOR_V3_DESIGN_UPDATED_normalized.md) |" >> "$INDEX_FILE"
fi

cat >> "$INDEX_FILE" <<EOF

---

## ✅ Completed Phases (4.x – Editor Core + Extensions)
| Phase | Title | Path |
|:------|:-------|:-----|
EOF

# Helper: list Markdown files in a folder with phase numbers
add_phase_table () {
  local folder="$1"
  local prefix="$2"
  find "$folder" -maxdepth 1 -type f -name "*.md" | sort | while read -r file; do
    local name="$(basename "$file")"
    local phase="$(echo "$name" | grep -oE '^[0-9]+\.[0-9a-z]+')"
    local title="$(grep -m1 '^# ' "$file" | sed 's/^# //')"
    [ -z "$title" ] && title="$(basename "$file")"
    echo "| $phase | ${title} | [$name](${prefix}/$name) |" >> "$INDEX_FILE"
  done
}

add_phase_table "$BASE_DIR/02_PHASE_4_EDITOR_CORE" "02_PHASE_4_EDITOR_CORE"
add_phase_table "$BASE_DIR/03_PHASE_4_EXTENSIONS" "03_PHASE_4_EXTENSIONS"

cat >> "$INDEX_FILE" <<EOF

---

## 🚧 In Progress (5.x – Pulse Markup Integration)
| Phase | Title | Path |
|:------|:-------|:-----|
EOF

add_phase_table "$BASE_DIR/04_PHASE_5_PULSE_INTEGRATION" "04_PHASE_5_PULSE_INTEGRATION"

cat >> "$INDEX_FILE" <<EOF

---

## 🧭 Planned Phases (5.x – 6.x)
| Phase | Title | Path |
|:------|:-------|:-----|
EOF

add_phase_table "$BASE_DIR/05_PHASE_6_LIVE_RUNTIME" "05_PHASE_6_LIVE_RUNTIME"

cat >> "$INDEX_FILE" <<EOF

---

## 🗂 Repository Overview
- **01_FOUNDATION_AND_ARCHITECTURE** – Historical design & architecture (Phases 0–3.9)  
- **02_PHASE_4_EDITOR_CORE** – Core editor features (4.0–4.5)  
- **03_PHASE_4_EXTENSIONS** – Extensions (4.6–4.7)  
- **04_PHASE_5_PULSE_INTEGRATION** – Pulse Markup Integration (5.0–5.0d)  
- **05_PHASE_6_LIVE_RUNTIME** – Live runtime and AI extensions (6.0–6.2)  
EOF

echo ""
echo "✅ 00_INDEX.md rebuilt successfully."
echo "You can open it in GitHub Desktop to preview changes."
