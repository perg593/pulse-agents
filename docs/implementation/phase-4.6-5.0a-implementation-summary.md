# Phase 4.6–5.0a Implementation Summary

**Purpose:** This document summarizes the implementation work completed for Phases 4.6, 4.7, 5.0, and 5.0a of the Theme Generator v3 project. It serves as a reference for future development and onboarding.

**Reference Design Document:** `docs/01_FOUNDATION_AND_ARCHITECTURE/00_THEME_GENERATOR_V3_DESIGN_CANONICAL.md`

**Date Range:** Implementation completed in single session covering multiple phases.

---

## Table of Contents

1. [Phase 4.6 – Undo/Redo & Reset Tools](#phase-46--undoredo--reset-tools)
2. [Phase 4.7 – Typography & Layout Tokens](#phase-47--typography--layout-tokens)
3. [Phase 5.0 – Pulse Markup Integration (Static Templates)](#phase-50--pulse-markup-integration-static-templates)
4. [Phase 5.0a – Docked Desktop Single-Choice (Standard Buttons) + Thank You](#phase-50a--docked-desktop-single-choice-standard-buttons--thank-you)
5. [Technical Patterns & Conventions](#technical-patterns--conventions)
6. [File Structure Reference](#file-structure-reference)

---

## Phase 4.6 – Undo/Redo & Reset Tools

### Overview

Implemented comprehensive undo/redo functionality and reset mechanisms for theme tokens, building on the Token Manager change log system established in Phase 4.4.

**Design Reference:** Section 12.6 of canonical design document

### Key Features Implemented

#### 1. Baseline Theme Snapshot System

- **Location:** `src/stores/themeStore.ts`
- **Implementation:**
  - Extended `ThemeProject` interface to include `baselineThemes?: Record<string, ThemeTokensLite>`
  - Added `getBaselineTheme()` and `setBaselineTheme()` methods to ThemeStore
  - Baseline themes are deep copies created when themes are first generated or created
  - Migration logic ensures existing themes get baselines on load

#### 2. Undo/Redo Stacks

- **Location:** `src/theme/tokenManager.ts`
- **Implementation:**
  - Added `undoStack: TokenChange[]` and `redoStack: TokenChange[]` arrays
  - Extended `TokenSource` type to include: `'undo' | 'redo' | 'reset-token' | 'reset-group' | 'reset-theme'`
  - Modified `updateToken()` to:
    - Push changes to `undoStack` when source is NOT undo/redo/reset
    - Clear `redoStack` on new changes
    - Limit stack size to 100 entries
  - Implemented `undoTokenChange()` and `redoTokenChange()` functions
  - Undo/redo operations do not create new change log entries (prevent infinite loops)

#### 3. Reset Controls

**Reset Token:**
- Added reset buttons (↺) next to editable fields in Theme Editor and Layer Inspector
- Calls `resetTokenToBaseline(tokenPath)` which looks up baseline value and applies via Token Manager

**Reset Group:**
- Added "Reset Group" buttons in Theme Editor collapsible sections
- Groups supported: Palette, Typography, Component, Layout
- Uses `resetTokenGroup(tokenPaths[])` to reset all tokens in a group

**Reset Entire Theme:**
- Added "Reset Theme to Baseline" button in Theme Editor header
- Two-click confirmation pattern (button changes to "Confirm Reset" on first click)
- Uses `resetThemeToBaseline()` to iterate all token paths and apply baseline values

#### 4. UI Components

- **UndoRedoButtons Component:** `src/components/UndoRedoButtons.tsx`
  - Displays Undo (←) and Redo (→) buttons in Canvas header
  - Disabled when respective stacks are empty
  - Tooltips: "Undo last change" / "Redo last undone change"

- **Reset Button Integration:**
  - Added to `ColorInput` component (`src/components/ColorInput.tsx`)
  - Added to `LayerInspector` component (`src/components/LayerInspector.tsx`)
  - Added to `CollapsibleSection` component (`src/components/CollapsibleSection.tsx`)

#### 5. State Management

- Undo/redo stacks cleared when:
  - Active theme changes (`setActiveTheme`)
  - New themes are generated (`addGeneratedThemes`)
- Ensures clean state transitions between themes

### Files Modified

- `src/theme/tokenManager.ts` - Core undo/redo logic
- `src/types/theme.ts` - Extended ThemeProject interface
- `src/stores/themeStore.ts` - Baseline theme management
- `src/components/UndoRedoButtons.tsx` - New component
- `src/components/DualPreview.tsx` - Added UndoRedoButtons to header
- `src/components/ThemeEditor.tsx` - Reset controls integration
- `src/components/LayerInspector.tsx` - Reset button for tokens
- `src/components/ColorInput.tsx` - Reset button prop support
- `src/components/CollapsibleSection.tsx` - Actions prop for reset buttons
- `src/App.css` - Styles for reset buttons and layout

### Key Technical Decisions

1. **Stack Size Limit:** 100 entries to prevent memory issues
2. **Source Tracking:** Undo/redo/reset operations tagged with specific sources to prevent recursive logging
3. **Deep Copy Strategy:** Uses `JSON.parse(JSON.stringify())` for baseline creation (simple, works for current schema)
4. **Confirmation Pattern:** Two-click confirmation for destructive "Reset Theme" action

---

## Phase 4.7 – Typography & Layout Tokens

### Overview

Extended theme expressiveness by elevating typography and layout to first-class theme tokens, exposing them in the UI and ensuring they drive Canvas, Layer Inspector, and Style Guide.

**Design Reference:** Section 12.7 of canonical design document

### Key Features Implemented

#### 1. Typography Token Structure

- **Location:** `src/types/theme.ts`
- **Structure:**
  ```typescript
  typography: {
    heading?: {
      fontFamily: string;
      fontSize: number;
      fontWeight: number;
      lineHeight?: number;
    };
    body?: {
      fontFamily: string;
      fontSize: number;
      fontWeight: number;
      lineHeight?: number;
    };
    button?: {
      fontFamily: string;
      fontSize: number;
      fontWeight: number;
      letterSpacing?: number;
      lineHeight?: number;
    };
  }
  ```
- All fields are optional to maintain backward compatibility

#### 2. Layout Token Structure

- **Location:** `src/types/theme.ts`
- **Structure:**
  ```typescript
  layout: {
    borderRadiusTokens?: {
      widget: number;
      button: number;
      option: number;
      input: number;
    };
    spacing?: {
      optionGap: number;
      widgetPadding: number;
      sectionSpacing: number;
    };
    maxWidth?: {
      widget: number;
    };
  }
  ```

#### 3. Typography Editor UI

- **Location:** `src/components/ThemeEditor.tsx`
- **Features:**
  - Typography section with controls for Heading, Body, and Button roles
  - Each role has:
    - Font family (text input)
    - Font size (number input, px)
    - Font weight (dropdown: 400, 500, 600, 700)
    - Line height (number input)
    - Letter spacing (button only)
  - Token paths displayed as `<small>` tags below each control
  - Reset buttons for each field

#### 4. Layout Editor UI

- **Location:** `src/components/ThemeEditor.tsx`
- **Features:**
  - Layout section with controls for:
    - Border radius (widget, button, option, input)
    - Spacing (optionGap, widgetPadding, sectionSpacing)
    - Max width (widget)
  - All controls wired to Token Manager
  - Token paths displayed for each field

#### 5. SCSS Integration

- **Location:** `src/theme/compileTheme.ts`
- **Implementation:**
  - Updated `generateSCSSVariables()` to use new structured tokens with fallbacks
  - New SCSS variables:
    - `$pi-font-heading`, `$pi-font-size-heading`, `$pi-font-weight-heading`
    - `$pi-font-body`, `$pi-font-size-body`, `$pi-font-weight-body`
    - `$pi-font-button`, `$pi-font-size-button`, `$pi-font-weight-button`
    - `$pi-line-height-heading`, `$pi-line-height-body`, `$pi-line-height-button`
    - `$pi-letter-spacing-button`
    - `$pi-border-radius`, `$pi-border-radius-button`, `$pi-border-radius-option`, `$pi-border-radius-input`
    - `$pi-spacing-md`, `$pi-widget-padding`, `$pi-section-spacing`
    - `$pi-widget-max-width`
  - Updated `SCSS_TEMPLATE` to apply these variables to relevant elements

#### 6. Layer Inspector Integration

- **Location:** `src/components/LayerInspector.tsx`
- **Features:**
  - Detects text-related layers (`isTextLayer`) and container layers (`isContainerLayer`)
  - Displays typography information for text layers:
    - Sample text with applied typography
    - Metadata (font size, family, weight)
    - Token paths
    - "Jump to Typography Editor" button
  - Displays layout information for container layers:
    - Border radius, padding, spacing values
    - Token paths
    - "Jump to Layout Editor" button
  - Jump buttons scroll Theme Editor to relevant section and expand if collapsed

#### 7. Style Guide Integration

- **Location:** `src/components/StyleGuide.tsx`
- **Features:**
  - Typography section uses new structured tokens for samples
  - Shows metadata: "16px / Inter / 600" format
  - Displays token paths under each role
  - Components section implicitly reflects layout changes through compiled CSS

#### 8. Analyzer Integration

- **Location:** `server/generateThemes.ts`
- **Implementation:**
  - Created `createTypographyStructure()` helper function
  - Created `createLayoutStructure()` helper function
  - Updated theme generation to use these helpers for all variants
  - Provides fallbacks based on SiteSnapshot data

#### 9. Token Manager Metadata

- **Location:** `src/theme/tokenManager.ts`
- **Implementation:**
  - Updated `TOKEN_META` array to include all new typography and layout token paths
  - Clear distinction between legacy and new structured tokens

### Files Modified

- `src/types/theme.ts` - Extended typography and layout interfaces
- `src/stores/themeStore.ts` - Default theme initialization
- `src/components/ThemeEditor.tsx` - Typography and Layout editor sections
- `src/components/LayerInspector.tsx` - Typography/Layout display and jump buttons
- `src/components/StyleGuide.tsx` - Typography section updates
- `src/theme/compileTheme.ts` - SCSS variable generation and template updates
- `src/theme/tokenManager.ts` - Token metadata updates
- `server/generateThemes.ts` - Theme generation helpers
- `src/App.css` - Styles for new editor sections

### Key Technical Decisions

1. **Backward Compatibility:** All new fields are optional, existing themes continue to work
2. **Fallback Strategy:** SCSS compilation prioritizes new structured tokens, falls back to legacy fields
3. **Token Path Display:** Shows token paths in UI for transparency and debugging
4. **Jump Navigation:** Layer Inspector can navigate to Theme Editor sections for related tokens

---

## Phase 5.0 – Pulse Markup Integration (Static Templates)

### Overview

Introduced real Pulse widget markup into the Theme Designer as a new set of preview templates, while preserving the existing Canvas/Layers/Style Guide/Token Manager architecture.

**Design Reference:** Section 13.0 of canonical design document

### Key Features Implemented

#### 1. Pulse Template Renderers

- **Location:** `src/preview/pulseTemplates.ts`
- **Implementation:**
  - Created HTML string generators for Pulse markup
  - Templates use real Pulse class names and DOM structure:
    - `#_pi_surveyWidgetContainer`, `#_pi_surveyWidget`
    - `._pi_question`, `._pi_answers_container`
    - `._pi_closeButton`, `._pi_branding`
    - `._pi_radio_button_outer`, `._pi_radio_button_inner`
    - `._pi_widgetContentContainer`, `._pi_accessibilityHidden`
  - Includes `data-layer` attributes for layer system integration

#### 2. Pulse Layer Definitions

- **Location:** `src/layers/pulseDefinitions.ts`
- **Implementation:**
  - Created `dockedSinglePulseLayersDesktopV1` and `dockedSinglePulseLayersMobileV1`
  - Layer definitions match actual Pulse DOM structure
  - Selectors use `[data-layer='...']` pattern for reliability

#### 3. Template Registry Updates

- **Location:** `src/preview/templates.ts`
- **Implementation:**
  - Added three new Pulse templates to `TEMPLATE_REGISTRY`:
    - `docked-single-desktop-pulse-v1`
    - `docked-single-iphone-pulse-v1`
    - `docked-single-android-pulse-v1`
  - Templates use `version: 'pulse-v1'` to distinguish from lab templates

#### 4. SCSS Integration

- **Location:** `src/theme/compileTheme.ts`
- **Implementation:**
  - Extended `SCSS_TEMPLATE` to target Pulse-specific class names
  - Added styles for:
    - Close button positioning and styling
    - Radio button outer/inner circles
    - Text input containers
    - Submit button containers
    - Branding link
    - Accessibility hidden elements
  - All styles pull from ThemeTokensLite via SCSS variables

#### 5. Advanced Configuration Integration

- **Location:** `src/components/AdvancedConfig.tsx`
- **Implementation:**
  - No direct changes needed (uses existing template registry)
  - Templates automatically appear in dropdowns via `getTemplatesForCanvasDevice()`
  - Users can switch between "Lab" and "Pulse" templates per device

### Files Created

- `src/preview/pulseTemplates.ts` - Pulse markup renderer functions
- `src/layers/pulseDefinitions.ts` - Pulse-specific layer definitions

### Files Modified

- `src/preview/templates.ts` - Added Pulse templates to registry
- `src/theme/compileTheme.ts` - Extended SCSS template for Pulse classes

### Key Technical Decisions

1. **HTML String Approach:** Templates return HTML strings (not React components) for iframe rendering
2. **Static Markup Only:** No live Pulse JS snippet execution (Phase 5.1+)
3. **Layer System Preservation:** `data-layer` attributes maintain layer selection functionality
4. **Template Versioning:** Uses `version: 'pulse-v1'` to distinguish from lab templates

---

## Phase 5.0a – Docked Desktop Single-Choice (Standard Buttons) + Thank You

### Overview

Added two new Pulse templates: Single Choice (Standard Buttons) and Thank You screen, using a shared shell structure.

**Design Reference:** Section 13.1 of canonical design document

### Key Features Implemented

#### 1. Shared DockedShell HTML Generator

- **Location:** `src/preview/pulseTemplates.ts`
- **Implementation:**
  - Created `generateDockedShellHTML()` helper function
  - Generates consistent Pulse widget outer structure:
    - Container with `data-layer="widget-container"`
    - Widget shell with `data-layer="widget-body"`
    - Close button, content container, branding link
  - Accepts `questionType` parameter for `data-question-type` attribute

#### 2. Single Choice (Standard Buttons) Template

- **Location:** `src/preview/pulseTemplates.ts`
- **Function:** `renderDockedSingleStandardDesktopPulseV1()`
- **Features:**
  - Uses button-style options instead of radio buttons
  - Question text with `data-layer="question-text"`
  - Answer buttons with `data-layer="single-choice-default"` and `data-layer="single-choice-active"`
  - Template ID: `docked-single-standard-desktop-pulse-v1`

#### 3. Thank You Template

- **Location:** `src/preview/pulseTemplates.ts`
- **Function:** `renderDockedThankYouDesktopPulseV1()`
- **Features:**
  - Simple thank you message screen
  - Uses `._pi_thankYouSurvey` class
  - `data-layer="thank-you-text"` for layer system
  - Template ID: `docked-thank-you-desktop-pulse-v1`

#### 4. Layer Definitions

- **Location:** 
  - `src/layers/pulse/dockedSingleStandard.ts`
  - `src/layers/pulse/dockedThankYou.ts`
- **Implementation:**
  - `dockedSingleStandardPulseLayersDesktopV1`: Widget container, widget body, question text, single-choice default/active
  - `dockedThankYouPulseLayersDesktopV1`: Widget container, widget body, thank-you text
  - Mappings use structured token paths (e.g., `components.singleChoice.bgDefault`)

#### 5. SCSS Integration

- **Location:** `src/theme/compileTheme.ts`
- **Implementation:**
  - Added styles for Standard Buttons template:
    - Question text styling
    - Default button styling with hover states
    - Active button styling
  - Added styles for Thank You template:
    - Thank you text using heading typography tokens
  - All styles integrate with existing theme token system

#### 6. Type System Updates

- **Location:** `src/types/layers.ts`
- **Implementation:**
  - Extended `QuestionType` to include:
    - `'single-choice-standard'`
    - `'thank-you'`

#### 7. Advanced Configuration Updates

- **Location:** `src/components/AdvancedConfig.tsx`
- **Implementation:**
  - Added `'single-choice-standard'` and `'thank-you'` to question types list
  - Updated `isSupported()` to recognize new question types
  - Updated `getCurrentTemplateId()` to return correct defaults for new question types
  - Templates appear in dropdowns for supported combinations

### Files Created

- `src/layers/pulse/dockedSingleStandard.ts` - Standard buttons layer definitions
- `src/layers/pulse/dockedThankYou.ts` - Thank you layer definitions

### Files Modified

- `src/preview/pulseTemplates.ts` - Added new template renderers and shell helper
- `src/preview/templates.ts` - Registered new templates
- `src/types/layers.ts` - Extended QuestionType
- `src/theme/compileTheme.ts` - Added SCSS styles for new templates
- `src/components/AdvancedConfig.tsx` - Updated question type support

### Key Technical Decisions

1. **Shared Shell Pattern:** Reusable `generateDockedShellHTML()` reduces duplication
2. **Desktop Only:** Mobile templates deferred to future phases
3. **Static Markup:** No live Pulse JS snippet (consistent with Phase 5.0)
4. **Layer System:** Full integration with existing layer selection and inspector

---

## Technical Patterns & Conventions

### Token Manager Pattern

All theme token reads/writes go through centralized Token Manager:

```typescript
import { updateToken, getToken } from '../theme/tokenManager';

// Reading
const brandPrimary = getToken<string>('palette.brandPrimary');

// Writing
updateToken('palette.brandPrimary', newColor, { source: 'themeEditor' });
```

### Template Registry Pattern

Templates are registered in `src/preview/templates.ts`:

```typescript
export const templateDockedSingleDesktopPulseV1: PreviewTemplateConfig = {
  id: 'docked-single-desktop-pulse-v1',
  label: 'Docked / Single Choice / Desktop — Pulse v1',
  version: 'pulse-v1',
  widgetType: 'docked',
  questionType: 'single-choice',
  deviceType: 'desktop',
  generateHTML: renderDockedSingleDesktopPulseV1,
  layers: dockedSinglePulseLayersDesktopV1
};
```

### Layer Definition Pattern

Layers map DOM elements to theme tokens:

```typescript
export const dockedSingleStandardPulseLayersDesktopV1: LayerDefinition[] = [
  {
    id: 'widget-container',
    displayName: 'Widget Container',
    selector: "[data-layer='widget-container']",
    group: 'widget',
    mappings: [
      { tokenPath: 'components.widget.bodyBg', role: 'background' }
    ]
  }
];
```

### SCSS Variable Pattern

SCSS variables use fallback chain for backward compatibility:

```scss
$pi-font-heading: ${typography.heading?.fontFamily || typography.fontFamilyHeading || typography.fontFamilyBase};
```

### Reset Pattern

Reset operations use baseline theme lookup:

```typescript
export function resetTokenToBaseline(tokenPath: TokenPath): boolean {
  const baselineTheme = getBaselineTheme(projectId, themeId);
  if (!baselineTheme) return false;
  const baselineValue = getNestedValue(baselineTheme, tokenPath);
  updateToken(tokenPath, baselineValue, { source: 'reset-token' });
  return true;
}
```

---

## File Structure Reference

### Core Theme System

```
src/
├── theme/
│   ├── tokenManager.ts          # Centralized token read/write API
│   └── compileTheme.ts          # SCSS compilation and template
├── types/
│   ├── theme.ts                 # ThemeTokensLite, ThemeProject interfaces
│   └── layers.ts                # LayerDefinition, PreviewTemplateConfig
└── stores/
    └── themeStore.ts            # Zustand store with baseline theme support
```

### Preview System

```
src/
├── preview/
│   ├── templates.ts             # Template registry
│   └── pulseTemplates.ts        # Pulse markup renderers
└── layers/
    ├── definitions.ts           # Lab template layer definitions
    ├── pulseDefinitions.ts      # Pulse template layer definitions
    └── pulse/
        ├── dockedSingleStandard.ts
        └── dockedThankYou.ts
```

### UI Components

```
src/
├── components/
│   ├── ThemeEditor.tsx          # Main theme editing interface
│   ├── LayerInspector.tsx       # Layer-specific editing panel
│   ├── DualPreview.tsx          # Canvas preview component
│   ├── StyleGuide.tsx           # Style guide view
│   ├── AdvancedConfig.tsx       # Template configuration modal
│   ├── UndoRedoButtons.tsx     # Undo/redo controls
│   ├── ColorInput.tsx           # Color input with reset
│   └── CollapsibleSection.tsx  # Collapsible editor sections
```

### Server/Backend

```
server/
└── generateThemes.ts            # Theme generation from SiteSnapshot
```

---

## Important Notes for Future Development

### Backward Compatibility

- All new fields in ThemeTokensLite are optional
- SCSS compilation uses fallback chains for legacy fields
- Existing themes continue to work without modification

### State Management

- Undo/redo stacks are cleared when switching themes
- Baseline themes are created automatically for new themes
- Migration logic ensures existing themes get baselines

### Template System

- Templates return HTML strings (not React components)
- Templates are selected via Advanced Configuration
- Layer definitions must match template DOM structure

### Token Paths

- Use dot notation: `'palette.brandPrimary'`
- Token Manager handles nested path resolution
- Token metadata registry provides human-readable labels

### Testing Considerations

- Undo/redo should be tested across all token sources
- Reset operations should preserve undo history
- Template switching should maintain layer selection
- Typography/layout changes should reflect immediately in all views

---

## Known Limitations & Future Work

### Phase 4.6 Limitations

- Undo/redo stacks are in-memory only (not persisted)
- Stack size limited to 100 entries
- No cross-session undo/redo

### Phase 4.7 Limitations

- Typography/layout tokens are theme-level (not per-device)
- No advanced CSS features (variable fonts, fluid type)
- Per-template typography/layout overrides not supported

### Phase 5.0 Limitations

- Static markup only (no live Pulse JS snippet)
- Desktop/iPhone/Android templates use same markup (device-specific styling via CSS)
- Limited to docked + single-choice widget/question types

### Phase 5.0a Limitations

- Desktop only (no mobile templates)
- No radio button, dropdown, multi-choice, or free-text variants
- Thank you screen is static (no dynamic content)

### Future Phases (Not Implemented)

- Phase 5.1+: Live Pulse snippet integration
- Phase 5.0b/5.0c: Mobile templates for Standard Buttons and Thank You
- Additional question types: radio, dropdown, multi-choice, free-text
- Multi-step/intro templates
- Per-device typography/layout tokens

---

## Migration Notes

If migrating existing themes or code:

1. **Baseline Themes:** Existing themes will automatically get baselines on first load via migration logic in `themeStore.ts`
2. **Typography/Layout:** Existing themes will use fallback values if new structured tokens are missing
3. **Template Selection:** Existing template selections remain valid; new Pulse templates are opt-in via Advanced Config
4. **Token Paths:** Legacy token paths continue to work; new structured paths are additive

---

## References

- **Design Document:** `docs/01_FOUNDATION_AND_ARCHITECTURE/00_THEME_GENERATOR_V3_DESIGN_CANONICAL.md`
  - Section 12.6: Phase 4.6 – Undo/Redo & Reset Tools
  - Section 12.7: Phase 4.7 – Typography & Layout Tokens
  - Section 13.0: Phase 5.0 – Pulse Markup Integration
  - Section 13.1: Phase 5.0a – Docked Desktop Single-Choice (Standard Buttons) + Thank You

---

**Document Version:** 1.0  
**Last Updated:** Implementation session covering Phases 4.6, 4.7, 5.0, and 5.0a  
**Status:** Complete

