# Theme Generator v3

A React + TypeScript application for generating Pulse widget themes from websites.

## Features

- **Theme Playground**: Edit theme properties and see live preview
- **Theme Projects**: Organize multiple themes per project
- **Persistence**: All data saved to localStorage
- **Site Analysis**: Automatically generate 4 theme variants from any website URL
- **SCSS Pipeline**: Compile themes to CSS using SCSS templates

## Getting Started

### Prerequisites

- Node.js 18+ 
- npm or yarn

### Installation

```bash
npm install
```

### Install Playwright Browsers

The analyzer uses Playwright, which requires browser binaries:

```bash
npx playwright install chromium
```

### Development

Run both frontend and backend servers:

```bash
npm run dev:all
```

This starts:
- Frontend dev server: `http://localhost:5173`
- Backend analyzer API: `http://localhost:3001`

Or run them separately:

```bash
# Frontend only
npm run dev

# Backend only
npm run dev:server
```

### Building

```bash
npm run build
```

## Usage

### Creating Themes Manually

1. Create a new project or select an existing one
2. Create a new theme or select an existing theme
3. Edit theme properties in the Theme Editor
4. See live preview in the Preview panel
5. Toggle between Desktop and Mobile viewports

### Generating Themes from a Website

1. Select or create a project
2. Enter a website URL in the "Source URL" field (e.g., `https://www.example.com`)
3. Click "Analyze" button
4. Wait for analysis to complete (may take 15-45 seconds)
5. Four new themes will be added to your project:
   - **Brand Faithful**: Stays close to the original site design
   - **Light**: Clean, light theme with good contrast
   - **Dark**: Dark theme variant
   - **Minimal**: Minimal, high-clarity theme

The first generated theme will be automatically selected for preview.

**Note**: The analyzer now crawls up to 3 pages (homepage, category/collection page, and product/detail page) to extract a more accurate brand palette. It uses CSS variables, button/link colors, background/surface colors, and logo hints to build a comprehensive color palette.

## Project Structure

```
theme-generator/v3/
├── src/                    # Frontend React app
│   ├── api/               # API client functions
│   ├── components/        # React components
│   ├── stores/            # Zustand state management
│   ├── theme/             # Theme compilation logic
│   ├── types/             # TypeScript types
│   └── styles/            # SCSS templates
├── server/                 # Backend Express server
│   ├── analyzeSite.ts     # Playwright site analyzer
│   ├── generateThemes.ts  # Theme generation logic
│   └── index.ts           # Express server
└── package.json
```

## API Endpoints

### POST /api/analyze-site

Analyzes a website and generates 4 theme variants.

**Request:**
```json
{
  "url": "https://example.com",
  "maxPages": 3
}
```

**Note**: `maxPages` defaults to 3. The analyzer will attempt to crawl:
- Homepage (`/`)
- A category/collection/shop page (e.g., `/collections`, `/shop`, `/category`)
- A product/detail page (e.g., `/product`, `/p/`, `/item`)

If any page fails to load, the analyzer gracefully skips it and continues with other pages.

**Response:**
```json
{
  "snapshot": {
    "url": "https://example.com",
    "pageTitle": "Example",
    "detectedColors": { ... },
    "typography": { ... }
  },
  "themes": [ /* 4 ThemeTokensLite objects */ ]
}
```

## Environment Variables

- `VITE_API_URL`: Backend API URL (default: `http://localhost:3001`)
- `PORT`: Backend server port (default: `3001`)

## Development Notes

- All theme data is stored in browser localStorage
- The SCSS template compiles themes to CSS for preview
- Playwright runs in headless mode for site analysis

## Phase 4.0 & 4.1 Features

### Canvas Modes

The Theme Designer supports two Canvas modes:

- **Edit Mode**: Design and configuration mode where the widget behaves as a design surface. Layer inspection, selection, and editing are enabled. Survey interactions (clicking options, typing in inputs) are disabled to allow precise layer selection.

- **Interact Mode**: Realistic survey behavior mode where the widget behaves like a real survey. All Edit-only affordances (layer highlighting, selection, inspector) are disabled. Users can click options, type in inputs, and interact with the widget as end users would.

Switch between modes using the "Canvas Mode" toggle in the Canvas header.

### Device Selection

The Canvas supports three device previews:
- **Desktop** (1280px width)
- **iPhone** (375px width)
- **Android** (360px width)

Only one device preview is shown at a time. Switch devices using the "Devices" selector in the Canvas header. iPhone and Android both use the mobile template; desktop uses the desktop template.

### Layer System

The Layer system provides semantic mapping between visual elements in the widget and theme tokens:

- **Layer Definitions**: Each layer has an ID, display name, CSS selector, and token mappings. Layers are organized into groups: Widget, Question, and Controls.

- **Layer Selection**: In Edit mode, hover over elements to see layer highlights. Click to select a layer. If multiple overlapping layers are present, the topmost layer is selected (layer picker popup coming in future phases).

- **Layer Inspector**: When a layer is selected, a Layer Inspector panel appears showing:
  - Layer name and mapped token paths
  - Brand palette swatches (Brand Primary, Brand Secondary, Accent, Background, Surface, Text Primary, Text Secondary)
  - Current color display with hex input
  - "More…" button to jump to Theme Editor

- **Layers Tab**: The Layers tab shows a hierarchical list of all layers organized by group. Clicking a layer selects it and opens the Layer Inspector. Layer selection is disabled in Interact mode.

### Context Mode Integration

Context Mode (Clean / Context) works alongside Canvas Mode:
- **Clean**: Neutral background for focusing on theme structure
- **Context**: Homepage screenshot as background for seeing the widget in context

Both Edit and Interact modes respect Context Mode settings.

## Phase 4.2 Features

### Preview Template Configuration

Phase 4.2 introduces a data-driven template system:

- **Template Registry**: All preview templates are registered in `src/preview/templates.ts` with:
  - Unique ID (e.g., `docked-single-desktop-v1`)
  - Human-readable label (e.g., "Docked / Single Choice / Desktop / v1")
  - Widget type, question type, and device type
  - HTML generation function and layer definitions

- **Template Selection State**: The app maintains active template selections per (`widgetType`, `questionType`, `deviceType`) combination. Selections are stored in Zustand and persisted to localStorage.

- **Default Templates**: Currently supports:
  - Docked widget + Single Choice question
  - Desktop, iPhone, and Android devices
  - Version v1 templates

### Advanced Configuration Modal

The Advanced Configuration modal (accessible via the "Advanced" button in the Canvas header) provides:

**A. Template Version Matrix**
- Table showing widget/question combinations
- Dropdowns to select active template version for Desktop and Mobile (iPhone/Android)
- Placeholder rows for future widget/question types (multi-choice, modal widget)
- Changes take effect immediately when saved

**B. Rendering Options**
- **Enable Animations**: Toggle preview animations (slide-in, fades)
- **Cache Templates**: Store template versions locally for faster loading
- **Max Cache Size (MB)**: Configure cache size limit (default: 50MB)

**C. Editor Options**
- **Auto-save Changes**: Automatically save theme changes as you edit
- **Debug Mode**: Show extra console logging and debug overlays in Canvas

All configuration options are stored in global state and persisted to localStorage. They can be consumed by the app for client-side behavior (CSS transitions, memoization, logging, etc.).
- Generated themes are fully compatible with the existing theme editor

## Phase 4.3 Features

### Style Guide 2.0

The Style Guide tab provides a client-ready, read-only summary of the active theme:

**Sections:**

1. **Header**: Theme name, project name, and variant label. Export buttons (Copy Markdown / Copy HTML) are located in the header.

2. **Color Palette**: Displays key theme colors as cards in a responsive grid (2-4 per row). Each card shows:
   - Large color swatch
   - Color label (e.g., "Brand Primary")
   - Hex value
   - Token path (e.g., `palette.brandPrimary`)

3. **Typography**: Shows samples for Heading, Body, and Button roles with:
   - Example text ("Quick Feedback Survey", "How satisfied are you with our service?", "Submit Feedback")
   - Font information (size, family, weight)
   - Token path (e.g., `typography.heading`)

4. **Components**: Mini-previews of core components:
   - Single Choice Option (Default and Active states side-by-side)
   - CTA Button
   - Text Input

5. **Accessibility / Contrast Summary**: Reports contrast ratios for key text/background pairs:
   - Text Primary vs Background
   - Text Primary vs Surface
   - CTA Button Text vs CTA Button Background
   - Single Choice Active Text vs Active Background
   
   Each pair shows color swatches, contrast ratio, and status (✅ Pass or ⚠️ Low contrast).

**Export Functionality:**

- **Copy Markdown**: Generates a Markdown document with all theme information (colors, typography, components, accessibility) and copies it to the clipboard.

- **Copy HTML**: Generates a semantic HTML document with the same information and copies it to the clipboard.

The Style Guide automatically reflects changes made via the Theme Editor, Layer Inspector, or palette updates. It is theme-centric and does not depend on Canvas mode or device selection.

## Phase 4.4 Features

### Token Manager & Unified Theme Update System

Phase 4.4 introduces a centralized **Token Manager** that provides a unified API for reading and writing theme tokens. All theme changes now go through this single point of contact, ensuring consistency, enabling provenance logging, and keeping all views (Canvas, Style Guide, Layers) in sync.

**Key Features:**

- **Unified Write API**: `updateToken(tokenPath, value, options)` - All theme mutations go through this function with optional source tracking (`themeEditor`, `layerInspector`, `analyzer`, `advancedConfig`, `other`).

- **Unified Read API**: `getToken<T>(tokenPath)` - Centralized token reads that automatically resolve paths like `"palette.brandPrimary"` or `"components.ctaButton.bg"` from the active theme.

- **Token Metadata Registry**: Optional metadata for tokens including labels, descriptions, and grouping (`palette`, `typography`, `component`, `layout`) to help UIs display friendly names and provide context.

- **Change Logging**: In-memory change log tracks all token updates with timestamps, old/new values, and source. Useful for debugging and future undo/redo features. Accessible via `getChangeLog()`.

**Refactored Components:**

- **Theme Editor**: All color, typography, and component token updates now use `updateToken` with `source: 'themeEditor'`.

- **Layer Inspector**: Color swatch clicks and hex input changes use `updateToken` with `source: 'layerInspector'`. Token reads use `getToken`.

- **Style Guide**: Key token reads (colors, typography, contrast calculations) use `getToken` for consistency.

**Benefits:**

- Single source of truth for all theme mutations
- Automatic change tracking and provenance
- Consistent behavior across all editing surfaces
- Easier to add future features (undo/redo, validation, AI suggestions)
- Better debugging with change log visibility

The Token Manager does not modify `ThemeTokensLite` structure, analyzer behavior, or SCSS template semantics. It is purely a refactoring of how updates are propagated through the system.

## Phase 4.5 Features

### Visual Polish & UI System

Phase 4.5 introduces a comprehensive UI design system and visual polish pass to upgrade the look & feel of the Theme Designer to match modern design standards.

**UI Design System:**

- **UI Color Tokens** (`src/ui/tokens.ts`): Centralized color palette for consistent styling:
  - `bg`: App background (#F8FAFC)
  - `panel`: Panel/card background (#FFFFFF)
  - `border`: Neutral borders (#E2E8F0)
  - `divider`: Section dividers (#E5E7EB)
  - `text`: Primary text (#1E293B)
  - `textMuted`: Secondary text (#64748B)
  - `primary`: Primary actions (#3B82F6)
  - `primaryHover`: Primary hover state (#2563EB)
  - `focusRing`: Focus indicators (#3B82F6)
  - `canvasDarkBg`: Dark background for mobile frames (#1E293B)

- **UI Typography Tokens** (`src/ui/typography.ts`): Typography roles for consistent text styling:
  - `title`: 18px, 600 weight (headers)
  - `section`: 15px, 500 weight (section headings)
  - `label`: 13px, 500 weight (field labels)
  - `body`: 14px, 400 weight (body text)
  - `small`: 12px, 400 weight (small text)

- **Motion Tokens** (`src/ui/motion.ts`): Animation timing constants:
  - `fast`: 150ms ease (hover states, quick transitions)
  - `medium`: 300ms ease-in-out (sidebar collapse, tab switches)
  - `slow`: 400ms ease-out (device switching, page transitions)

- **Container Styles** (`src/ui/containers.css`): Reusable card and container classes:
  - `.card`: Base card style with shadow and border
  - `.card-modal`: Modal card with stronger shadow
  - `.card-section`: Section card for Style Guide sections
  - `.card-component`: Component preview card

**Visual Improvements:**

- **Canvas Header**: Studio toolbar layout with grouped clusters (Canvas Mode, Device Selector, Context + Advanced), taller header (56px), consistent button styling with active/hover states.

- **Device Frames**: 
  - Desktop: Card-style preview with light neutral background
  - iPhone: Rounded frame (32px radius) with notch, dark background, drop shadow
  - Android: Less rounded frame (24px radius) with speaker notch, dark background
  - Smooth cross-fade animations when switching devices

- **Layers Tab**: Tree-style layout with icons, chevrons, indentation (16px per depth), selected state with blue background and left border, hover states.

- **Layer Inspector**: Card-style panel with two-column layout (PROPERTIES / COLORS), larger color swatches with selected state (border + glow), fade-in animation on appearance.

- **Style Guide**: Card-style sections with consistent spacing (24px), color swatches with fixed height (120px), typography samples in cards, contrast badges (pill style with green/red tints).

- **Modals**: Card modal style with stronger shadow, 12px border radius, proper header/footer styling, consistent input focus rings.

**Microinteractions:**

- Tab underline animations (200ms)
- Button hover transitions (150ms)
- Device switching fade + scale (400ms)
- Sidebar collapse slide (300ms)
- Layer Inspector popover fade + translate (200ms)

All microinteractions use the motion tokens for consistency.

**Constraints:**

- No changes to `ThemeTokensLite` structure
- No changes to analyzer or template logic
- No changes to Token Manager behavior
- Purely visual/UI polish - all functionality remains identical

## Phase 4.6 Features

### Undo / Redo & Reset Tools

Phase 4.6 introduces comprehensive undo/redo functionality and reset mechanisms for theme tokens, enabling users to easily revert changes and restore themes to their baseline state.

**Key Features:**

- **Baseline Theme Snapshot**: Each theme maintains a deep copy of its initial state (when first created or generated by the analyzer). This baseline is used as a reference point for all reset operations.

- **Undo / Redo Stacks**: The Token Manager maintains separate `undoStack` and `redoStack` arrays to track token changes. Users can undo the last change or redo a previously undone change using buttons in the Canvas header.

- **Reset Token**: Individual token fields in the Theme Editor and Layer Inspector include a reset button (↺) that restores that specific token to its baseline value.

- **Reset Group**: Each collapsible section (Palette, Typography, Widget, Single Choice, CTA Button, Layout) includes a "Reset Group" button that resets all tokens in that group to their baseline values.

- **Reset Entire Theme**: A "Reset Theme to Baseline" button in the Theme Editor header allows users to restore the entire theme to its original state. This action requires confirmation (click twice) to prevent accidental resets.

**Implementation Details:**

- **Baseline Storage**: Baseline themes are stored in `ThemeProject.baselineThemes` as a `Record<string, ThemeTokensLite>` mapping theme IDs to their baseline snapshots.

- **Undo/Redo Logic**: When `updateToken` is called with a non-undo/redo/reset source, the change is pushed onto `undoStack` and `redoStack` is cleared. Undo operations pop from `undoStack`, apply the old value, and push to `redoStack`. Redo operations reverse this process.

- **Change Logging**: All token changes (including undo/redo/reset operations) are logged to the Token Manager's change log for debugging and provenance tracking.

- **Stack Management**: Undo/redo stacks are automatically cleared when switching themes or generating new themes to prevent confusion.

**UI Components:**

- **UndoRedoButtons**: Component in Canvas header with Undo (↩) and Redo (↪) buttons, disabled when stacks are empty.

- **Reset Token Button**: Small ↺ button next to each editable field in Theme Editor and Layer Inspector.

- **Reset Group Button**: "Reset Group" button in each CollapsibleSection header.

- **Reset Theme Button**: "Reset Theme to Baseline" button in Theme Editor header with confirmation state.

**Constraints:**

- No changes to `ThemeTokensLite` structure
- No changes to analyzer behavior
- No changes to SCSS template semantics
- Undo/redo stacks are in-memory only (not persisted)
- Baseline themes are persisted per project in localStorage

## Phase 5.0 Features

### Pulse Markup Integration (Static Templates)

Phase 5.0 introduces **real Pulse widget markup** into the Theme Designer as a new set of preview templates, while preserving the existing Canvas / Layers / Style Guide / Token Manager architecture.

**Key Features:**

- **Pulse-Based Templates**: New template versions using real Pulse HTML structure and class names:
  - `docked-single-desktop-pulse-v1`: Desktop Pulse template
  - `docked-single-iphone-pulse-v1`: iPhone Pulse template
  - `docked-single-android-pulse-v1`: Android Pulse template

- **Template Selection**: Switch between "Lab" templates (simplified v1) and "Pulse" templates (pulse-v1) via Advanced Configuration:
  - Open Advanced Configuration modal from Canvas header
  - Select template version per widget/question/device combination
  - Changes take effect immediately

- **Real Pulse Markup**: Templates use actual Pulse DOM structure:
  - `#_pi_surveyWidgetContainer` and `#_pi_surveyWidget` containers
  - `._pi_question`, `._pi_answers_container`, `._pi_closeButton` classes
  - `._pi_radio_button_outer` and `._pi_radio_button_inner` for radio buttons
  - `._pi_widgetContentContainer`, `._pi_branding`, `._pi_accessibilityHidden` elements

- **Layer System Integration**: Pulse templates include `data-layer` attributes matching layer definitions:
  - Widget container, header, and body layers
  - Single choice default and active states
  - CTA button and text input layers
  - All layers work with Layer Inspector and Edit mode

- **SCSS Compatibility**: Theme compilation targets Pulse class names:
  - Styles apply to Pulse-specific elements (close button, radio buttons, branding)
  - All theme tokens map correctly to Pulse markup
  - Preview reflects theme changes in real-time

**Current Support:**

- **Widget Types**: Docked widget only (for now)
- **Question Types**: Single choice only (for now)
- **Devices**: Desktop, iPhone, Android
- **Template Versions**: v1 (Lab) and pulse-v1 (Pulse)

**Usage:**

1. Open Advanced Configuration from Canvas header
2. In Template Version Matrix, find "Docked / Single Choice" row
3. Select template version from Desktop Template dropdown:
   - "Docked / Single Choice / Desktop / v1" (Lab template)
   - "Docked / Single Choice / Desktop / Pulse v1" (Pulse template)
4. Select template version from Mobile Template dropdown (iPhone/Android)
5. Click "Save" to apply changes

The preview will immediately switch to the selected template version, maintaining all theme customizations and layer functionality.

**Note:** Phase 5.0 uses **static markup only**. Live Pulse snippet integration (JavaScript runtime behavior) is planned for Phase 5.1+.

## Phase 4.7 Features

### Typography & Layout Tokens

Phase 4.7 extends theme expressiveness by elevating typography and layout to first-class theme tokens, enabling fine-grained control over text styling and widget shape.

**Key Features:**

- **Enhanced Typography Structure**: Typography tokens are now organized by role (heading, body, button) with comprehensive properties:
  - `fontFamily`: Font family for each role
  - `fontSize`: Font size in pixels
  - `fontWeight`: Font weight (400, 500, 600, 700)
  - `lineHeight`: Line height as unitless multiple
  - `letterSpacing`: Letter spacing for buttons (px)

- **Enhanced Layout Structure**: Layout tokens provide component-specific control:
  - **Border Radius Tokens**: Separate border radius values for widget, button, option, and input components
  - **Spacing Tokens**: Option gap, widget padding, and section spacing
  - **Max Width Tokens**: Widget maximum width constraint

**Typography Editor UI:**

- **Heading Section**: Controls for font family, size, weight, and line height
- **Body Section**: Controls for font family, size, weight, and line height
- **Button Section**: Controls for font family, size, weight, letter spacing, and line height
- All controls use Token Manager for updates and support undo/redo and reset functionality

**Layout Editor UI:**

- **Border Radius Group**: Individual controls for widget, button, option, and input border radius
- **Spacing Group**: Controls for option gap, widget padding, and section spacing
- **Max Width Group**: Control for widget maximum width
- All controls display token paths and support undo/redo and reset functionality

**Canvas Integration:**

- Preview templates use enhanced typography tokens for heading, body, and button text
- Layout tokens control border radius, spacing, and max width in the compiled CSS
- Changes reflect immediately in the Canvas preview

**Layer Inspector Integration:**

- **Text Layers**: Display typography information (font family, size, weight) with sample text and "Jump to Typography Editor" link
- **Container Layers**: Display layout information (border radius, padding, spacing, max width) with "Jump to Layout Editor" link
- Typography and layout values are read-only in Layer Inspector (editing happens in Theme Editor)

**Style Guide Integration:**

- Typography section shows heading, body, and button samples using actual typography tokens
- Displays metadata (font size, family, weight) and token paths
- Components section reflects updated border radius and spacing tokens

**SCSS Compilation:**

- SCSS template uses enhanced typography tokens with fallbacks to legacy structure
- Layout tokens are applied to widget, button, option, and input components
- All tokens support backward compatibility with existing themes

**Token Paths:**

- **Typography**: `typography.heading.*`, `typography.body.*`, `typography.button.*`
- **Layout**: `layout.borderRadiusTokens.*`, `layout.spacing.*`, `layout.maxWidth.*`

**Constraints:**

- No breaking changes to `ThemeTokensLite` structure (new fields are optional)
- Backward compatible with existing themes (fallbacks to legacy structure)
- Undo/redo and reset functionality work seamlessly with typography/layout tokens
- All changes reflect immediately in Canvas, Style Guide, and Layer Inspector

### Color Extraction (Phase 3.7 & 3.9)

The analyzer uses an improved multi-page color extraction system with brand color refinement:

- **Multi-page crawling**: Visits homepage, category, and product pages to gather more color samples
- **CSS variable extraction**: Reads CSS custom properties (`--brand-*`, `--color-*`, `--primary-*`, etc.) from `:root` and header/theme containers
- **Button & link sampling**: Samples colors from buttons, CTAs, and prominent links with weighted frequency tracking (CTA colors get 1.5x weight, nav colors get 1.2x weight)
- **Background & surface extraction**: Gathers background colors from body, header, nav, footer, and surface elements
- **Logo color sampling** (Phase 3.9): Samples the top 200-300px region of the homepage screenshot to extract dominant saturated brand colors using pixel clustering
- **Brand Color Priority Model** (Phase 3.9): Palette builder follows a clear priority order:
  - **Brand Primary**: CSS variables (`--brand-primary`, `--primary`) → Logo color → CTA button backgrounds → CTA text/borders → High-saturation accents
  - **Brand Secondary**: Remaining CSS variables → Second-highest saturation (different hue) → Nav/CTA colors → Distinct hues with contrast
  - **Accent**: Distinct non-brand hues → Secondary CTAs → Link hover colors → Warm/bright hero colors
- **Stability thresholds**: Colors must appear on multiple pages or come from CSS variables/logo to be considered brand candidates
- **Hue differentiation**: Ensures brandSecondary has sufficient hue difference from brandPrimary (30+ degrees)
- **Contrast validation**: Ensures text colors meet WCAG 4.5:1 minimum contrast ratio

## Troubleshooting

### Playwright browser not found

Run: `npx playwright install chromium`

### Backend server won't start

Check that port 3001 is available. Change it with: `PORT=3002 npm run dev:server`

### Analysis fails

- Ensure the URL is accessible
- Check browser console for errors
- Verify Playwright browsers are installed

## License

Internal use only.

