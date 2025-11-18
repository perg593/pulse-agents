---
title: "Theme Generator V3 – Design Document"
author: "Pablo Rojas"
repository: "theme-specs"
status: "Complete"
last_updated: "2025-11-17"
---

# Theme Generator V3 – Design Document

---

## 0 Purpose

The Theme Generator V3 project defines how the Pulse Insights platform can analyze client websites, derive style tokens, and automatically generate multiple production-ready survey themes.  
This document captures every design and engineering phase leading from the prototype playground to the integrated analyzer service.

---

## 1 Core Concepts

### 1.1 Theme Projects
Each project represents a client or brand context that may contain multiple themes.  
Projects include metadata such as URL, analysis scope, and timestamps for when snapshots were generated.

### 1.2 Theme Tokens
Themes are expressed through a structured set of tokens — colors, typography, layout, and component states — that map directly to SCSS variables used in the Pulse Insights console.

### 1.3 SCSS Framework
The system compiles SCSS templates into CSS for preview.  
Each token category (palette, typography, components) is merged into a master `theme-template.scss` that mirrors Pulse’s production framework.

---

## 2 Product UX

### 2.1 Default Flow
1. User enters a target URL.  
2. The analyzer service crawls and extracts a snapshot of colors, fonts, and UI cues.  
3. The generator produces four theme variants — Brand Faithful, Light, Dark, and Minimal — and saves them inside the project.  
4. User can edit tokens, preview in desktop / mobile modes, and export SCSS.

### 2.2 Editor UX
The left sidebar hosts editable parameters grouped by Palette, Typography, Widget, CTA, and Layout.  
The right preview pane shows the live survey rendered in Canvas Edit or Interact mode.

### 2.3 Device Previews
The Canvas supports Desktop (1280 px), iPhone (375 px), and Android (360 px) viewports.  
Both previews share the same SCSS pipeline so that changes remain consistent across devices.

### 2.4 Fonts and Brand Assets
If the analyzed site references custom web fonts, the generator attempts to load them in preview.  
Otherwise it falls back to system fonts while keeping font-family metadata for later accuracy.

---

## 3 Technical Architecture

### 3.1 System Components
- Frontend (React + TypeScript + Vite)  
- Backend (Express + TypeScript) running Playwright for site analysis  
- Local storage for projects and themes  
- SCSS compilation using Dart Sass  
- Optional cloud deployment (Cloud Run / Lambda) for analyzer scaling

### 3.2 Site Snapshot Model
A `SiteSnapshot` contains:
- Detected colors (background, text, brand primary / secondary / accent)  
- Typography (body & heading fonts, base font size)  
- Page title and metadata  
- Logo region reference (optional)

Snapshots feed into the Theme Generator module, which converts them into `ThemeTokensLite` arrays.

---

## 4 Using Existing Themes

Pulse Insights already maintains hundreds of production survey themes.  
Analyzing these provides a training set for the generator’s token mappings and common color heuristics.

### 4.1 Theme Analysis
- Parse existing SCSS to extract variable patterns.  
- Identify relationships between brand colors and component roles (e.g., CTA = primary color).  
- Store results in an internal reference dataset for the analyzer.

---

## 5 Preview Strategy

### 5.1 Simulated Pulse Widget
For local development, the system uses simplified HTML that reproduces the structure of a real Pulse survey:
- Widget container  
- Question block  
- Single-choice buttons, radio buttons, sliders, and text inputs  
- CTA button and thank-you message  

### 5.2 Real Markup Parity
Later phases (5.x) will replace these simulated templates with real Pulse widget markup while preserving the same Layer definitions and data-layer selectors.

---

## 6 Accessibility

Accessibility and contrast are enforced at design time.

### 6.1 Contrast Ratios
Each theme automatically computes WCAG 2.1 contrast ratios for key color pairs:
- Text vs background  
- CTA text vs CTA background  
- Option active vs option background  

Results appear in the Style Guide section with pass/fail indicators.

### 6.2 Color-Blind Safety
Future iterations may include color-blindness simulations to guide palette adjustments.

---

## 7 Phase Plan

The project evolved through iterative implementation phases:

| Phase | Focus | Outcome |
|:------|:------|:--------|
| 0 | Theme Playground | Stand-alone React app proving live token editing |
| 1 | Theme Tokens | Formalized token structure + SCSS template |
| 2 | Theme Projects & Persistence | Local storage with multiple projects/themes |
| 3 | Analyzer & Auto-Generation | Playwright-based analyzer, 4 auto variants |
| 3.5 | UX Refinements | Context mode, dual preview, palette presets |
| 3.7 | Improved Color Extraction | Multi-page crawling + CSS variables |
| 3.9 | Brand Color Refinement | Logo sampling + weighted heuristics |
| 4 – 6 | Theme Designer Integration | Full editor, Pulse markup, runtime mode |

Each incremental phase built on the prior, culminating in the Theme Designer (Phase 4+).

---

## 10 Phase 2 – Theme Projects & Persistence

### 10.1 Project Management
Users can create, rename, delete, and switch between projects.  
Each project retains:
- Source URL  
- Number of pages analyzed  
- Set of themes (generated + custom)

### 10.2 Local Storage
All data persists in `localStorage` using JSON serialization.  
Keys include project metadata, theme tokens, and timestamps.

### 10.3 Theme Cloning
Themes can clone from any existing theme, copying token values for iterative editing.

### 10.4 Data Integrity
The system prevents deletion of the last theme in a project and restores state on reload.

---

## 11 Phase 3 – Analyzer & Auto Theme Generation

### 11.0 Overview
Phase 3 introduces automated theme generation based on live site analysis.  
It adds a local analyzer backend using Playwright and a frontend integration for one-click theme generation.

---

### 11.1 Site Analysis & Snapshot Model

#### 11.1.1 Playwright Setup
Playwright launches a headless Chromium instance and captures DOM and computed styles from target pages.  
Viewport = 1280×720, waitUntil = "domcontentloaded".

#### 11.1.2 Color Extraction Pipeline
- Read `background-color` and `color` from body and main containers.  
- Sample CTA and link colors for brand cues.  
- Store distinct RGB values with frequency weights.

#### 11.1.3 Typography Detection
Detect font-family and font-size from `body`, `h1/h2`, and button elements.  
Fallback to system fonts if not found.

---

### 11.2 Theme Generation Logic

#### 11.2.1 Theme Variants
Generator creates four variants:
1. Brand Faithful  
2. Light  
3. Dark  
4. Minimal  

#### 11.2.2 Color Transformation
Apply lighten/darken operations and contrast adjustments to derive variant palettes.

#### 11.2.3 Token Population
Map extracted values into `ThemeTokensLite` structure:
- `palette.brandPrimary` → CTA/button colors  
- `palette.background` → body background  
- `typography.body.fontFamily` → detected font

---

### 11.3 Frontend Integration
Frontend invokes `POST /api/analyze-site` with URL and `maxPages`.  
Response includes `SiteSnapshot` and generated themes.  
Themes are added to the current project and rendered immediately in Canvas.

---

### 11.4 Backend Endpoints
| Endpoint | Method | Description |
|-----------|---------|-------------|
| `/api/analyze-site` | POST | Trigger Playwright analysis and return snapshot + themes |
| `/health` | GET | Server health check |

CORS enabled for local dev and integration with frontend port 5173.

---

### 11.5 Color Palette Extraction
Playwright samples colors from:
- CSS variables (`:root --brand-*`, `--primary-*`)  
- Buttons and links (high saturation colors)  
- Background elements (body, header, footer)  

Aggregated colors are ranked by frequency and saturation to determine dominant palette.

---

### 11.6 Typography Extraction
Collect computed styles from `body`, `h1`, and CTA elements.  
Convert sizes to px, normalize weights (400–700), and store families as string stacks.  
Typography tokens are populated accordingly.

---

### 11.7 Multi-Page Crawling (Phase 3.7)
Analyzer now fetches multiple pages (home, category, product) to improve accuracy.  
Colors are aggregated across pages and weighted by occurrence.  
Failed pages are skipped gracefully.

---

### 11.8 Color Refinement (Phase 3.7 Implementation Summary)
**Features Implemented**
1. Multi-page crawling with weighted color aggregation.  
2. CSS variable extraction from `:root` and header containers.  
3. High/low saturation filtering to identify brand vs neutral tones.  
4. WCAG contrast validation (4.5:1 minimum).  
5. Graceful error handling and fallback to defaults.

**Result:** Significantly more accurate palette detection for complex sites.

---

### 11.9 Brand Color Refinement (Phase 3.9)

#### 11.9.1 Logo Sampling
Capture top 200–300 px region of screenshot using `sharp`.  
Quantize pixels (16 levels per channel) and select dominant saturated color as brand primary.

#### 11.9.2 CSS Variable Expansion
Scan `:root`, `header`, `nav`, and `.theme` containers for brand-related CSS variables.  
Filter variables like `--brand-*`, `--primary-*`, `--color-*`.

#### 11.9.3 CTA / Nav Weighting
Assign frequency weights (CTA 1.5×, active nav 1.5×, regular buttons 1×).  
Aggregate colors with weighted scores to determine primary and secondary brand hues.

#### 11.9.4 Stability Thresholds
Ensure `brandSecondary` differs by ≥ 30° hue from primary.  
Validate contrast and generate surfaces if missing.

#### 11.9.5 Accessibility Pass
Re-run contrast ratios after brand refinement and adjust lightness to maintain AA compliance.

#### 11.9.6 Palette Normalization
Standardize palette fields (background, surface, text primary/secondary, brand, accent).  
Fallback to neutrals if any channel is undefined.

#### 11.9.7 Error Handling
Catch and log `sharp` image processing errors.  
Fallback to CSS variable colors if logo sampling fails.

#### 11.9.8 Performance Considerations
Logo sampling adds 100–200 ms overhead per analysis.  
CSS variable scanning has negligible cost.  
All operations degrade gracefully on failure.

#### 11.9.9 Summary (Phase 3.9 Implementation Summary)
**Features Implemented**
1. Logo color sampling via `screenshot region` and `sharp`.  
2. Expanded CSS variable extraction (header + theme containers).  
3. Weighted CTA/nav color prioritization.  
4. Hue differentiation and contrast threshold enforcement.  
5. Optional surface generation and safe fallbacks.  

**Impact:** Analyzer achieves stable brand palette generation with minimal manual correction.

---

# End of Document
