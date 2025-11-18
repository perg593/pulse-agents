#!/bin/bash
# ============================================================
#  build-theme-specs.sh  —  Theme Designer Spec Repository Builder
#  Author: Pablo Rojas
#  Repository: theme-specs
#  Behavior: OVERWRITES existing files on each run
# ============================================================

set -e

echo "🏗️  Building Theme Designer specs (Phases 0 – 5.0a)…"

BASE_DIR="$(pwd)"

# ---------- Utility function ----------
write_file () {
  local path="$1"
  local content="$2"
  mkdir -p "$(dirname "$path")"
  echo "$content" > "$path"
  echo "  ✔︎ Wrote $path"
}

# ============================================================
# 02_PHASE_4_EDITOR_CORE
# ============================================================

# ---------- 4.0 Canvas Modes ----------
write_file "$BASE_DIR/02_PHASE_4_EDITOR_CORE/4.0_Canvas_Modes.md" \
'---
title: "Phase 4.0 – Canvas Modes & Core Canvas Shell"
phase: 4.0
status: "Complete"
author: "Pablo Rojas"
repository: "theme-specs"
last_updated: "2025-11-17"
---
# Phase 4.0 – Canvas Modes & Core Canvas Shell

## Goals
Introduce Edit / Interact modes and a structured Canvas shell for the Theme Designer.
…(full Phase 4.0 spec text from our design doc continues here)…
'

# ---------- 4.1 Layer System ----------
write_file "$BASE_DIR/02_PHASE_4_EDITOR_CORE/4.1_Layer_System.md" \
'---
title: "Phase 4.1 – Layer System & Layer Inspector"
phase: 4.1
status: "Complete"
author: "Pablo Rojas"
repository: "theme-specs"
last_updated: "2025-11-17"
---
# Phase 4.1 – Layer System & Layer Inspector

## Goals
Implement semantic layers, hover/select behavior, and a Layer Inspector connected to theme tokens.
…(insert full Phase 4.1 spec text)…
'

# ---------- 4.2 Template Registry ----------
write_file "$BASE_DIR/02_PHASE_4_EDITOR_CORE/4.2_Template_Registry.md" \
'---
title: "Phase 4.2 – Template Registry & Advanced Configuration"
phase: 4.2
status: "Complete"
author: "Pablo Rojas"
repository: "theme-specs"
last_updated: "2025-11-17"
---
# Phase 4.2 – Template Registry & Advanced Configuration

## Goals
Create a data-driven registry for preview templates and a UI for managing template selection.
…(insert full Phase 4.2 spec text)…
'

# ---------- create placeholder subfolder ----------
mkdir -p "$BASE_DIR/02_PHASE_4_EDITOR_CORE/4.5_Screenshots"

echo "✅  Part 1 complete: 02_PHASE_4_EDITOR_CORE created."
echo "👉  Next: paste Part 2 (Phases 4.3 – 4.7) below this section."






# ============================================================
# 03_PHASE_4_EXTENSIONS (Phases 4.3 – 4.7)
# ============================================================

# ---------- 4.3 Style Guide 2.0 ----------
write_file "$BASE_DIR/02_PHASE_4_EDITOR_CORE/4.3_StyleGuide_2.0.md" \
'---
title: "Phase 4.3 – Style Guide 2.0"
phase: 4.3
status: "Complete"
author: "Pablo Rojas"
repository: "theme-specs"
last_updated: "2025-11-17"
---
# Phase 4.3 – Style Guide 2.0

## Goals
Convert the Style Guide tab into a complete, client-ready design-system summary.
…(full Phase 4.3 spec text)…
'

# ---------- 4.4 Token Manager ----------
write_file "$BASE_DIR/02_PHASE_4_EDITOR_CORE/4.4_Token_Manager.md" \
'---
title: "Phase 4.4 – Token Manager & Unified Theme Update System"
phase: 4.4
status: "Complete"
author: "Pablo Rojas"
repository: "theme-specs"
last_updated: "2025-11-17"
---
# Phase 4.4 – Token Manager & Unified Theme Update System

## Goals
Create a centralized Token Manager API to unify all theme reads/writes and enable provenance logging.
…(full Phase 4.4 spec text)…
'

# ---------- 4.5 Visual Polish ----------
write_file "$BASE_DIR/02_PHASE_4_EDITOR_CORE/4.5_Visual_Polish.md" \
'---
title: "Phase 4.5 – Visual Polish & UI System"
phase: 4.5
status: "Complete"
author: "Pablo Rojas"
repository: "theme-specs"
last_updated: "2025-11-17"
---
# Phase 4.5 – Visual Polish & UI System

## Goals
Apply Figma-level visual consistency: colors, typography, layout, and micro-interactions.
…(full Phase 4.5 spec text)…
'

# ---------- 4.5 Implementation Summary ----------
write_file "$BASE_DIR/02_PHASE_4_EDITOR_CORE/4.5_Implementation_Summary.md" \
'---
title: "Phase 4.5 Implementation Summary"
phase: 4.5
status: "Complete"
author: "Pablo Rojas"
repository: "theme-specs"
last_updated: "2025-11-17"
---
# Phase 4.5 Implementation Summary
…(implementation summary text)…
'

# ---------- 4.6 Undo / Redo + Reset ----------
write_file "$BASE_DIR/03_PHASE_4_EXTENSIONS/4.6_Undo_Redo_Reset.md" \
'---
title: "Phase 4.6 – Undo / Redo & Reset Tools"
phase: 4.6
status: "Complete"
author: "Pablo Rojas"
repository: "theme-specs"
last_updated: "2025-11-17"
---
# Phase 4.6 – Undo / Redo & Reset Tools
…(full Phase 4.6 spec text)…
'

# ---------- 4.7 Typography & Layout Tokens ----------
write_file "$BASE_DIR/03_PHASE_4_EXTENSIONS/4.7_Typography_Layout.md" \
'---
title: "Phase 4.7 – Typography & Layout Tokens"
phase: 4.7
status: "Complete"
author: "Pablo Rojas"
repository: "theme-specs"
last_updated: "2025-11-17"
---
# Phase 4.7 – Typography & Layout Tokens
…(full Phase 4.7 spec text)…
'

# ---------- 4.7 Implementation Summary ----------
write_file "$BASE_DIR/03_PHASE_4_EXTENSIONS/4.7_Implementation_Summary.md" \
'---
title: "Phase 4.7 Implementation Summary"
phase: 4.7
status: "Complete"
author: "Pablo Rojas"
repository: "theme-specs"
last_updated: "2025-11-17"
---
# Phase 4.7 Implementation Summary
…(implementation summary text)…
'

# ---------- create placeholder subfolders ----------
mkdir -p "$BASE_DIR/03_PHASE_4_EXTENSIONS/4.7_Examples"
mkdir -p "$BASE_DIR/04_PHASE_5_PULSE_INTEGRATION/5.0_Screenshots"

echo "✅  Part 2 complete: Phases 4.3 → 4.7 written."
echo "👉  Next: paste Part 3 (Pulse Integration + index/readme/memory card) below this section."








# ============================================================
# 04_PHASE_5_PULSE_INTEGRATION  (Phases 5.0 – 5.0a)
# ============================================================

# ---------- 5.0 Spec Overview ----------
write_file "$BASE_DIR/04_PHASE_5_PULSE_INTEGRATION/5.0_Spec_Overview.md" \
'---
title: "Phase 5.0 – Pulse Markup Integration (Static Templates)"
phase: 5.0
status: "In Progress"
author: "Pablo Rojas"
repository: "theme-specs"
last_updated: "2025-11-17"
---
# Phase 5.0 – Pulse Markup Integration (Static Templates)

## Goals
Introduce real Pulse widget markup into the Theme Designer as selectable templates inside the registry.
…(full Phase 5.0 spec text)…
'

# ---------- 5.0a Docked Desktop Single Choice + Thank You ----------
write_file "$BASE_DIR/04_PHASE_5_PULSE_INTEGRATION/5.0a_DockedDesktop_SingleChoice.md" \
'---
title: "Phase 5.0a – Docked Desktop Single Choice (Standard Buttons) + Thank You"
phase: 5.0a
status: "Complete"
author: "Pablo Rojas"
repository: "theme-specs"
last_updated: "2025-11-17"
---
# Phase 5.0a – Docked Desktop Single Choice (Standard Buttons) + Thank You

## Goals
Add the first Pulse-markup templates for docked desktop widgets – single-choice (standard buttons) and thank-you state.
…(full Phase 5.0a spec text)…
'

# ---------- 5.0a Cursor Prompt ----------
write_file "$BASE_DIR/04_PHASE_5_PULSE_INTEGRATION/5.0a_CursorPrompt.txt" \
'Cursor Prompt for Phase 5.0a – Docked Desktop Single Choice (Standard Buttons) + Thank You
…(full Cursor prompt text)…
'

# ---------- 5.0a Implementation Summary ----------
write_file "$BASE_DIR/04_PHASE_5_PULSE_INTEGRATION/5.0a_Implementation_Summary.md" \
'---
title: "Phase 5.0a Implementation Summary"
phase: 5.0a
status: "Complete"
author: "Pablo Rojas"
repository: "theme-specs"
last_updated: "2025-11-17"
---
# Phase 5.0a Implementation Summary
…(implementation summary text)…
'

# ---------- placeholder future files ----------
touch "$BASE_DIR/04_PHASE_5_PULSE_INTEGRATION/5.0b_FreeText.md"
touch "$BASE_DIR/04_PHASE_5_PULSE_INTEGRATION/5.0c_MultiChoice_Radio_Dropdown.md"
touch "$BASE_DIR/04_PHASE_5_PULSE_INTEGRATION/5.0d_CustomContent.md"

# ============================================================
# 05_PHASE_6_LIVE_RUNTIME  (placeholders)
# ============================================================
mkdir -p "$BASE_DIR/05_PHASE_6_LIVE_RUNTIME"
touch "$BASE_DIR/05_PHASE_6_LIVE_RUNTIME/6.0_Snippet_Integration.md"
touch "$BASE_DIR/05_PHASE_6_LIVE_RUNTIME/6.1_Runtime_Preview_Mode.md"
touch "$BASE_DIR/05_PHASE_6_LIVE_RUNTIME/6.2_AI_Assistance.md"

# ============================================================
# Root files (README, INDEX, Memory Card)
# ============================================================

# ---------- README ----------
write_file "$BASE_DIR/README.md" \
'# Theme Designer Specifications

This repository tracks all design documents, phase specs, Cursor prompts, and implementation summaries for the Pulse Insights Theme Designer project.

Each folder represents a logical phase of development (4.x Editor Core, 5.x Pulse Integration, 6.x Runtime).

If you’re continuing work in ChatGPT or Cursor:
1. Copy the phase spec you’re implementing.  
2. Paste it into your Cursor prompt.  
3. Commit the resulting implementation summary here when done.
'

# ---------- INDEX ----------
write_file "$BASE_DIR/00_INDEX.md" \
'# Theme Designer – Design Index

## ✅ Completed Phases
- [4.0 – Canvas Modes](02_PHASE_4_EDITOR_CORE/4.0_Canvas_Modes.md)  
- [4.1 – Layer System](02_PHASE_4_EDITOR_CORE/4.1_Layer_System.md)  
- [4.2 – Template Registry](02_PHASE_4_EDITOR_CORE/4.2_Template_Registry.md)  
- [4.3 – Style Guide 2.0](02_PHASE_4_EDITOR_CORE/4.3_StyleGuide_2.0.md)  
- [4.4 – Token Manager](02_PHASE_4_EDITOR_CORE/4.4_Token_Manager.md)  
- [4.5 – Visual Polish](02_PHASE_4_EDITOR_CORE/4.5_Visual_Polish.md)  
- [4.6 – Undo / Redo + Reset](03_PHASE_4_EXTENSIONS/4.6_Undo_Redo_Reset.md)  
- [4.7 – Typography & Layout Tokens](03_PHASE_4_EXTENSIONS/4.7_Typography_Layout.md)

## 🚧 In Progress
- [5.0 Overview](04_PHASE_5_PULSE_INTEGRATION/5.0_Spec_Overview.md)  
- [5.0a – Docked Desktop Single Choice + Thank You](04_PHASE_5_PULSE_INTEGRATION/5.0a_DockedDesktop_SingleChoice.md)

## 🧭 Planned
- [5.0b – Free Text Templates](04_PHASE_5_PULSE_INTEGRATION/5.0b_FreeText.md)  
- [5.0c – Multi-Choice / Radio / Dropdown](04_PHASE_5_PULSE_INTEGRATION/5.0c_MultiChoice_Radio_Dropdown.md)  
- [5.0d – Custom Content](04_PHASE_5_PULSE_INTEGRATION/5.0d_CustomContent.md)  
- [6.0 – Live Snippet Integration](05_PHASE_6_LIVE_RUNTIME/6.0_Snippet_Integration.md)  
- [6.1 – Runtime Preview Mode](05_PHASE_6_LIVE_RUNTIME/6.1_Runtime_Preview_Mode.md)  
- [6.2 – AI Assistance](05_PHASE_6_LIVE_RUNTIME/6.2_AI_Assistance.md)
'

# ---------- Memory Card (summary status) ----------
write_file "$BASE_DIR/theme-designer-summary.txt" \
'Theme Designer – Snapshot Summary

Latest completed: Phase 5.0a – Docked Desktop Single Choice + Thank You  
Next in queue: Phase 5.0b – Free Text  
Open topics: Finalize mobile layer mappings, confirm analyzer font detection  
'

echo "✅ Build complete! All folders and Markdown files created in $BASE_DIR"
echo "You can now open GitHub Desktop → Commit → Push to publish theme-specs."
