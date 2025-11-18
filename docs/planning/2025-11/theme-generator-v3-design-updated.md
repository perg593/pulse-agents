# Theme Generator v3 – Plan & Architecture



## 0. Purpose

Build a **Theme Generation app for Pulse Insights** that:

* Analyzes a client website.
* Generates **4 production-ready Pulse themes**.
* Lets users **preview and refine** those themes (especially on mobile).
* Outputs **CSS** that can be pasted directly into the Pulse console.
* Over time, learns from **existing Pulse themes (CSS/SCSS)** to get smarter.

The app should be usable by internal folks (you + devs) and eventually by non-devs (CSMs, designers) to quickly produce high-quality themes that match a site’s look and feel.

Cursor + GitHub are the primary dev tools. Cursor can handle all git/branching mechanics; this document is the **conceptual blueprint**.

---





## 1. Core Concepts

### 1.1 Theme Projects

The primary object is a **Theme Project**.

Each project represents one site (or client) and contains:

* **Input**

  * Target URL (e.g. `https://www.skechers.com`)
  * Number of pages to analyze (default: 3)
  * Optional notes and flags (e.g. “Light mode bias”, “Dark mode bias”)

* **Analysis Results**

  * Extracted color palette
  * Typography (fonts, sizes, weights)
  * Component style hints (buttons, links, inputs)
  * Evidence: snippets/samples from the site (for debugging/trust)

* **Themes**

  * At least 4 variants per project:

    * Brand Faithful
    * Light
    * Dark
    * Minimal / High-clarity
  * Each theme can be edited, duplicated, and exported.

* **Style Guide**

  * Visual document showing:

    * Colors
    * Typography
    * Component examples (single-choice, sliders, etc.)
  * Tied to a specific theme.

* **Exports**

  * CSS ready for Pulse console (copy–paste).
  * Optional: download bundle (tokens JSON + SCSS + CSS) for devs.

---

### 1.2 Theme Tokens (Conceptual Model)

Internally, themes should be represented as a **structured “Theme Tokens” object**, not just raw CSS.

The Theme Tokens object (conceptual, not tied to any specific language) includes:

* **Identity**

  * `id` – unique identifier
  * `name` – human label (“Brand Faithful”, “Visa Dark v2”)
  * `variantType` – e.g. `brand-faithful`, `light`, `dark`, `minimal`, `custom`
  * `sourceUrl` – where the theme came from (site URL, optional)
  * `createdAt`

* **Palette**

  * Neutral scale: `neutral0`, `neutral50`, `neutral100`, …, `neutral900`

    * Used for backgrounds, borders, text, etc.
  * Brand colors:

    * `brandPrimary`
    * `brandPrimarySoft` (optional)
    * `brandSecondary` (optional)
    * `accent`
  * Semantic colors:

    * `success`, `warning`, `danger`, `info`

* **Surfaces**

  * `appBackground` – base background (if needed)
  * `widgetBackground` – main survey container
  * `cardBackground`
  * `surfaceAlt` – alternate/hover surfaces
  * `borderSubtle`
  * `borderStrong`
  * `overlayBackground` – for overlays/modals (e.g. rgba black)

* **Text Roles**

  * `textPrimary`
  * `textSecondary`
  * `textMuted`
  * `textInverse` – text on dark backgrounds
  * `textLink`
  * `textLinkHover`
  * `textDanger`
  * `textSuccess`

* **Typography**

  * Font families:

    * `fontFamilyBase` (body text)
    * `fontFamilyHeading` (optional override)
    * `fontFamilyMono` (optional)
  * Base sizing:

    * `baseFontSize` (px)
    * `baseLineHeight` (unitless)
  * Text styles (include size, line-height, optional letter-spacing and weight):

    * `heading.h1`, `heading.h2`, `heading.h3`, `heading.h4`
    * `body`
    * `label`
    * `button`
    * `small`
  * These can be used to control **spacing and perceived kerning**:

    * Letter-spacing at least on buttons and headings.

* **Spacing**

  * A small scale of spacing tokens (pixels):

    * `spacing.xs`, `spacing.sm`, `spacing.md`, `spacing.lg`, `spacing.xl`
  * Used for:

    * Padding
    * Gaps between options
    * Widget margin / internal layout

* **Radii**

  * `radius.none`
  * `radius.sm`
  * `radius.md`
  * `radius.lg`
  * `radius.pill`
  * `radius.full`
  * Used for:

    * Buttons
    * Pills
    * Cards
    * Widgets

* **Elevation**

  * **Shadow tokens** (string values):

    * `elevation.subtle`
    * `elevation.raised`
    * `elevation.overlay`

* **Component-specific Tokens**

  Theme Tokens should understand **Pulse components**, not just generic buttons.

  * **Widget / Chrome**

    * `widget.headerBackground`
    * `widget.headerText`
    * `widget.bodyBackground`
    * `widget.bodyText`
    * `widget.border`
    * `widget.progressBackground`
    * `widget.progressFill`
    * `widget.overlayBackground`

  * **Single-choice option**

    * A set of **state tokens**:

      * `default` (bg, text, border)
      * `hover`
      * `active`
      * `disabled`
      * optional `focusRing` (color, width, offset)

  * **Multi-choice option**

    * Same model as single-choice (chips/checkbox-style).

  * **Tag pills / labels**

    * Tokens for “pill” styles (filters, segments).

  * **Buttons**

    * `ctaButton` (primary action)
    * `secondaryButton`
    * Each defines:

      * default/hover/active/disabled state colors
      * optional focus ring

  * **Inputs**

    * `textInput` (free-text answers)
    * `dropdownInput` (select-like)
    * Each defines:

      * default/hover/focus/disabled states
      * placeholder color
      * optional error styling (border, text, background)
      * optional focus ring

  * **Sliders / scales**

    * `slider.trackBackground`
    * `slider.trackFilled`
    * `slider.thumbBackground`
    * `slider.thumbBorder`
    * optional `slider.tickColor`, `slider.valueLabelText`

  * **Content links / promos**

    * Default/hover/visited colors, optional focus ring.

The point: a Theme is a **structured set of decisions** that can be used to:

* Drive **preview UI**
* Drive **SCSS template**
* Drive **style guide**

We are not locked into a specific implementation language here.

---

### 1.3 Theme Template (SCSS Engine)

Pulse already has SCSS files with:

* variables
* maps
* mixins
* selectors
* responsive behaviors

v3 should:

* Consolidate these into a **single SCSS “Theme Template”** that:

  * Contains the full implementation of how Pulse widgets are styled.
  * Expects a set of variables or a single map (e.g. `$tokens`) that corresponds to the Theme Tokens.

* This template should:

  * Know Pulse’s HTML structure (selectors, states).
  * Use the tokens for:

    * Colors
    * Fonts
    * Spacing
    * Radii
    * Component logic (e.g. single-choice vs slider)
  * Be versioned:

    * `ThemeTemplate v1` corresponds to current Pulse HTML/markup.
    * In future, `v2` can be created if markup changes.

Implementation detail (high-level):

* Theme Generator:

  * Takes a Theme Tokens object.
  * Emits a small SCSS snippet that sets variables / map values.
  * Imports the `theme-template.scss`.
  * Compiles SCSS → CSS.
* Pulse console:

  * Only ever sees the compiled CSS.

---





## 2. Product UX

### 2.1 Default Flow: “URL → 4 Themes”

The primary user journey:

1. **Create a Theme Project**

   * Enter URL
   * Choose number of pages to analyze (default 3)
   * Click “Analyze & Generate Themes”

2. **Analysis**

   * A backend analyzer:

     * Loads the specified pages.
     * Extracts:

       * Colors (from CSS variables & computed styles)
       * Typography (font families, sizes, headings vs body)
       * Basic component styles (buttons, links, inputs)
     * Produces a **Site Snapshot** (see 3.2)
     * Converts the Site Snapshot into **4 Theme Tokens**:

       * Brand Faithful
       * Light
       * Dark
       * Minimal

3. **Themes View**

   * Shows 4 theme cards:

     * Thumbnail preview
     * Name
     * Actions:

       * “Open in Editor”
       * “Copy CSS for Pulse”
       * “Duplicate theme”

4. **Preview**

   * For any theme:

     * Preview panel shows:

       * Fake Pulse survey HTML:

         * Question title
         * Description
         * Single-choice options
         * Slider
         * Free-text input
         * Submit button
     * Viewport toggles:

       * Desktop
       * Tablet (optional)
       * Mobile (essential)
     * Theme CSS is applied to this preview.

5. **Export**

   * “Copy CSS for Pulse console”
   * Optional: “Download theme bundle” (tokens + SCSS + CSS)

---

### 2.2 Theme Editor (Customization Interface)

Per theme, the editor provides:

* **Left panel**: Token categories

  * Palette
  * Typography
  * Components (Single-choice, Buttons, Slider, Inputs)
  * Spacing / Radii (advanced)

* **Center panel**: Live preview

  * Uses the same fake Pulse HTML.
  * Desktop/mobile toggles.

* **Right panel**: Inspector

  * When clicking on a part of the preview (e.g. single-choice button):

    * Shows which tokens drive it.
  * Editing those tokens updates:

    * Preview
    * Theme Tokens object
    * Under-the-hood CSS (via SCSS template)

Advanced options (hidden by default):

* Spacing scale adjustments (padding, gaps).
* Letter-spacing for headings/buttons.
* Per-component radii.

---

### 2.3 Mobile & Tablet Previews

Viewports:

* Desktop: e.g. width 1280
* Tablet: width ~768–1024
* Mobile: width ~375–430

Each viewport:

* Renders the same Pulse widget markup.
* Applies the same CSS.
* Allows evaluation of:

  * Text size
  * Spacing
  * Tap targets
  * Contrast and readability

Mobile is **non-negotiable priority**. Tablet is nice-to-have but should be considered.

---

### 2.4 Fonts & Custom Font Handling

Key requirement: Many clients have custom fonts (e.g. `VisaBold`).

The app should:

1. **Auto-detect fonts from the site**:

   * Parse loaded CSS for:

     * `@font-face` rules.
     * Remote font CSS (Google Fonts, Adobe, or client-hosted).
   * Detect which font families are used for:

     * Headings
     * Body text
     * Buttons

2. **Use these fonts in preview where possible**:

   * Apply the same `font-family` in Theme Tokens.
   * For web-accessible fonts (public URLs), load them into the preview via `<link>` or inline `@font-face`.

3. **Provide manual overrides**:

   * In the typography section:

     * Let user edit `fontFamilyBase` and `fontFamilyHeading`.
     * Provide fallbacks (e.g. `VisaBold, system-ui, sans-serif`).

Licensing note: font files are not re-distributed. The app should load them from existing client-hosted URLs or public CDNs when possible.

---







## 3. Technical Architecture (High-Level)

This is intentionally tool-agnostic on specifics. Cursor will handle the exact frameworks and wiring.

### 3.1 Major Components

1. **Front-end UI**

   * React-based (or similar) single-page app.
   * Responsibilities:

     * Project list and details
     * URL input + “Analyze” trigger
     * Theme cards view (4 variants)
     * Theme editor
     * Viewport preview (desktop/mobile)
     * Style guide view

2. **Theme Engine**

   * Core logic (likely a shared library/module):

     * Theme Tokens model.
     * Mapping between Theme Tokens and SCSS variables.
     * SCSS template integration.
     * SCSS → CSS compilation.
   * Should be reusable by:

     * UI in dev.
     * CLI or backend jobs in future.

3. **Analyzer Backend**

   * Service that:

     * Given URL + page count:

       * Crawls pages (using Playwright/Puppeteer or similar).
       * Extracts:

         * Colors
         * Fonts
         * Basic component styles
       * Builds a **Site Snapshot** (structured).
       * Converts it into 4 Theme Tokens (via Theme Engine).
   * Can start as a simple Node script run manually or via dev server.
   * Later can become:

     * A service on GCP Cloud Run or AWS Lambda.

4. **Storage**

   * For v1:

     * Simple storage (e.g. JSON in local dev).
   * Later:

     * Database or cloud storage:

       * `Theme Projects`
       * `Themes`
       * `Site Snapshots`

---

### 3.2 Site Snapshot (Conceptual)

The Analyzer produces a **Site Snapshot** that contains:

* **Colors**

  * Candidate brand colors
  * Background colors
  * Text colors
  * Semantic hints (e.g. button background, link color)

* **Typography**

  * Font families used for headings and body.
  * Approximate sizes and weights.

* **Component Patterns (Lightweight)**

  * Buttons:

    * Background, text, border colors
    * Hover/active hints (if discoverable)
  * Inputs:

    * Background, border, placeholder colors.
  * Links:

    * Default and hover colors.

* **Meta**

  * URLs crawled
  * Confidence scores for some choices

The Theme Engine takes this snapshot and emits 4 Theme Tokens:

* `Brand Faithful`: stays as close as possible, with contrast fixes.
* `Light`: lighter surfaces, safe contrast, brand as accent.
* `Dark`: dark surfaces, brand color as main highlight.
* `Minimal`: neutral, high clarity, brand color limited.

---





## 4. Using Existing CSS/SCSS Themes

You already have:

* Many **CSS themes** used in production.
* Many **SCSS files** with maps, mixins, variables.

These should be used as **inputs to design the system**, not just content.

Usage:

1. **Schema Discovery**

   * Analyze existing SCSS/CSS to extract:

     * Common variables
     * Common patterns
     * Range of values and design patterns.
   * Use this to:

     * Inform the Theme Tokens schema.
     * Inform the SCSS Theme Template.

2. **Template Creation**

   * Create a canonical `theme-template.scss` that:

     * Encodes how Pulse components should be styled.
     * Replaces hard-coded values with variables/maps compatible with Theme Tokens.

3. **Optionally: Training Set for Later ML**

   * Once Theme Tokens are defined:

     * Map existing themes into tokens.
     * Use this pool later to train or guide:

       * More advanced auto-generation.
       * Better heuristics for dark/light variants.
   * This is a future phase, not required for v1.

---






## 5. Preview Strategy

Two main approaches:

### 5.1 Simulated HTML (Primary for v1)

* Use HTML fragments that match **Pulse’s survey markup**:

  * Single-choice question
  * Multi-choice
  * Slider
  * Input
  * CTA buttons
* Render these fragments inside the app and apply the generated CSS.
* Benefits:

  * Fully controlled.
  * Easy to version alongside the template.
* Risk:

  * Can drift from real widget if Pulse markup changes (mitigated with template versioning and periodic syncs).

### 5.2 Optional “Real Pulse” Preview (Later)

* Use a dedicated Pulse test account/environment.
* Render a real survey via:

  * Pulse snippet on a test page.
  * Apply generated CSS via a `<style>` tag or external file.
* Benefits:

  * Confidence that themes behave correctly in production context.
* Costs:

  * More moving parts: account, snippet, environment, auth.
  * Needs integration and coordination with core Pulse stack.

**Recommendation:**

* v1: Simulated HTML preview inside the app.
* Later: Add a “Preview in real Pulse” link that opens a test page styled with the generated theme.

---







## 6. Accessibility & Contrast

The Theme Engine must:

* Check contrast between:

  * Single-choice button text vs background.
  * CTA text vs background.
  * Body text vs widget background.
  * Slider thumb vs track.
* Enforce minimum contrast thresholds (inspired by WCAG).
* If initial colors don’t meet thresholds:

  * Adjust them slightly (darken/lighten).
  * Record the adjustments in metadata, if useful.

This is critical for:

* Clients in regulated industries.
* Mobile readability.
* General UX quality.

---






## 7. Implementation Phasing (for Cursor)

This section is intentionally conceptual; Cursor will handle the details.

### Phase 0 – Theme Playground (Local only)

* Simple app with:

  * A small theme object (colors + fonts + radii).
  * A fake Pulse survey preview.
  * Desktop/mobile toggle.
* No backend, no analysis, no persistence.

### Phase 1 – Theme Tokens + SCSS Template Integration

* Evolve the theme object into a **richer Theme Tokens structure** (based on this doc).
* Create or refactor `theme-template.scss` to:

  * Use variables/ maps driven by Theme Tokens.
* Wire up:

  * Theme Tokens → SCSS → CSS → preview.

### Phase 2 – Theme Projects & Persistence

* Introduce **Theme Projects**:

  * Multiple projects stored in the UI.
  * Each project holds multiple themes.
* Provide:

  * Create project
  * Rename project
  * Add/duplicate themes per project
* Persist projects somewhere simple (local dev first).

### Phase 3 – Analyzer & Auto Generation (URL → 4 Themes)

* Implement analyzer:

  * Given URL + page count → Site Snapshot.
* Implement generation:

  * Site Snapshot → 4 Theme Tokens (Brand Faithful, Light, Dark, Minimal).
* Integrate analysis trigger into the UI:

  * Enter URL + pages → click “Analyze” → get 4 themes in current project.

### Phase 4 – Style Guide & Refinements

* Add Style Guide view for each theme:

  * Colors
  * Typography samples
  * Component examples
  * Contrast indicators
* Let users:

  * Export style guide as HTML or Markdown (optional).
* Improve:

  * Font handling
  * Spacing/kerning controls
  * Tablet preview

---






## 8. Placeholder. Ignore this

---







## 9. Phase 1 – Theme Tokens Lite & SCSS Pipeline (Practical Plan)

### 9.1 Goals for Phase 1

Phase 1 should **evolve** the current playground into something closer to the final architecture, but without going “full enterprise schema” yet.

Concretely:

1. Upgrade the `SimpleTheme` into a **Theme Tokens Lite** structure:

   * Still understandable at a glance.
   * Already aligned with the bigger Theme Tokens concepts (palette, typography, components).
2. Replace inline / hardcoded styles in `SurveyPreview` with:

   * A **SCSS template** that takes variables from the theme.
   * A **basic SCSS → CSS compilation step**.
3. Continue to:

   * Keep everything local (no backend, no analyzer).
   * Keep the UI simple and working.
   * Let me still edit theme values and see live preview for Desktop/Mobile.

This is the bridge between the toy playground and the real engine.

---

### 9.2 Theme Tokens Lite (v0.1)

Instead of jumping straight to the full Theme Tokens spec, Phase 1 will introduce a **small, structured theme model** that still feels similar to the final shape.

#### 9.2.1 ThemeTokensLite shape (conceptual)

Implementation detail is up to Cursor, but the model should look roughly like this:

```ts
// Conceptual shape, not a final TS interface name requirement

ThemeTokensLite {
  id: string;
  name: string;                 // "Brand Faithful", "Visa Light v1", etc.
  variantType: "custom" | "brand-faithful" | "light" | "dark" | "minimal";

  // Palette – simple but more semantic than Phase 0
  palette: {
    background: string;         // widget background
    surface: string;            // cards / options background
    surfaceAlt: string;         // hover or subtle surface
    textPrimary: string;
    textSecondary: string;
    brandPrimary: string;
    brandSecondary: string;
    accent: string;
    danger: string;
    success: string;
  };

  // Typography – stripped-down but ready for growth
  typography: {
    fontFamilyBase: string;
    fontFamilyHeading?: string;
    baseFontSize: number;       // px
    headingSize: number;        // px, for question titles
    bodySize: number;           // px, for body / option text
    buttonSize: number;         // px
  };

  // Components – just enough to express key Pulse components
  components: {
    widget: {
      headerBg: string;
      headerText: string;
      bodyBg: string;
      bodyText: string;
      borderColor: string;
    };

    singleChoice: {
      bgDefault: string;
      bgActive: string;
      textDefault: string;
      textActive: string;
      borderDefault: string;
      borderActive: string;
    };

    ctaButton: {
      bg: string;
      text: string;
      bgHover: string;
      textHover: string;
    };
  };

  // Layout / shape
  layout: {
    borderRadius: number;       // base radius for options + buttons
    spacingMd: number;          // main padding / gap, px
  };
}
```

Notes:

* This **replaces** the current `SimpleTheme` (`primaryColor`, `secondaryColor`, etc.).
* It is intentionally small:

  * Enough to feel like “real theme tokens”.
  * Not so big that editing it is overwhelming.
* It lines up nicely with the bigger Theme Tokens idea (palette, typography, components, spacing).

---

### 9.3 SCSS Template for Preview

Phase 1 introduces a **SCSS template** to drive the preview instead of inline styles.

Key ideas:

1. Create a new SCSS file (for example):
   `src/styles/theme-template-v1.scss`

2. This file should:

   * Define **CSS rules** for the fake survey markup used in `SurveyPreview`:

     * `.pi-widget`
     * `.pi-widget-header`
     * `.pi-widget-body`
     * `.pi-question-title`
     * `.pi-option`
     * `.pi-option--active`
     * `.pi-text-input`
     * `.pi-submit-button`
   * Rely on **SCSS variables** (or a map) for:

     * Colors
     * Font families
     * Font sizes
     * Border radius
     * Spacing

   Example variables (illustrative, Cursor can refine):

   ```scss
   $pi-bg: #ffffff;
   $pi-surface: #f9fafb;
   $pi-text-primary: #111827;
   $pi-text-secondary: #4b5563;
   $pi-brand-primary: #2563eb;
   $pi-brand-secondary: #9333ea;
   $pi-accent: #f97316;
   $pi-danger: #dc2626;
   $pi-success: #16a34a;

   $pi-font-base: "system-ui", sans-serif;
   $pi-font-heading: "system-ui", sans-serif;
   $pi-font-size-base: 14px;
   $pi-font-size-heading: 18px;
   $pi-font-size-button: 14px;

   $pi-border-radius: 9999px; // or 8px etc
   $pi-spacing-md: 12px;
   ```

3. Phase 1 does **not** need to integrate with the full Pulse SCSS framework yet.

   * This template is **scoped to the preview only**.
   * Later phases can replace it with a template that wraps the real Pulse SCSS.

---

### 9.4 SCSS → CSS Compilation Pipeline (Preview Only)

For Phase 1, the compilation can be **local, simple, and dev-only**:

* Use `sass` (Dart Sass) in Node.

* Implement a small function/module (e.g. `src/theme/compileTheme.ts`) that:

  1. Takes a `ThemeTokensLite` instance.
  2. Generates a SCSS string:

     * Sets the SCSS variables derived from the theme.
     * Imports `theme-template-v1.scss`.
  3. Calls `sass.compileString` (or similar) to get CSS.
  4. Returns CSS as a string.

* `SurveyPreview` should:

  * Call this compilation function whenever the theme changes.
  * Inject the compiled CSS into the iframe’s `srcDoc` (instead of inline styles).

**Performance note:**
It’s okay if this is not insanely optimized in v1. The goal is correctness and a clear pathway, not micro-performance.

---

### 9.5 UI/UX Changes in Phase 1

1. **Theme Editor**

   * Update `ThemeEditor` to edit `ThemeTokensLite` instead of `SimpleTheme`.
   * Group fields in logical sections:

     * Palette
     * Typography
     * Components (Widget, Single Choice, CTA)
     * Layout (radius, spacing)
   * Keep the UI minimal:

     * Don’t expose every nested field if overwhelming.
     * It’s okay to start with:

       * Basic palette fields
       * Font family + basic sizes
       * A few component fields
       * Border radius

2. **Survey Preview**

   * Stop generating inline CSS in JS.
   * Use the compiled CSS from the SCSS pipeline.
   * Keep:

     * Desktop/Mobile toggle.
     * Same markup for the fake Pulse survey.

3. **State Management**

   * Keep using Zustand.
   * State should hold a `ThemeTokensLite` object instead of `SimpleTheme`.

---

### 9.6 What Cursor Should Implement in Phase 1

This is the concrete work Cursor should do:

1. **Introduce ThemeTokensLite**

   * Replace `SimpleTheme` in `src/types/theme.ts` with a `ThemeTokensLite` structure (similar to 9.2.1).
   * Update `themeStore.ts` to use this new type.
   * Update `ThemeEditor` to edit the new shape.

2. **Add SCSS Template**

   * Create `src/styles/theme-template-v1.scss`.
   * Move existing hardcoded styles for the fake survey into this file, but expressed with SCSS variables as in 9.3.

3. **Add SCSS Compilation Function**

   * Add a module (e.g. `src/theme/compileTheme.ts`) that:

     * Accepts `ThemeTokensLite`.
     * Generates a SCSS string that:

       * Sets SCSS variables based on the theme.
       * Imports `theme-template-v1.scss`.
     * Compiles it to CSS using `sass` (Dart Sass).
   * For Phase 1, this can run on the client or via a dev-time helper—Cursor can pick the simplest approach compatible with Vite.

4. **Wire Compilation to Preview**

   * Update `SurveyPreview` so it:

     * Uses the new compile function.
     * Injects the compiled CSS into the `iframe srcDoc`.
   * Remove any previous inline style generation logic.

5. **Keep DX Smooth**

   * Ensure I can still:

     * Run `npm install`
     * Run `npm run dev`
     * Edit theme values and see live changes in the preview.

---

### 9.7 Out of Scope for Phase 1

Phase 1 explicitly does **not** include:

* Full, comprehensive Theme Tokens schema from the long-term design.
* Integration with existing Pulse `sass-framework/01-css-pulse/` files.
* Express backend / API server.
* Playwright/Puppeteer analyzer.
* Theme Projects & persistence.
* URL analysis or automatic 4-theme generation.
* Style guide export.

Those belong in **Phase 2 and beyond**, once this SCSS + ThemeTokensLite path is solid.

---






## 10. Phase 2 – Theme Projects & Persistence

### 10.1 Goals for Phase 2

Phase 2 turns the playground into a **real tool**:

1. Introduce **Theme Projects**:

   * Each project holds one or more themes.
   * Projects can be named, selected, and created.
2. Add **local persistence**:

   * On refresh, projects and themes are restored.
   * No backend yet; use browser storage.
3. Keep the existing UX intact:

   * The current Theme Editor + Preview become “editing the active theme in the active project”.

No analyzer, no URL crawling, no style guide yet. Just “I can come back tomorrow and my stuff is still here, and I can keep variants per client”.

---

### 10.2 Data Model (Conceptual)

#### 10.2.1 ThemeProject

A Theme Project is a container for themes and basic metadata:

```ts
ThemeProject {
  id: string;              // uuid or similar
  name: string;            // e.g. "Visa.com", "Skechers CX"
  sourceUrl?: string;      // optional; used later for analyzer
  createdAt: string;       // ISO timestamp
  updatedAt: string;       // ISO timestamp
  themes: ThemeTokensLite[];
  activeThemeId: string;   // which theme is currently being edited
}
```

#### 10.2.2 App-level State

The global app state should look roughly like:

```ts
ThemeAppState {
  projects: ThemeProject[];
  activeProjectId: string | null;
}
```

On first load:

* If no saved data exists:

  * Create a **Default Project**:

    * `name = "Untitled Project"`
    * `sourceUrl = undefined`
    * `themes = [current default theme]`
    * `activeThemeId = id of that theme`
  * `activeProjectId` points to this project.

---

### 10.3 Persistence Strategy (v1)

For this phase, persistence should be **entirely client-side**:

* Use `localStorage` with a single key, e.g.:

  * `"pi-theme-generator-v3:projects"`
* Stored value:

  * JSON serialization of `ThemeAppState` (`projects` + `activeProjectId`).

Behavior:

* **On app load**:

  * Try to read from localStorage.
  * If valid data is found:

    * Hydrate app state from it.
  * If not:

    * Create the Default Project described above.

* **On any change** (project rename, theme edit, etc.):

  * Update in-memory Zustand store.
  * Persist updated state back to localStorage.

No server, no files, no external services.

---

### 10.4 UI Changes for Projects & Themes

#### 10.4.1 Project Selector

Add a simple **Project section** to the left sidebar (above the Theme Editor) or as a top-level bar. Minimal requirements:

* **Project dropdown or list**:

  * Shows all existing projects.
  * Selecting a project sets `activeProjectId`.
* **New Project button**:

  * Creates a new project.
  * Reasonable defaults:

    * Name: `New Project`, `Project 2`, etc.
    * `sourceUrl`: empty.
    * `themes`: one theme cloned from the currently active theme or from a base default theme.
* **Rename Project**:

  * Inline edit (click project name) or a small “Rename” action.

Delete project is optional for Phase 2; if easy, allow deletion with a confirmation guard.

#### 10.4.2 Theme Selector Within a Project

Within the active project, support:

* **List or tabs of themes**:

  * Each theme has:

    * Name (e.g. “Brand Faithful”, “Light Variant”, “Dark v2”).
  * Clicking a theme:

    * Sets `activeThemeId` for that project.
    * Theme Editor + Preview switch to that theme.

* **Actions**:

  * “New Theme”:

    * Creates a new theme in the project.
    * Can start from:

      * A blank default, or
      * A duplicate of the currently active theme (recommended).
  * “Rename Theme”:

    * Allows giving friendly names.
  * “Duplicate Theme”:

    * Shortcut for creating variations; duplicates tokens and appends “(Copy)” to the name.

Delete theme:

* Optional in Phase 2.
* If implemented, prevent deleting the last remaining theme in a project.

#### 10.4.3 Integration with Existing Editor & Preview

* `ThemeEditor`:

  * Reads and writes **the active theme** of the active project.
  * No UI change is required beyond showing the active theme name somewhere for clarity.

* `SurveyPreview`:

  * Receives the active theme.
  * Compiles SCSS → CSS exactly as in Phase 1.

---

### 10.5 State Management Changes (Zustand)

The existing Zustand store currently holds a single theme. Phase 2 should:

1. Replace that with `ThemeAppState`:

   * `projects: ThemeProject[]`
   * `activeProjectId: string | null`

2. Provide actions such as:

* `initializeFromStorage()`
* `createProject(name?: string)`
* `renameProject(projectId, newName)`
* `setActiveProject(projectId)`
* `createTheme(projectId)` (optionally from base or clone)
* `renameTheme(projectId, themeId, newName)`
* `duplicateTheme(projectId, themeId)`
* `setActiveTheme(projectId, themeId)`
* `updateThemeTokens(projectId, themeId, partialTokens)`
* `persist()` (internal, called after every state change)

The exact signatures are up to Cursor; they just need to cover these behaviors.

`ThemeEditor` should call `updateThemeTokens` instead of directly mutating a simple theme.

---

### 10.6 What Cursor Should Implement in Phase 2

Concretely, for implementation:

1. **Introduce ThemeProject & ThemeAppState**

   * Define the types/interfaces near the existing theme types.
   * Update the Zustand store to use `ThemeAppState` instead of a single theme.

2. **Add LocalStorage Persistence**

   * Implement load-on-startup and save-on-change logic using a key like:

     * `"pi-theme-generator-v3:projects"`.

3. **UI for Project Selection**

   * Add a small UI element for:

     * Viewing current project name.
     * Selecting between projects.
     * Creating a new project.
     * Renaming the current project.

4. **UI for Theme Selection per Project**

   * Add a theme list or tabs for:

     * Viewing themes in the active project.
     * Selecting active theme.
     * Creating / duplicating themes.
     * Renaming themes.

5. **Wire Editor & Preview to Active Theme**

   * Ensure `ThemeEditor` and `SurveyPreview` always operate on:

     * The active theme of the active project.
   * Keep SCSS compilation exactly as in Phase 1.

6. **Maintain Developer Experience**

   * Ensure the app still runs with:

     * `npm install`
     * `npm run dev`
   * Confirm that:

     * After refreshing the page, projects and themes persist.

---

### 10.7 Out of Scope for Phase 2

Phase 2 intentionally does *not* add:

* URL analysis / Playwright
* Automatic 4-theme generation
* Style guide view
* Export to file/Markdown
* Integration with real Pulse SCSS framework

Those remain for Phase 3+.

---








## 11. Phase 3 – Analyzer & Auto Theme Generation

### 11.1 Goals

Phase 3 should let me:

1. Pick a project and **enter a URL** (e.g. `https://www.skechers.com`).
2. Click an **“Analyze & Generate Themes”** button.
3. Behind the scenes:

   * A **Node/Express + Playwright** analyzer loads the site.
   * Extracts **basic colors + fonts** into a `SiteSnapshot`.
   * Converts that snapshot into **4 ThemeTokensLite themes**:

     * Brand Faithful
     * Light
     * Dark
     * Minimal
4. The 4 new themes appear in the project’s theme list and can be edited like any other theme.

No AWS/GCP deployment yet. This is still a **local dev-only backend**.

---

### 11.2 Backend: Local Analyzer Service

Add a small backend in the same repo:

* Technology:

  * Express + TypeScript (as previously recommended).
  * Playwright for browser automation.
* Dev usage:

  * Started with a script like `npm run dev:server` or integrated into `npm run dev` (Cursor’s choice).
* Endpoint:

  * `POST /api/analyze-site`

    * Request body:

      ```json
      {
        "url": "https://example.com",
        "maxPages": 1
      }
      ```

      * For Phase 3, `maxPages` can default to `1`. Multi-page comes later.
    * Response body:

      ```json
      {
        "snapshot": { ... },
        "themes": [ /* 4 ThemeTokensLite objects */ ]
      }
      ```

#### 11.2.1 SiteSnapshot (MVP)

Keep it small and practical. Something like:

```ts
SiteSnapshot {
  url: string;
  pageTitle?: string;
  detectedColors: {
    background: string;       // body background
    surface?: string;         // card / panel bg (if detected)
    textPrimary: string;
    textSecondary?: string;
    brandPrimary?: string;    // from buttons/links
    brandSecondary?: string;
    accent?: string;
  };
  typography: {
    bodyFontFamily: string;   // from body / main
    headingFontFamily: string;// from h1/h2, fallback to body
    baseFontSizePx: number;   // from computed body font-size
  };
}
```

**Extraction rules (high level, Cursor handles details):**

* Load the page in **desktop viewport** for now.
* Colors:

  * `background`: computed `background-color` of `body` or main container.
  * `textPrimary`: computed `color` of `body`.
  * `brandPrimary`: pick dominant color from:

    * Primary buttons (e.g. `<button>`, `.btn-primary`, etc.).
    * Or from prominent links if no buttons.
* Typography:

  * `bodyFontFamily`: computed `font-family` on `body`.
  * `headingFontFamily`: computed `font-family` on first visible `h1`/`h2`.
  * `baseFontSizePx`: computed `font-size` on `body`.

We’re not chasing perfection here; just a decent first guess.

---

### 11.3 From SiteSnapshot → 4 ThemeTokensLite

Define a small **Theme Generation module** on the backend, e.g. `generateThemesFromSnapshot.ts`.

Input:

* `SiteSnapshot`

Output:

* `ThemeTokensLite[]` (array of 4 themes):

  * `"Brand Faithful"`
  * `"Light"`
  * `"Dark"`
  * `"Minimal"`

Use the existing **ThemeTokensLite** shape from Phase 1/2 (do not blow it up; reuse what you have).

**Guidelines for each variant:**

1. **Brand Faithful**

   * Background: use snapshot background.
   * Surface: slightly lighter or darker than background.
   * Text primary: snapshot textPrimary.
   * Brand primary: snapshot brandPrimary (fallback to link color or a contrasting neutral).
   * Keep overall vibe close to the site.

2. **Light**

   * Background: very light neutral (`#ffffff` or near).
   * Surface: light neutral like `#f9fafb`.
   * Text primary: dark neutral (`#111827`).
   * Brand primary: snapshot brandPrimary.
   * Emphasize readability and clean contrast.

3. **Dark**

   * Background: dark neutral (`#0f172a` style).
   * Surface: slightly lighter dark (`#111827`).
   * Text primary: white.
   * Brand primary: snapshot brandPrimary (possibly brightened).
   * Make sure single-choice & CTA tokens keep strong contrast.

4. **Minimal**

   * Background: white or very light.
   * Surface: white/light with subtle border.
   * Text primary: dark neutral.
   * Brand primary: used sparingly (CTA + single-choice active).
   * Everything else very neutral, for high clarity.

You don’t need fancy color math yet—simple lightening/darkening is fine. The important part is: each theme is a **valid, fully populated ThemeTokensLite** that the existing UI and SCSS template can consume.

---

### 11.4 Frontend Changes

#### 11.4.1 Project URL & Analyze Controls

In the **Projects panel**:

* Add a `Source URL` field per project:

  * Simple text input under the project name.
* Add a button:

  * **“Analyze & Generate Themes”**
  * When clicked:

    * Validates that URL is non-empty.
    * Calls `POST /api/analyze-site` with:

      * `url = project.sourceUrl`
      * `maxPages = 1` (for now).
    * On success:

      * Adds the returned 4 themes to the project’s `themes` array.
      * Sets the first generated theme as `activeThemeId`.

Optionally, show a **small loading state** while the analysis is running.

#### 11.4.2 Theme Variant Label

In the Themes panel:

* Display each theme’s `variantType` (if present):

  * `brand-faithful`, `light`, `dark`, `minimal`, `custom`
* For manually edited themes, `variantType` can remain `"custom"`.

---

### 11.5 State / Types Adjustments

Ensure `ThemeTokensLite` includes:

* `id`
* `name`
* `variantType: "brand-faithful" | "light" | "dark" | "minimal" | "custom"`

If any of these are missing, Cursor should add them in a minimal way without breaking existing UI.

`ThemeProject` should already have `sourceUrl?`; if not, it should be added now.

---

### 11.6 What Cursor Should Implement in Phase 3

1. **Backend analyzer service**

   * Add Express + TypeScript server to the repo.
   * Install and configure Playwright.
   * Implement `POST /api/analyze-site`:

     * Uses Playwright to load the URL.
     * Builds a `SiteSnapshot`.
     * Generates 4 `ThemeTokensLite` themes.
     * Returns `{ snapshot, themes }`.

2. **Wire analyzer to frontend**

   * Add `sourceUrl` field to projects in state.
   * Add UI in Projects panel:

     * URL input
     * “Analyze & Generate Themes” button.
   * On click, call the backend and merge the new themes into the current project.

3. **Integrate with existing Theme system**

   * Ensure generated themes:

     * Conform to ThemeTokensLite (no missing fields).
     * Work with the SCSS template & preview without changes.
   * Set the first generated theme as active so the user instantly sees results.

4. **Developer experience**

   * Update `package.json` scripts so it’s easy to run both:

     * Frontend dev server
     * Backend analyzer
   * Document in the README:

     * How to start the analyzer-enabled dev environment.
     * Example URL to test.

---

### 11.7 Out of Scope for Phase 3

* Multi-page analysis (`maxPages > 1`)
* Advanced color clustering / palette extraction
* Mobile-specific style detection
* Style Guide view
* Export to Markdown/HTML
* Cloud deployment (Cloud Run / Lambda)

All of that can come once the single-page analyzer → 4 themes loop is stable and pleasant.

---






## 11.5 Phase 3.5 – UX Refinements & Layout Upgrade

### 11.5.1 Goals

Phase 3.5 improves the **day-to-day usability** and visual clarity of the Theme Generator without altering core logic. It transitions the tool from a narrow form-driven interface into a more mature **design environment** by refining layout, preview behavior, and palette selection.

This phase includes **no backend changes**, no modifications to the analyzer, and no alterations to ThemeTokensLite. It is strictly a **UX and layout enhancement** layer on top of existing capabilities.

---

### 11.5.2 Source URL UX Improvements

**Change:**
When creating a new project—or when the Source URL field is empty—prepopulate the field with:

```
https://www.
```

**Rules:**

* Do **not** overwrite user input if the field already contains data.
* If the user clears the field, placeholder text may reappear, but the value should not be forcibly reinserted.

---

### 11.5.3 Full-Width Application Layout

The application should adopt a **full-width, design-tool style layout** to better support present and future workflows.

**High-level structure:**

* **Top Bar:** Project name, Source URL input, Analyze button.
* **Left Panel (fixed width):**

  * Project selector
  * Theme selector
  * Theme Editor (grouped sections)
* **Right Panel (flex width):**

  * Preview area (Desktop + Mobile)
  * Context Mode toggle (Clean vs. Screenshot)

This creates clear separation between “editing tools” and “visual output.”

---

### 11.5.4 Independent Scrolling for Editor and Preview

To avoid constant scrolling up/down:

* The **left panel** (projects, themes, editor) has its own vertical scroll.
* The **right panel** (preview) has its own vertical scroll.
* The top bar should remain visible or quickly accessible.

This lets users tweak parameters and see results instantly without losing their place.

---

### 11.5.5 Dual Preview: Desktop & Mobile Simultaneous View

Instead of forcing the user to toggle between Desktop and Mobile:

* Show **both previews at once**.

**Responsive behavior:**

* **Wide screens:** Desktop and Mobile appear side-by-side.
* **Narrow screens:** Desktop and Mobile stack vertically.

Both previews:

* Use the same CSS/SCSS pipeline.
* Update in real time as the theme changes.

---

### 11.5.6 Context Mode Preview (Homepage Screenshot Background)

Add a toggle in the preview header:

```
Preview Mode:  [ Clean ]  [ Context ]
```

#### **Clean Mode (default):**

* Neutral background.
* Widget is primary focus.
* Best for theme editing.

#### **Context Mode (new):**

* Show a **homepage screenshot** (from the analyzed URL) as the preview background.
* Overlay the Desktop and Mobile widgets on top of the screenshot.

Constraints for Phase 3.5:

* The screenshot mechanism may be basic (saved during analysis, or captured via Playwright).
* No full live-site embedding yet.
* Screenshot should not visually overwhelm the widget; optional dimming/blur is acceptable.

Goal:
Give the user a “theme in context” feel without complicating the feature.

---

### 11.5.7 Improved Palette UX: Extracted Colors + Custom Overrides

For color-editing fields in the Theme Editor:

* If the analyzer extracted colors from the site, show them as **selectable preset options**.
* Always include a **“Custom color…”** button that opens the standard color picker.

This provides:

* Guided color selection for brand alignment,
* Full freedom for power users.

Fallback:
If no extracted colors exist, show the standard color picker by default.

---

### 11.5.8 Editor Visual Grouping & Collapsing

Because the left-side editor may become long:

* Group Theme Editor fields into logical sections:

  * Palette
  * Typography
  * Widget
  * CTA
  * Single Choice
  * Layout (border radius, spacing)
* Use **accordions/collapsible sections**.
* Keep visual clarity and reduce vertical scroll pressure.

No new theme fields are added; this is purely structural.

---

### 11.5.9 Out of Scope for Phase 3.5

This phase does **not** change:

* Backend analyzer
* SCSS template semantics
* Style Guide content
* ThemeTokensLite
* Any cloud deployment strategy

It is exclusively focused on layout, interaction, and preview UX.

---







## 11.7 Phase 3.7 – Improved Color Extraction

### 11.7.1 Goals

Phase 3.7 improves the **accuracy, stability, and usefulness of automatic theme generation** by upgrading the color extraction logic in the analyzer.

The current detection is intentionally minimal (pulling only `<body>` colors, text, and simple accents), which results in incorrect palettes for highly designed modern websites.

Phase 3.7 introduces **multi-page crawling**, **CSS variable extraction**, and **component-based color sampling** so the generated themes reflect true brand identity across a wider range of sites.

This phase modifies the analyzer **only**.
ThemeTokensLite, SCSS templates, UI, and UX remain unchanged.

---

### 11.7.2 Multi-Page Crawling (MVP)

The analyzer should inspect **multiple pages** (2–3) rather than the homepage alone. This reduces “hero randomness” and stabilizes palette detection.

**Target pages (in order):**

1. **Homepage (`/`)**
2. **Category or Collection Page**

   * Automatically detect by:

     * First `<a>` tag with “/collections”, “/category”, “/shop”, “/products”
     * Or fallback to the first internal link.
3. **Product Page (optional but ideal)**

   * Find first link that matches:

     * `/product/`, `/p/`, `/item/`, `/sku/`

**Constraints:**

* Analyze a maximum of **3 pages** per run.
* If URLs are protected, skip gracefully.
* Use Playwright’s navigation with:

  * `waitUntil: "domcontentloaded"`
  * Desktop viewport

---

### 11.7.3 CSS Variable Extraction (Critical)

Modern sites often define brand colors in CSS variables:

```css
:root {
  --brand-primary: #1a4ed8;
  --color-primary: #ff0000;
  --brand-accent: #f97316;
}
```

Playwright evaluator should:

1. Read all computed style properties from `document.documentElement`
2. Collect any variables matching patterns:

```
--brand-*
--color-*
--primary-*
--accent-*
--theme-*
```

3. Store these values in `snapshot.detectedColors.cssVariables`.

**Brand Primary Selection Rule:**

* Prefer `--brand-primary`, then `--primary`, then the most saturated variable.

---

### 11.7.4 Button & Link Style Extraction (High Impact)

Most brand colors appear on interactive elements rather than backgrounds. Extract colors from:

* `<button>`
* `.btn`, `.button`, `.primary-button`
* Large link CTAs (`a[href]`) with:

  * High contrast
  * Non-neutral colors
  * Bold/large font sizes

For each element, capture:

* `background-color`
* `color`
* `border-color`

Keep a tally across all analyzed pages.

---

### 11.7.5 Logo Color Sampling (Optional but Valuable)

If the site logo is an `<img>` tag or `<picture>`:

* Capture the screenshot already taken in Phase 3.5.
* Sample the **top-left 300×200 px region** (or a smaller area).
* Extract the dominant color using simple pixel clustering (e.g., K-means with 3 clusters).

Use this color as a **strong vote for brandPrimary** if it’s not black/white/gray.

Skip if sampling fails.

---

### 11.7.6 Background & Surface Extraction (More Reliable)

For each page:

Collect background colors from:

* `<body>`
* `.header`, `.nav`, `.footer`
* First visible “hero-like” container (non-transparent, large height)

Keep track of the **most frequent background** and **most frequent surface**.

Derive:

* `background` = lightest neutral or most common
* `surface` = second-most common neutral or slightly lighter/darker

---

### 11.7.7 Build a Weighted Palette (Key Step)

Combine colors from:

* CSS variables
* Buttons/links
* Logo sampling
* Backgrounds/surfaces

Then:

1. **Cluster into groups:**

   * Neutrals (light → dark)
   * Brand hues (most saturated)
   * Accents (unique hues)
2. **Pick final palette:**

   * `background` → neutral cluster center
   * `surface` → second neutral cluster
   * `textPrimary` → whichever neutral has best contrast against background
   * `brandPrimary` → highest weighted brand hue (CSS variable > button color > logo > link)
   * `brandSecondary` → next distinct brand hue or refine via saturation
   * `accent` → distinct non-brand color with medium saturation
   * `success`/`danger` → defaults from existing generator

This creates stable, reliable palettes.

---

### 11.7.8 Final Output for ThemeTokensLite

From the weighted palette, map to ThemeTokensLite fields:

* palette.background
* palette.surface
* palette.textPrimary
* palette.textSecondary (neutral)
* palette.brandPrimary
* palette.brandSecondary
* palette.accent
* palette.success / palette.danger (unchanged)

Typography (fonts, sizes) extracted from Phase 3 remains unchanged.

---

### 11.7.9 What Cursor Should Implement in Phase 3.7

1. **Multi-page crawler**

   * Collect 2–3 pages per analysis.
   * Graceful fallbacks.

2. **CSS variable extractor**

   * Capture `--brand-*`, `--primary-*`, etc.

3. **Button/link sampler**

   * Extract colors from real UI elements.

4. **Logo sampler (optional MVP)**

   * Basic clustering on screenshot data.

5. **Background/surface extractor**

   * From body/header/footer/hero layers.

6. **Weighted palette builder**

   * Cluster and prioritize extracted colors.
   * Create final palette used by ThemeTokensLite.

7. **No changes to:**

   * ThemeTokensLite structure
   * Backend endpoints
   * SCSS system
   * UI / layout

This phase strictly improves the underlying **intelligence** of the analyzer without altering its public contract.

---

### 11.7.10 Out of Scope for Phase 3.7

* Multi-device (mobile/tablet) extraction
* Advanced ML-based palette extraction
* Style similarity detection
* Typography clustering
* Iconography extraction
* Dark/light mode auto-switching

These belong to Phase 5+.

---











## 11.9 Phase 3.9 – Brand Color Refinement (Logo Sampling + Priority Model)

### 11.9.1 Goals**

Phase 3.9 strengthens brand color detection by introducing two high-leverage improvements:

1. **Actual logo color sampling** from homepage screenshots
2. **A unified color priority model** that reorders and harmonizes palette selection

This significantly increases accuracy for ecommerce and enterprise sites whose brand identity lives primarily in:

* their **logo**,
* their **header/navigation**,
* and **button/link emphasis** rather than page backgrounds.

This phase focuses **only** on the analyzer.
No changes are made to ThemeTokensLite, SCSS templates, the UI, or Theme Editor.

---

### 11.9.2 Real Logo Color Sampling (Dominant Hue Extraction)**

The analyzer currently includes a placeholder for logo sampling.
Phase 3.9 implements a real extraction flow.

**Source of Truth:**
Use the homepage screenshot generated in earlier phases.

**Sampling Region:**

Scan only the **header/logo zone**, not the full screenshot.

Recommended bounding box:

* From the top of the screenshot
* Height: ~200–300 px
* Width: 100% of page
* Then identify the densest non-neutral area (to avoid white nav bars)

**Processing Steps:**

1. Convert the region into an array of pixel RGB values.
2. Apply lightweight k-means or median-cut clustering:

   * Use **3 clusters** (brand-safe, memory-light)
3. Remove grayscale/near-neutral clusters:

   * saturation < 0.15 → drop
4. Select the **dominant saturated color** as `logoDominantColor`.

**Validation:**

* If the logo color is excessively bright (e.g., #ffffff, #dddddd), ignore it.
* If it’s too dark (~#000000), keep it only if the site truly uses black logos.
* If it fails extraction, return `undefined` silently.

**Output:**
Add a new field to snapshot:

```ts
snapshot.detectedColors.logo?: string;
```

---

### 11.9.3 CSS Variable Enhancement (Header & Component Scope)**

Expand CSS variable extraction beyond `:root`:

* Inspect declarations on:

  * `header`
  * `.header`, `.global-header`, `.site-header`
  * `.theme`, `[data-theme]`
  * `.nav`, `.navbar`, `.top-nav`
  * `.site-branding`, `.branding`

Across each, extract variables matching:

```
--brand-*
--primary-*
--accent-*
--theme-*
--color-*
```

Results should merge into the same structure used in Phase 3.7.

This improves accuracy for:

* Tailwind-based sites
* Shopify themes with scoped tokens
* Component-driven design systems

---

### 11.9.4 High-Priority CTA / Navigation Detection**

Brand colors often appear on:

* Primary CTAs (“Shop Now”, “Buy”, “Learn More”, etc.)
* Navigation hover/focus states
* Announcement bars

Phase 3.9 should:

1. Detect elements with attributes like:

   * `[class*="primary"]`
   * `[class*="cta"]`
   * `[class*="nav"]`
   * `.active`
2. Sample:

   * background color
   * text color
   * border color (if visible)
3. Boost frequency weights for these samples

   * CTA colors × 1.5
   * Nav colors × 1.2

This improves brandPrimary consistency across pages.

---

### 11.9.5 Brand Color Priority Model (New Selection Algorithm)**

Phase 3.7 aggregated colors well, but still had cases where:

* neutrals overwhelmed brand colors
* hero background hues were mistaken for brand hues
* brandSecondary sometimes became random

Phase 3.9 introduces a **strict priority model** for the final palette:

### Brand Primary (descending order of priority)

1. **CSS Variables**

   * `--brand-primary`
   * `--primary`
   * `--color-primary`
2. **Logo dominant color**
3. **CTA button background colors**
4. **CTA text or border colors (fallback)**
5. **High-saturation accent colors from hero/links**

### Brand Secondary

1. Any remaining CSS variable colors
2. Second-highest saturation cluster
3. Navigation hover/focus colors
4. Secondary CTA colors
5. Distinct hue from brandPrimary (Δ hue > 30°)

### Accent

1. Distinct non-brand hue with mid-high saturation
2. Secondary CTA or highlight colors
3. Link hover colors
4. Bright or warm hues in hero sections (if consistent across pages)

### Background / Surface

As defined in Phase 3.7 (unchanged):

* background → light neutral cluster
* surface → second neutral cluster

### Text Primary

* Select neutral color with **WCAG 4.5:1** contrast against background.
* Fallback: #000000 or #ffffff depending on contrast.

---

### 11.9.6 Palette Stability Thresholds**

Phase 3.7 introduced clustering and weighting.
Phase 3.9 adds *stability thresholds*:

1. A color must appear in **≥ 2 pages** to be considered for brandPrimary.
2. A color must pass **contrast checks** against both:

   * background
   * surface
3. A brandSecondary cannot be:

   * Too close to brandPrimary (ΔE < 12)
   * Too close to textPrimary
4. Neutral palette is considered “valid” only if:

   * At least 4 distinct neutral luminance values exist
   * Otherwise, generate a neutral ramp algorithmically

If thresholds fail:

* Use CSS variables if available
* Then use logo color
* Then use CTA colors
* Finally, use fallback neutrals

---

### 11.9.7 Output for ThemeTokensLite (No Structural Changes)**

All computed colors should map into existing fields:

* palette.background
* palette.surface
* palette.textPrimary
* palette.textSecondary
* palette.brandPrimary
* palette.brandSecondary
* palette.accent
* palette.success / palette.danger (unchanged)

Typography, spacing, layout, and SCSS behavior remain untouched.

---

### 11.9.8 What Cursor Should Implement in Phase 3.9**

1. **Implement real logo color sampling**

   * Use screenshot region
   * Extract dominant saturated hue
   * Add `snapshot.detectedColors.logo`

2. **Expand CSS variable search to header/nav/theme scopes**

3. **Improve CTA/nav color sampling**

   * Add priority weights for CTA and nav colors

4. **Implement the Brand Color Priority Model**

   * Centralize selection logic in paletteBuilder
   * Apply new priority flow (CSS vars → logo → CTAs → links → others)

5. **Add palette stability thresholds**

   * Multi-page consistency requirement
   * Hue difference checks
   * Neutral fallback ramp if needed

6. **Maintain all existing API shapes and outputs**

   * No changes to ThemeTokensLite
   * No changes to preview or SCSS system
   * No endpoint changes

Only analyzer internals should change.

---

### 11.9.9 Out of Scope for Phase 3.9**

* Deep screenshot palette clustering
* Mobile-specific extraction
* Typography clustering
* Font weight extraction
* Edge embedding preview
* AI-guided palette smoothing
* Multi-device rendering awareness

These belong to Phase 4+.

---

















## 11.95 Phase 3.95 – Bugfixes & UX Polish (Color Presets, Widget Wiring, Sharp Fix)

### 11.95.1 Goals

Phase 3.95 focuses on eliminating friction and repairing gaps introduced during Phases 3.5–3.9. It is not a feature phase — it is a **refinement and correctness** phase.

This addresses:

1. **Preset fatigue** — too many clicks required to reveal presets  
2. **Preset inconsistencies** — fewer presets than the Style Guide shows  
3. **Widget tokens not affecting preview** — SCSS/template wiring issue  
4. **Sharp screenshot errors** — analyzer struggling to decode PNG buffers  

This phase ensures the core experience feels clean, responsive, and trustworthy before moving to Phase 4.

---

### 11.95.2 Preset Color Improvements

#### **Problem**
- Every color input requires clicking **“Show Presets”** individually.  
- This becomes repetitive and slows down theme editing.  
- Presets in the editor do **not match** the palette shown in the Style Guide.

#### **Changes**

##### **A. Palette Section: Presets Always Visible**
- In the **Palette** collapsible section:
  - Presets should be **always visible**, without a per-field toggle.
  - Show presets as small color chips organized into groups:
    - Brand Primary, Secondary, Accent  
    - Neutrals (background/surface/textSamples)  
    - Additional extracted colors (optional, lightly styled)

##### **B. Other Sections: Minimal Preset UI**
- In other sections (CTA, Single Choice, Widget):
  - Replace “Show Presets” with a small dropdown:
    - “Use palette color…” → list of brand/background/accent tokens
  - Or show presets inline only when the Palette section is expanded.

This maintains power while reducing clutter.

##### **C. Preset Source of Truth**
Presets shown in the editor should come from:

1. **ThemeTokensLite palette values** (always present)  
2. **detectedColors** (CSS variables, logo, CTA) as “suggestions”  

This ensures parity with the Style Guide.

---

### 11.95.3 Widget Token Wiring Fix

#### **Problem**
- Changing `widget.*` tokens produces no visual effect in the preview.
- Indicates missing or incomplete wiring in:
  - SCSS template  
  - theme→SCSS variable injection  
  - preview HTML structure  
  - OR a mismatch in classnames  

#### **Changes**

Cursor should:

1. **Identify all widget-related tokens** in `ThemeTokensLite.components.widget.*`
2. **Trace their mapping** into generated SCSS variables  
3. **Verify template classnames** match preview HTML classes:
   - `.pi-widget`
   - `.pi-widget-header`
   - `.pi-widget-body`
   - `.pi-widget-border`
   - `.pi-widget-overlay`
4. **Implement a unit sanity check** (manual or visual):
   - Temporarily set headerBg to a bright color via theme override
   - Confirm preview updates accordingly
5. Fix:
   - Missing variable injection  
   - SCSS rules referencing wrong variables  
   - Preview HTML missing necessary structure or classes  

After this phase, modifications to `widget.*` tokens should clearly update:

- Widget header background & text
- Widget body background & text
- Border color
- Overlay color (if present)

---

### 11.95.4 Sharp “Unsupported Image Format” Fix

#### **Problem**
Analyzer logs show:

```
Sharp cannot read screenshot format: Input buffer contains unsupported image format
```

This indicates the buffer passed to Sharp is not a raw PNG buffer.

Common causes:
- Passing a **base64 data URL string** instead of stripping headers  
- Using Playwright screenshot defaults that produce a format unsupported by sharp  
- Accidentally serializing the buffer as JSON  

#### **Required Fixes**

Cursor should:

1. Ensure Playwright captures screenshot as:

```ts
page.screenshot({ type: 'png' })
```

2. Ensure screenshot is a **raw Buffer**, not base64 unless explicitly converted.

3. If a base64 string is used:
   - Strip prefix `data:image/png;base64,`
   - Convert with `Buffer.from(base64, 'base64')`

4. Ensure the screenshot from the crawler is **not JSON-stringified** before Sharp receives it.

5. Add safe error logging:
   - If buffer is invalid, skip logo sampling and continue analysis cleanly.

Outcome:
- Logo sampling becomes reliable  
- No more Sharp errors in logs  
- `snapshot.detectedColors.logo` becomes meaningful

---

### 11.95.5 Out of Scope

- No changes to ThemeTokensLite
- No changes to analyzer endpoints
- No SCSS template restructuring beyond wiring fixes
- No changes to color priority model
- No UI redesign beyond preset behavior

This phase is purely corrective.

---














## **12. Phase 4.0 – Canvas Modes (Edit | Interact) & Core Canvas Shell**

### **12.1 Goals**

Phase 4.0 evolves the Theme Designer from a “preview + form editor” into a **true design environment** with explicit modes of interaction:

1. Introduce **Canvas modes**:
   - **Edit** – design & configuration mode
   - **Interact** – realistic survey behavior mode
2. Standardize the **Canvas shell**:
   - Clear top navigation
   - Device selector (Desktop / iPhone / Android)
   - Integration with existing Context Mode (Clean / Context)
3. Prepare the Canvas for future phases:
   - Layer selection & layer inspector (Phase 4.1)
   - Template version selection / Advanced Config (Phase 4.2)
   - Enhanced Style Guide and token manager (Phase 4.3+)

Critically, Phase 4.0 **does not** change ThemeTokensLite, the analyzer, or the SCSS pipeline. It is about **interaction model and layout**, not new data structures.

---

### **12.2 Canvas-Level Information Architecture**

Phase 4.0 establishes the main working areas of the app as top-level tabs:

- **Canvas** – the primary visual editing surface  
- **Layers** – structured layer tree & inspector (Phase 4.1 will fill this in)  
- **Style Guide** – theme documentation (already present, enhanced later)

Tabs sit below the app header and span the full width of the right panel.

Example:

```text
[ Canvas ]   [ Layers ]   [ Style Guide ]
-----------------------------------------
|                                         |
|  (canvas content here, depending on    |
|   active tab and mode)                 |
```

Phase 4.0 focuses on the **Canvas** tab only. Layers and Style Guide remain as-is for now and will be upgraded in Phases 4.1+.

---

### **12.3 Canvas Modes: Edit | Interact**

Inside the **Canvas** tab, Phase 4.0 introduces a **mode toggle** that controls how the widget behaves:

```text
Canvas Mode:  [ Edit ]  [ Interact ]
```

#### **12.3.1 Edit Mode (Design Mode)**

In **Edit** mode:

- The widget is treated as a **design surface**, not an interactive survey.
- Clicking inside the widget will **not**:
  - Move focus into text input
  - Trigger navigation logic
  - Submit the form
- Instead, Edit mode prioritizes:
  - Visual feedback
  - Future layer selection (Phase 4.1)
  - Future layer inspector popovers
  - “Designer”-style manipulations

For Phase 4.0 specifically:

- Existing editor controls (theme selection, palette inputs, typography inputs) remain in the left panel.
- The widget responds visually to changes from the left panel (as it does now).
- **No complex layer selection is required yet** – that arrives in Phase 4.1.
- We may implement **basic hover outlines** for whole-widget regions (e.g. widget container, question area, controls area) as a visual hint of where layer-based editing will go next.

#### **12.3.2 Interact Mode (Simulation Mode)**

In **Interact** mode:

- The widget behaves like a **real survey**:
  - Clicking options changes their state
  - Inputs can be focused and typed into
  - Submit button can be clicked (either no-op or simulated behavior)
- All Edit-only affordances disappear or are disabled:
  - No hover outlines
  - No layer selection
  - No layer inspector popovers

This mode exists to:

- Let designers/CSMs verify the **actual experience** of the survey.
- Provide a client-demo-friendly, realistic view.
- Support future QA workflows.

Switching between modes is instantaneous; the underlying theme remains the same.

---

### **12.4 Canvas Layout & Device Selection**

The **Canvas** tab uses a centered layout similar to the Figma exploration:

- A large neutral background (e.g. light gray canvas).
- A **single device view at a time** (for Phase 4.0):
  - Desktop
  - iPhone
  - Android

#### **12.4.1 Device Selector**

On the right side of the Canvas header (within the Canvas tab):

```text
Devices:  [ Desktop ]  [ iPhone ]  [ Android ]
```

Behavior:

- Only one device preview is shown at a time.
- Clicking a device:
  - Switches the preview template to the correct combination of:
    - widgetType
    - questionType
    - deviceType
  - Keeps the same active theme / tokens.
- In **Edit** mode, device switches allow designers to fine-tune per device.
- In **Interact** mode, device switches allow simulation of experience across devices.

(Phase 4.2 will introduce the full template versioning and configuration per widget/question/device; in 4.0, we just establish the selector and single-preview behavior.)

---

### **12.5 Integration with Context Mode (Clean | Context)**

Context Mode (from Phase 3.5) remains available in the Canvas header when in **Canvas** tab:

```text
Context:  [ Clean ]  [ Context ]
```

- **Clean**:
  - Neutral background behind the widget.
  - Best for focusing on structure and chroma of the theme.
- **Context**:
  - Homepage screenshot as the background.
  - Widget floats over that screenshot.
  - Background can be dimmed or blurred (as already implemented).

Mode interactions:

- Both **Edit** and **Interact** modes should respect Context Mode:
  - In Edit + Context → designer tweaks colors while seeing site context.
  - In Interact + Context → simulate real experience on client’s page.

Phase 4.0 only ensures **proper layout and state wiring** between:
- Canvas Mode (Edit/Interact)
- Context Mode (Clean/Context)
- Device selection

---

### **12.6 Left Panel & Theme Editor (No Structural Change Yet)**

In Phase 4.0:

- The **left panel** remains structurally the same:
  - Projects list
  - Themes list
  - Theme Editor sections (Palette, Typography, Widget, CTA, Single Choice, Layout)
- The panel continues to:
  - Control ThemeTokensLite values.
  - Drive SCSS compilation & preview.
- Any minor visual adjustments needed to harmonize with the Canvas header are allowed (e.g., aligning labels, spacing).

Phases 4.1+ will add:

- Tight coupling between selected Canvas layer and corresponding editor section.
- Potential “jump to token” behavior when a layer is selected.

---

### **12.7 State & Implementation Notes**

- Canvas mode (`edit` vs `interact`) should be stored in global UI state (e.g., Zustand or React context).
- Device selection and Context Mode should also live in shared UI state so they are:
  - Available to the preview component
  - Potentially serialized with Theme Projects in the future (optional)
- When switching modes:
  - The preview component should be able to adjust:
    - Pointer event handling
    - Focus behavior
    - Whether click handlers are attached for survey logic vs. layer editing
- At this phase, **no new data model fields are required**.

---

### **12.8 Out of Scope for Phase 4.0**

Phase 4.0 is explicitly **not** responsible for:

- Full **Layer system** (semantic layer definitions, layer list, full Layer Inspector).  
  - This is Phase 4.1.
- **Template versioning** and full Advanced Configuration modal.  
  - This is Phase 4.2.
- Any changes to:
  - ThemeTokensLite structure
  - Analyzer logic
  - SCSS template semantics
  - API contract

Phase 4.0 is about **interaction modes and the Canvas shell**, preparing a solid foundation for the richer layer/editing and template features in later phases.

---








## **12.1 Phase 4.1 – Layer System & Layer Inspector**

### **12.1.1 Goals**

Phase 4.1 introduces a **semantic Layer system** and **Layer Inspector** so that in **Edit mode** designers can:

1. Hover and select individual visual elements (“layers”) in the widget.
2. See which theme tokens control that layer.
3. Quickly apply colors from a centralized brand palette (and later font/spacing tweaks).
4. Navigate the widget structure via a **Layers tab** that mirrors the Canvas.

This phase is the first step toward “Photoshop/Sketch-style editing” of the widget. It does **not** change ThemeTokensLite’s shape, analyzer logic, or SCSS semantics; it only adds semantic metadata and new UI.

---

### **12.1.2 Layer Model & Data Structures**

Introduce a **Layer model** that is independent of HTML implementation.

#### **Type Definitions (Conceptual)**

```ts
type DeviceType = "desktop" | "mobile";

type WidgetType = "docked" | "inline" | "top-bar" | "bottom-bar" | "modal";

type QuestionType = "single-choice" | "multi-choice" | "slider" | "nps" | "free-text";

type TokenPath = string; // e.g. "components.ctaButton.default.bg"

interface LayerTokenMapping {
  tokenPath: TokenPath;          // Which ThemeTokensLite field(s) this layer uses
  role: "background" | "text" | "border" | "icon";
}

interface LayerDefinition {
  id: string;                    // "cta-button-bg"
  displayName: string;           // "CTA Button – Background"
  selector: string;              // e.g. "[data-layer='cta-button-bg']"
  mappings: LayerTokenMapping[]; // token paths + roles
  group: "widget" | "question" | "controls"; // for Layers tab grouping
}
```

LayerDefinitions will later be attached to preview templates (Phase 4.2), but in 4.1 we can start with a small set for the current preview.

**Initial layer set (for single-choice, docked widget):**

- **Widget**
  - `widget-container` → widget container / card
  - `widget-header` → title bar
  - `widget-body` → body background
- **Question**
  - `single-choice-default` → unselected option
  - `single-choice-active` → selected option
- **Controls**
  - `cta-button-bg` → submit button background
  - `cta-button-text` → submit button text
  - `text-input-border` → free-text border
  - `text-input-text` → free-text text

Each maps to one or more ThemeTokensLite paths, e.g.:

- `widget-container` → `components.widget.bodyBg`, `components.widget.bodyFg`
- `single-choice-default` → `components.singleChoice.default.bg`, `.fg`, `.border`
- `cta-button-bg` → `components.ctaButton.default.bg`

---

### **12.1.3 Wiring Layers to the Preview Markup**

In the preview JSX/HTML, attach **data attributes** that correspond to `LayerDefinition.selector`.

Example:

```jsx
<div data-layer="widget-container">…</div>
<div data-layer="widget-header">…</div>
<button data-layer="cta-button-bg">Submit Feedback</button>
```

Then:

- In Edit mode, the Canvas interaction layer can:
  - Hit-test `event.target.closest('[data-layer]')`
  - Look up the corresponding `LayerDefinition` by `id`

Selectors in `LayerDefinition.selector` should be simple `[data-layer='id']` to avoid fragility.

---

### **12.1.4 Hover & Selection Behavior (Edit Mode Only)**

In **Edit** mode only (as defined in Phase 4.0):

1. **Hover Highlight**
   - When the mouse moves over the preview:
     - Find the topmost `[data-layer]` element under the cursor.
     - Apply a **visual highlight**:
       - e.g., translucent overlay or glow/outline.
     - If a layer is already selected, maintain a stronger “selected” styling (e.g., solid outline) for it.

2. **Click Selection**
   - On click in Edit mode:
     - Gather **all** layers under the cursor:
       - Walk up DOM ancestors, collecting `data-layer` values.
     - If only one layer is present:
       - Select that `LayerDefinition`.
     - If multiple:
       - Show a small popup “Layer Picker” at the click position listing:
         - e.g.  
           - CTA Button – Background  
           - CTA Button – Text  
           - Widget Container
       - Clicking a menu item selects that layer.

3. **Selected Layer State**
   - Store selected layer in global UI state:
     - `selectedLayerId: string | null`
   - Selected state should be reflected in:
     - Canvas highlight
     - Layers tab (see 12.1.5)
     - Layer Inspector (12.1.6)

---

### **12.1.5 Layers Tab (Left-Side Hierarchy)**

In the **Layers** main tab (next to Canvas / Style Guide):

- Show a sidebar tree that mirrors the layer model for the **current widgetType/questionType/deviceType**.

Structure:

```text
Widget
  - Container
  - Header
  - Body
Question
  - Single Choice (Default)
  - Single Choice (Active)
Controls
  - CTA Button
  - Text Input
```

Behavior:

- Clicking a row:
  - Sets `selectedLayerId`.
  - Highlights corresponding layer in the Canvas.
  - Opens the Layer Inspector panel for that layer.
- When the selection changes via Canvas click, the Layers tab updates to show the active row.

Phase 4.1 only needs a minimal tree; later phases can support expanding to other question types and templates.

---

### **12.1.6 Layer Inspector UI**

When a layer is selected (from Canvas or Layers tab), show a **Layer Inspector**.

There are two variants:

1. **Popover over Canvas** (as in your Figma)
2. **Side Panel** when in Layers tab (your Figma’s “Widget Container / Layer Inspector” screen)

Phase 4.1 should implement at least one; ideally both share underlying logic.

Minimum contents:

- **Layer Name**  
  - e.g. “Single Choice (Active)”
- **Token Mapping** (read-only, for now)  
  - e.g. `components.singleChoice.active.bg`
- **Brand Palette Swatches**
  - Show central palette tokens:
    - `brandPrimary`, `brandSecondary`, `accent`
    - `background`, `surface`
    - `textPrimary`, `textSecondary`, `neutralDark`
  - Clicking a swatch:
    - Updates the mapped token(s) for that layer:
      - e.g. set `components.singleChoice.active.bg = palette.brandPrimary`
- **Custom Color**
  - Show current color as a small square + hex input.
  - Optional: “More…” link to open existing full color picker UI.

Interaction logic:

- Layer Inspector must route all changes through the existing Theme update mechanism:
  - e.g. `updateThemeTokens(tokenPath, newColor)`
- Theme Editor sidebar should reflect updates immediately.

---

### **12.1.7 Interaction with ThemeTokensLite**

When a user selects a layer and chooses a color:

1. Find the layer’s `LayerTokenMapping[]`:
   - e.g. background vs text vs border
2. For each mapping:
   - Determine which token is being edited (e.g. `components.ctaButton.default.bg`)
   - Call the same update function used by Theme Editor:
     - So there is a single source of truth for state changes.
3. Recompile SCSS & re-render preview (existing mechanism).

For Phase 4.1, color is the primary focus; font-family and border radius, etc., can be added later using the same pattern.

---

### **12.1.8 Integration with Canvas Modes**

- Layer hover/selection and Layer Inspector should only be active in **Edit** mode.
- In **Interact** mode:
  - No hover outlining
  - Clicks behave as survey interactions
  - The Layers tab may remain visible but cannot change the Canvas behavior
    - (Optionally, Layers tab controls could be disabled or show a notice if Interact mode is active.)

---

### **12.1.9 Non-Goals / Out of Scope for Phase 4.1**

- Template version selection or Advanced Configuration UI  
  - Covered in Phase 4.2.
- Layer definitions for all widget/question/device combinations:
  - Phase 4.1 can start with:
    - widgetType = `docked`
    - questionType = `single-choice`
    - desktop & mobile variants
- Editing non-color properties (border radius, shadow, max width, etc.) beyond a minimal placeholder:
  - These can be wired up in later phases.
- Any changes to ThemeTokensLite schema, analyzer behavior, or SCSS semantics.

Phase 4.1 focuses on:
- Semantic layer mapping  
- Selection mechanics  
- Basic Layer Inspector → token updates  
over the existing theme field set.

---






### **12.2 Phase 4.2 – Preview Template Config & Advanced Configuration**

#### **12.2.1 Goals**

Phase 4.2 introduces an **Advanced Configuration** UI and an underlying **Preview Template Config** system so we can:

1. Select which **preview template version** is active for each combination of:
   - `widgetType`
   - `questionType`
   - `deviceType` (Desktop / iPhone / Android)
2. Configure **rendering options**:
   - Enable/disable preview animations
   - Caching for templates
3. Configure **editor options**:
   - Auto-save
   - Debug mode

This gives us a future-proof way to evolve markup without rewriting the Canvas and Layer logic.

---

#### **12.2.2 Template Registry (PreviewTemplateConfig)**

Create a registry describing available preview templates.

Conceptual types:

```ts
type DeviceType = "desktop" | "iphone" | "android";

type WidgetType = "docked" | "inline" | "modal";  // extendable
type QuestionType = "single-choice" | "multi-choice" | "slider" | "nps" | "free-text";

interface PreviewTemplate {
  id: string; // e.g. "docked-single-desktop-v1"
  label: string; // "Docked / Single Choice / Desktop / v1"
  widgetType: WidgetType;
  questionType: QuestionType;
  deviceType: DeviceType;
  // Component to render the preview for this combination
  render: React.ComponentType;
  // Layers: the LayerDefinitions to use with this template
  layers: LayerDefinition[];
}
```

Implement this as a static list in something like:

```ts
// src/preview/templates.ts
export const PREVIEW_TEMPLATES: PreviewTemplate[] = [ … ];
```

For now, Phase 4.2 can start with:

- `widgetType = "docked"`
- `questionType = "single-choice"`
- All 3 devices (desktop/iphone/android)
- Version `v1`

But the registry must be **ready to host more** templates (e.g. `v2`, multi-choice, modal).

---

#### **12.2.3 Active Template Selection**

Maintain a **selection state** describing which template to use for each (`widgetType`, `questionType`, `deviceType`) combo:

```ts
interface TemplateSelectionKey {
  widgetType: WidgetType;
  questionType: QuestionType;
  deviceType: DeviceType;
}

interface TemplateSelection {
  key: TemplateSelectionKey;
  templateId: string; // matches `PreviewTemplate.id`
}
```

Store these in the app’s state management (e.g. Zustand store), with a reasonable default mapping:

- Docked + Single Choice + Desktop → `docked-single-desktop-v1`
- Docked + Single Choice + iPhone → `docked-single-iphone-v1`
- Docked + Single Choice + Android → `docked-single-android-v1`

When the Canvas asks for the preview:

- It passes the current `widgetType`, `questionType`, `deviceType` (even if hard-coded for now).
- The preview component looks up the active `PreviewTemplate` from this selection state and uses its `render` + `layers`.

This is the architectural pivot: **templates stop being “magic JSX” and become data-driven.**

---

#### **12.2.4 Advanced Configuration Modal (UI)**

Hook the existing “Advanced” button in the Canvas header to open a modal:

- Title: **Advanced Configuration**
- Subtitle: “Configure advanced settings for your widgets and templates.”

Sections:

##### **A. Template Version Matrix**

A simple table-like layout:

Columns:
- Widget Type
- Question Type
- Desktop Template
- Mobile Template *(for iPhone/Android)*

Rows (Phase 4.2 MVP):
- Docked / Single Choice
- Docked / Multi Choice *(can be stubbed placeholder)*
- Modal / Single Choice *(placeholder for future)*

Each template cell:
- A dropdown listing all `PreviewTemplate.id`s compatible with that `widgetType` / `questionType` / `deviceType`.
- Display template `label` in the dropdown.

Changing a dropdown:
- Updates the `TemplateSelection` state.
- Immediately affects the preview the next time the Canvas is rendered.

##### **B. Rendering Options**

A “Rendering Options” group with switches (UI only, but wired to state):

- **Enable Animations** (boolean)
  - Controls whether preview animations (e.g., slide-in, fades) are used.
- **Cache Templates** (boolean)
  - “Store template versions locally for faster loading.”
- **Max Cache Size (MB)** (numeric input or dropdown; can be stubbed).

For now, these can influence **client-side behavior only** (e.g., toggling CSS transitions or memoization). They don’t need to integrate with any server.

##### **C. Editor Options**

Another group:

- **Auto-save Changes** (boolean)
  - Toggles whether theme changes are saved automatically (vs manual save, if you later introduce explicit saves).
- **Debug Mode** (boolean)
  - When enabled, the app can:
    - Show extra console logging.
    - Optionally overlay debug info in the Canvas (e.g., layer IDs, tokenPath overlays).

Phase 4.2 only needs basic wiring: toggles are stored in state and can be consumed later.

##### **D. Modal Controls**

- **Cancel** – closes modal without persisting changes.
- **Save** – persists changes to selection/state; closes modal.

(Implementation can choose between optimistic update vs “save to store on click”.)

---

#### **12.2.5 Canvas Integration**

- The Canvas should now, when rendering:

  1. Use the current `widgetType` and `questionType` (for now, can be hard-coded to `docked` / `single-choice` until you expose real controls).
  2. Use `deviceType` from the Device Selector.
  3. Look up the active `PreviewTemplate` via the `TemplateSelection` state.
  4. Render the template’s `render` component and load its `layers` into the Layer system.

This ensures:

- When you add a new template version in code (e.g. `docked-single-desktop-v2`), the only UI work needed is adding it to the Advanced Configuration modal.

---

#### **12.2.6 Out of Scope for Phase 4.2**

- Supporting all widget types and question types in production:
  - It’s ok if Phase 4.2 only fully supports “docked + single-choice” and uses placeholder rows for others.
- UI for editing templates themselves:
  - Templates remain code-defined.
- Persisting Advanced Config per project/theme:
  - For now, global config is fine. Project-specific config could be a later phase.
- Any changes to ThemeTokensLite, analyzer, or SCSS behavior.

---






## **12.3 Phase 4.3 – Style Guide 2.0**

### **12.3.1 Goals**

Phase 4.3 turns the **Style Guide** tab into a proper design-system view for the active theme. It should:

1. Present a **clear, client-ready summary** of the theme:
   - Color palette
   - Typography
   - Core components
2. Provide basic **accessibility/contrast diagnostics**.
3. Allow easy **export** to Markdown and HTML for documentation, tickets, and client decks.
4. Reflect changes made via:
   - Theme Editor (sidebar)
   - Layer Inspector
   - Analyzer-derived defaults

Phase 4.3 does **not** change ThemeTokensLite, the analyzer, or SCSS semantics. It is a **read-only view** over the existing theme state, plus derived calculations (contrast, etc.).

---

### **12.3.2 Style Guide Tab Layout**

The Style Guide tab lives alongside **Canvas** and **Layers** and maintains its own content, independent of canvas mode.

High-level sections in order:

1. **Header**
2. **Color Palette**
3. **Typography**
4. **Components**
5. **Accessibility / Contrast Summary**
6. **Export**

Layout should be vertically scrollable, with generous whitespace and clear section headings.

---

### **12.3.3 Header**

At the top of the Style Guide tab:

- Theme name (e.g. “Brand Faithful”)
- Project name (e.g. “Verizon”)
- Variant label (e.g. `brand-faithful`, `light`, `dark`, `minimal`, `custom`)

Example:

> **Brand Faithful**  
> _verizon · brand-faithful_

This provides context when screenshots / exports are shared out of context.

---

### **12.3.4 Color Palette Section**

Display key colors as **cards**.

#### **Tokens to include**

At minimum:

- `palette.brandPrimary`
- `palette.brandSecondary`
- `palette.accent`
- `palette.background`
- `palette.surface`
- `palette.textPrimary`
- `palette.textSecondary`
- `palette.border` or `neutralDark` (if defined)
- `palette.success`
- `palette.danger`

Each card shows:

- A large swatch
- Token label (e.g. “Brand Primary”)
- Hex value
- Token path (e.g. `palette.brandPrimary`)

Optional enhancement (if data is available from analyzer):

- A small “source” badge:
  - e.g. “CSS var `--brand-primary`”
  - or “Logo dominant color”
  - or “CTA button color”

Cards should be arranged in a grid (2–4 per row), similar to your Figma concept.

---

### **12.3.5 Typography Section**

Show typography roles for the theme.

#### Roles to include

At minimum:

- **Heading** (e.g. used for survey title)
- **Body** (question text / body copy)
- **Button** (CTA text)

Each role is rendered as:

- A label and example text:
  - Heading → “Quick Feedback Survey”
  - Body → “How satisfied are you with our service?”
  - Button → “Submit Feedback”
- A subline with font info:
  - `24px / Inter / 600`
  - `16px / Inter / 400`, etc.
- Underlying token path(s):
  - e.g. `typography.heading`, `typography.body`, `typography.button`

Use the real font families, sizes, and weights from ThemeTokensLite so designers can visually check them.

---

### **12.3.6 Components Section**

Render small **component previews** that match the theme but do not need full survey layout.

Suggested components:

1. **Single Choice Option**
   - Show both Default and Active states side-by-side.
   - Use tokens from `components.singleChoice.default` and `.active`.

2. **CTA Button**
   - Show the primary button as a standalone preview (“Submit Feedback”).
   - Use `components.ctaButton.default`.

3. **Text Input**
   - Show a one-line text input with placeholder text.
   - Use `components.textInput` tokens (bg, border, text, placeholder).

Each component block should:

- Be labeled (“Single Choice”, “CTA Button”, “Text Input”).
- Use a small, consistent card-style presentation.

Implementation detail:

- You can either:
  - Use the same JSX/HTML fragments as the main preview templates in a “mini” layout, or
  - Render a simplified version styled with the same CSS classes/tokens.

---

### **12.3.7 Accessibility / Contrast Summary**

Provide a simple **contrast report** for key text/background pairs.

Pairs to check (at minimum):

- Text Primary vs Background
- Text Primary vs Surface
- CTA Button Text vs CTA Button Background
- Single Choice Active Text vs Active Background

For each pair:

- Show a label: e.g. “Text on Background”
- Show color swatches for foreground and background.
- Show contrast ratio, e.g. `4.8:1`.
- Show a status:
  - ✅ “Pass (AA normal text)”
  - ⚠️ “Low contrast – consider adjusting”

Implementation:

- Use the same contrast calculation utilities already used in the analyzer or palette builder (WCAG relative luminance).
- Keep it simple – this is a **summary**, not a full accessibility auditor.

---

### **12.3.8 Export Controls (Markdown & HTML)**

At the top of the Style Guide tab (or pinned in the header area), include two buttons:

- **Copy Markdown**
- **Copy HTML**

Clicking each:

- Generates a structured representation of the current Style Guide and copies it to the clipboard.
- Uses the same sections as the UI: Colors, Typography, Components, Accessibility.

#### Markdown output structure (example)

```md
# Theme: Brand Faithful
Project: Verizon  
Variant: brand-faithful

## Color Palette

- **Brand Primary** (`palette.brandPrimary`): `#3882F6`
- **Brand Secondary** (`palette.brandSecondary`): `#18B981`
- **Accent** (`palette.accent`): `#F5E98B`
...

## Typography

**Heading**  
`24px / Inter / 600`  
“Quick Feedback Survey”

**Body**  
`16px / Inter / 400`  
“How satisfied are you with our service?”
...

## Components

- Single Choice (Default/Active)
- CTA Button
- Text Input
...

## Accessibility

- Text on Background: `4.8:1` – Pass (AA)
- CTA Text on CTA BG: `3.9:1` – Low contrast – consider darker text or lighter background.
```

#### HTML output structure

- Use simple `<h1>`, `<h2>`, `<div>`, `<ul>`/`<li>`.
- No external CSS needed; consumers can style it themselves.
- Make sure hex codes and token paths are present.

---

### **12.3.9 Interaction with Canvas & Layers**

- Style Guide is **read-only**; it should reflect the *current active theme*.
- When tokens are changed via:
  - Theme Editor,
  - Layer Inspector,
  - Palette changes,
  
  the Style Guide updates automatically on render.

- Style Guide does **not** depend on Canvas mode (`Edit` / `Interact`) or device selection; it’s theme-centric, not device-centric.

---

### **12.3.10 Out of Scope for Phase 4.3**

- PDF export (can be a future enhancement).
- Per-layer typography/spacing details.
- Per-template or per-device style variations in the Style Guide (Phase 4.3 is theme-level, not template-level).
- AI-based commentary or automated change suggestions.

Those belong to later phases (Phase 4.4+ / 5.x).











---

## **12.4 Phase 4.4 – Token Manager & Unified Theme Update System**

### **12.4.1 Goals**

Phase 4.4 introduces a **centralized Token Manager** responsible for all theme read/write operations.  
Its purpose is to unify and stabilize how theme tokens are edited across the application.

Today, multiple parts of the UI make changes to theme tokens:

- Theme Editor (left sidebar)
- Layer Inspector popover
- Color swatch interactions
- Hex input interactions
- Future AI transforms and automated refinements

Phase 4.4 ensures:

1. All token updates go through a **single, consistent API**.  
2. All theme reads go through a **central access point**.  
3. All sections of the app (Canvas → Preview, Layers Tab, Style Guide) stay in sync reliably.  
4. Change provenance and logging becomes possible for future undo/redo and “reset” features.

This is a **refactor + infrastructure** phase. ThemeTokensLite schema, analyzer logic, and SCSS semantics remain unchanged.

---

### **12.4.2 Create a Token Manager Module**

Add a new module:

```
src/theme/tokenManager.ts
```

This module becomes the **authoritative gateway** for all theme updates and reads.

#### **Write API**

```ts
export type TokenPath = string;

export interface UpdateTokenOptions {
  source?: 
    | "themeEditor"
    | "layerInspector"
    | "analyzer"
    | "advancedConfig"
    | "other";
}

export function updateToken(
  tokenPath: TokenPath,
  value: unknown,
  options?: UpdateTokenOptions
): void;
```

**Responsibilities:**

- Resolve the token path (e.g., `"palette.brandPrimary"`) into the correct field of the active theme.  
- Apply immutable updates via the existing theme store.  
- Trigger SCSS compilation + preview CSS refresh (existing system).  
- Trigger global UI updates across Canvas, Layers, Style Guide, and other observers.  

All theme-changing operations must call `updateToken()`.

---

#### **Read API**

```ts
export function getToken<T = unknown>(tokenPath: TokenPath): T | undefined;
```

**Responsibilities:**

- Resolve the token path and return the current value in the active theme.  
- Remove the need for UI surfaces to manually reach into nested theme objects.

All theme-**reading** components should use `getToken()`.

---

### **12.4.3 Token Metadata Registry (Optional but Recommended)**

Introduce a metadata registry for tokens:

```ts
export interface TokenMeta {
  path: TokenPath;
  group: "palette" | "typography" | "component" | "layout";
  label: string;
  description?: string;
}

export const TOKEN_META: TokenMeta[] = [
  // Example:
  { path: "palette.brandPrimary", group: "palette", label: "Brand Primary" }
];
```

Uses:

- Style Guide can show human-friendly labels.  
- Layer Inspector can display clearer mapping descriptions.  
- Future AI features can use metadata context for reasoning.  

This does **not** change how tokens are stored.

---

### **12.4.4 Refactor Mutation Points to Use the Token Manager**

Every UI surface that edits theme tokens must be updated to call `updateToken()`.

#### **1. Theme Editor**

Replace direct store calls with:

```ts
updateToken("palette.brandPrimary", newColor, { source: "themeEditor" });
```

#### **2. Layer Inspector**

When user clicks a palette swatch or edits a hex value:

```ts
updateToken(mapping.tokenPath, newColor, {
  source: "layerInspector"
});
```

#### **3. Other Surfaces (as needed)**

If any Advanced Config or automatic defaults modify tokens, they must also route through:

```ts
updateToken(path, value, { source: "advancedConfig" });
```

Refactor ensures **all writes funnel through one function.**

---

### **12.4.5 Unified Read Path for Style Guide & Layers**

Update the following components so they read token values using `getToken()`:

- Style Guide (Color Palette, Typography, Components, Accessibility)
- Layer Inspector (current color, token path resolution)
- Any new UI relying on live theme values

This ensures consistent, centralized access for theme data.

---

### **12.4.6 Token Change Logging (Provenance MVP)**

Add minimal provenance tracking inside the Token Manager or store:

```ts
export interface TokenChange {
  timestamp: number;
  tokenPath: TokenPath;
  oldValue: unknown;
  newValue: unknown;
  source?: UpdateTokenOptions["source"];
}

export type TokenChangeLog = TokenChange[];
```

Behavior:

- If `updateToken()` results in a changed value:
  - Append a `TokenChange` entry to the log.
- Expose a getter:

```ts
export function getChangeLog(): TokenChangeLog;
```

This log is **read-only** and does not require a UI yet.

It will enable future features:

- Undo/redo  
- "Reset this token to analyzer defaults"  
- Detailed theme history / diff view  

---

### **12.4.7 State Guide QA Coverage**

Use the Annotated State Guide (all 119 states) as a QA baseline:

- **Color Interaction (CI-001..CI-010)**  
  - Swatch hovers, selection, hex input must continue to work.  
  - Inspector + Style Guide must update simultaneously.

- **Layer Selection (LS-001..LS-009)**  
  - Selecting layers should update Inspector using Token Manager reads.  
  - Editing via Inspector must reflect in preview + Style Guide.

- **Theme Selection (TH-001..TH-003)**  
  - Switching themes resets token values; Token Manager must respect this without stale values.

- **Tab Navigation (TS-001..003)**  
  - Reads in Style Guide and Layers must remain accurate after refactor.

If any direct theme access remains temporarily, they should be flagged for future cleanup.

---

### **12.4.8 Out of Scope**

- Undo/redo UI  
- Reset-to-default or reset-to-analyzer functions  
- Schema changes to ThemeTokensLite  
- Analyzer enhancements  
- Template or Layer system changes  

These can be layered on top of the Token Manager after stabilization.

---










## **12.5 Phase 4.5 – Visual Polish & UI System**

### **12.5.1 Goals**

Phase 4.5 delivers a comprehensive UI polish across the entire Theme Designer interface to match the fidelity, hierarchy, and interaction quality of the Figma prototype.

The objective is to unify the app under a consistent visual language that communicates clarity, professionalism, and modern design standards.

Phase 4.5 does **not** add new functional capabilities.  
It **refines**:

- Visual hierarchy  
- Layout consistency  
- Typography system  
- Color + spacing tokens  
- Component appearance  
- Microinteractions  
- Device frames  
- Layer inspector UX  
- Canvas header and toolbars  

This phase transitions the Theme Designer UI from “developer tool” → “design tool.”

---

### **12.5.2 Global UI System (Tokenized Visual Language)**

Introduce a centralized UI design system to enforce consistency.

Create:

```
src/ui/tokens.ts
src/ui/typography.ts
src/ui/containers.css
src/ui/motion.ts
```

#### **A. Color Tokens**

From the Figma prototype, define shared UI colors:

```ts
export const UI_COLORS = {
  bg: "#F8FAFC",            // neutral-50
  panel: "#FFFFFF",         // white
  border: "#E2E8F0",        // neutral-200
  divider: "#E5E7EB",       // neutral-300
  text: "#1E293B",          // neutral-800
  textMuted: "#64748B",     // neutral-500/600
  primary: "#3B82F6",       // blue-500/600
  primaryHover: "#2563EB",  // blue-700
  focusRing: "#3B82F6",
  canvasDarkBg: "#1E293B",  // dark bg for device frames
};
```

Applied to:

- Buttons  
- Tabs  
- Left panel  
- Layer Inspector  
- Advanced Config  
- Style Guide  
- Device preview backdrops  

---

#### **B. Typography Tokens**

Define global typographic roles based on prototype:

```ts
export const UI_TYPOGRAPHY = {
  title: "600 18px Inter",
  section: "500 15px Inter",
  label: "500 13px Inter",
  body: "400 14px Inter",
  small: "400 12px Inter",
};
```

Apply roles consistently to:

- Canvas header icons & mode selector  
- Layers tab item labels  
- Inspector section headers (“PROPERTIES”, “COLORS”)  
- Style Guide section headers & body text  
- Modal headings (“Advanced Configuration”, “Create New Project”)  

---

#### **C. Layout & Spacing Scale**

From Figma grid:

- 4px grid  
- Common spacing: 4 / 8 / 12 / 16 / 24 / 32  
- Containers:
  - Border radius: `8px` default  
  - Page sections: `24px` vertical spacing  
  - Gap between UI clusters: `10–16px`  

Define in `containers.css`:

```css
.card {
  background: #fff;
  border: 1px solid #E2E8F0;
  border-radius: 8px;
  padding: 16px;
  box-shadow: 0 1px 2px rgba(0,0,0,0.04);
}
```

---

#### **D. Motion & Microinteractions**

Capture prototype interaction behaviors:

- Tab underline slide:
  - 200ms, ease-out  
- Device switching:
  - Cross-fade + scale from 0.98 → 1  
  - 400ms, ease-in-out  
- Sidebar collapse:
  - Transform: translateX(-100%)  
  - 300ms  
- Inspector popover:
  - Fade + translateY(4px)  
- Hover effects:
  - Opacity 0.6 → 1.0  
  - 150ms linear  

Expose motion tokens:

```ts
export const UI_MOTION = {
  fast: "150ms ease",
  medium: "300ms ease-in-out",
  slow: "400ms ease-out",
};
```
---

### **12.5.3 Component-Level Visual Refinements**

This section details polishing each key UI element to match the prototype.

---

#### **A. Canvas Header**

Refine the header to match Figma’s “studio toolbar”:

- Increase height + padding (12–16px)
- Add a subtle bottom border (`1px solid UI_COLORS.divider`)
- Group controls into **clusters**:
  - Mode (Edit / Interact)
  - Devices (Desktop / iPhone / Android)
  - Context (Clean / Context)
  - Advanced (Settings icon)

Space groups using `gap-6`.

Buttons use UI tokens for:

- Active state: `bg-blue-600 text-white`
- Hover state: `bg-blue-700`
- Inactive: `bg-neutral-100 text-neutral-700`

---

#### **B. Device Frames**

Improve realism:

##### **iPhone:**
- Rounded corners  
- True notch with sensor bar  
- Safe-area top spacing  
- Shadow around device frame  
- Neutral-800 background behind frame  

##### **Android:**
- Rounded rectangle (less aggressive)  
- Fake speaker notch (small pill)  
- Dark background underneath  

##### **Desktop:**
- Simple centered box with subtle drop shadow  
- White or neutral-50 background  

---

#### **C. Layer Inspector**

Match the two-column inspector from the prototype:

Left column = **PROPERTIES**  
Right column = **COLORS**

Refine:

- Section titles (uppercase, 12px, tracking-wide)
- Divider lines (neutral-200)
- 24px spacing between sections
- Add subtle card container around inspector panels
- Use color swatch selection ring:
  - border: `2px solid blue-500`
  - ring: `shadow-outline` or custom ring

Align token labels, hex input, and swatches exactly as in prototype.

---

#### **D. Layers Tab**

Refine tree to mimic Figma:

- Parent items with chevron icons (12px)
- Iconography:
  - Widget → square outline  
  - Question → text “A” icon  
  - Controls → cursor icon  
- Indentation: 16px for child nodes
- Selected node:
  - `bg-blue-50 text-blue-900 border-left-2 border-blue-500`
- Hover node:
  - `bg-neutral-50`

Spacing:

- Vertical padding 6–8px per row
- Group labels (Widget, Question, Controls) have 12px top padding

---

#### **E. Style Guide**

Polish to match the Figma look:

##### **Color Palette**
- Cards with fixed height (120px)
- Label under swatch with muted text
- Token path lower in smaller type
- 24px vertical spacing between sections  

##### **Typography**
- Example text rendered with theme fonts  
- Secondary lines (“16px / Inter / 400”) in muted gray  
- Horizontal divider between roles  

##### **Components**
- Component previews boxed with card styling  
- Labels above previews  
- 12–16px padding inside preview cards  

##### **Contrast summary**
- Small pill-style badges for pass/fail  
- Color chips with small drop shadow  
- Ratio in bold type  

---

#### **F. Modals (New Project, Advanced Settings)**

Enhance to match your Figma:

- White panel with strong shadow (`0 8px 20px rgba(0,0,0,0.07)`)
- Rounded 12px
- Header:
  - 18px title, medium weight  
  - Faint divider below  
- Inputs:
  - 14px body type  
  - 10px padding  
  - Border: 1px solid neutral-300  
  - Focus ring: blue-500 2px  
- Footer:
  - Buttons spaced to left/right  
  - Subtle background in footer container  

---

### **12.5.4 Layout Improvements**

Refinement of global layout:

#### **Left Panel**
- Keep 280px width  
- Increase spacing between projects and themes  
- Add subtle dividers  
- Round theme cards with 8px radius and shadow  

#### **Canvas Tab**
- Center device frames horizontally  
- Use 24px padding around canvas  
- Use a neutral gradient in context mode background (optional)  

#### **Layers Tab**
- Split into:
  - Tree panel (fixed 320px)
  - Inspector panel (flex)  
- Add vertical divider between them  

---

### **12.5.5 Interaction Enhancements**

Small UX improvements that dramatically improve feel:

#### **Tab underline animation**
- Animated `left` & `width` transitions  
- 200ms ease-out  

#### **Hover effects**
Universal:
- opacity change or subtle background tint  
- 120–150ms  

#### **Inspector popover**
- fade + slide: `opacity 0 → 1`, `translateY(4px → 0)`  
- 150ms ease  

#### **Device switching**
- Fade-out & fade-in  
- Slight scale (0.98 → 1.0)  
- 300–400ms  

#### **Sidebar collapse animation**
- transform: `translateX(-100%)`  
- ease-in-out  

---

### **12.5.6 Constraints & Non-Goals**

Phase 4.5 **does not** modify:

- ThemeTokensLite schema  
- Analyzer behavior  
- Template registry logic  
- Layer Definitions  
- Token Manager architecture  
- SCSS variable mapping  

Functionality remains identical; only the **visual system** is updated.

---

### **12.5.7 Deliverables**

Implement:

- Global UI tokens & typography  
- Refined layout + spacing + structure  
- Polished Canvas header  
- Device frames  
- Layer Inspector visuals  
- Layers tab polish  
- Style Guide polish  
- Modal polish  
- Microinteraction animations  

Update README with a “UI System” section documenting:

- UI tokens  
- Typography roles  
- Motion guidelines  
- Component patterns  

---





## **12.6 Phase 4.6 – Undo / Redo & Reset Tools**

### **12.6.1 Goals**

Phase 4.6 builds on the Token Manager (Phase 4.4) to add:

1. **Undo / Redo** of recent theme changes.
2. **Reset** options:
   - Reset a single token.
   - Reset a group of related tokens (e.g., CTA Button).
   - Reset the entire theme to an analyzer or baseline snapshot.

The design intent is to allow safe exploration: users can experiment freely with colors and typography and easily return to a stable state.

No changes are made to ThemeTokensLite schema, analyzer behavior, or SCSS semantics.  
This phase only adds logic and UI *around* the existing Token Manager.

---

### **12.6.2 Baseline Theme Snapshot**

Define a concept of a **baseline theme** per project/theme:

- `baselineTheme` = the theme state immediately after:
  - initial analyzer generation **or**
  - first manual “Save as baseline” action.

Implementation:

- Extend the theme store to keep, per theme:
  - `currentTheme` (already present)
  - `baselineTheme` (deep copy of ThemeTokensLite)
- When a theme is created/generated:
  - Store its initial tokens as `baselineTheme`.
- Optionally, provide a “Set current as baseline” action later (can be stubbed for now).

---

### **12.6.3 Undo / Redo Model**

Use the existing change log from Token Manager to drive undo/redo.

Maintain two stacks:

- `undoStack: TokenChange[]`
- `redoStack: TokenChange[]`

Behavior:

- Whenever `updateToken` modifies a token:
  - Push the `TokenChange` onto `undoStack` (and clear `redoStack`).
- **Undo**:
  - Pop the last change from `undoStack`.
  - Call `updateToken(tokenPath, oldValue, { source: "undo" })`.
  - Push that change onto `redoStack`.
- **Redo**:
  - Pop from `redoStack`.
  - Call `updateToken(tokenPath, newValue, { source: "redo" })`.
  - Push back onto `undoStack`.

Constraints:

- Avoid recursively logging undo/redo as new history entries:
  - Either flag them in options and skip logging, or log them but ignore when computing stacks.
- Reasonable stack size limit (e.g. last 100 changes) is acceptable.

---

### **12.6.4 Undo / Redo UI**

Add small Undo/Redo controls to the Canvas header or near the Theme Editor:

- Buttons with icons:
  - Undo: left arrow icon
  - Redo: right arrow icon
- Tooltips:
  - “Undo last change”
  - “Redo last undone change”

Behavior:

- Disabled when:
  - Undo stack is empty (Undo).
  - Redo stack is empty (Redo).

Optional:  
Show a brief toast/inline message indicating what was undone/redone, e.g.:

> Undid: palette.brandPrimary (#3B82F6 → #1D4ED8)

---

### **12.6.5 Reset Tools**

Introduce reset capabilities at three levels:

#### A. Reset Token

In Layer Inspector and/or Theme Editor:

- For each editable token (e.g., `palette.brandPrimary`), show a small “Reset” link or icon.
- On click:
  - Look up the corresponding value in `baselineTheme`.
  - Call `updateToken(tokenPath, baselineValue, { source: "reset-token" })`.

If no baseline is available, the control can be disabled or hidden.

#### B. Reset Group (e.g. CTA Button, Single Choice)

For logical groups (CTA Button, Single Choice, Text Input, Widget):

- Provide a “Reset [Group]” button in the Layer Inspector or Theme Editor section.
- Each group has a set of token paths associated with it.
- For each token in the group:
  - Apply baseline value via `updateToken`.

Example groups:

- CTA Button:
  - `components.ctaButton.default.bg`
  - `components.ctaButton.default.fg`
  - `components.ctaButton.default.border`
- Single Choice:
  - `components.singleChoice.default.*`
  - `components.singleChoice.active.*`

#### C. Reset Theme

In Theme Editor or top-level theme actions:

- Provide “Reset Theme to Baseline” button.
- On click:
  - Iterate over all tokens in ThemeTokensLite.
  - For each token:
    - Apply baseline value via `updateToken(path, baseline[path], { source: "reset-theme" })`.

Optional: show a confirmation modal to avoid accidental full resets.

---

### **12.6.6 State & Integration Considerations**

- Undo/redo should work for all sources (themeEditor, layerInspector, analyzer, etc.).
- Reset actions should also generate entries in the undo stack so they can be undone.
- Style Guide, Canvas, and Layers must all reflect changes in real-time.

The Annotated State Guide can be reused for QA, focusing on:

- Color interaction states (CI-001..010)
- Layer selection states (LS-001..009)
- Theme selection states (TH-001..003)

---

### **12.6.7 Out of Scope**

- Cross-session undo/redo persistence.
- Multiple baselines per theme.
- Undo/redo of Advanced Config or non-token settings.
- AI-driven revert suggestions.

These may be added in later phases, but are not required now.

---









## **12.7 Phase 4.7 – Typography & Layout Tokens**

### **12.7.1 Goals**

Phase 4.7 extends theme expressiveness by:

1. Elevating **typography** to first-class theme tokens:
   - Heading, Body, Button text roles.
2. Adding **layout tokens**:
   - Border radii
   - Spacing
   - Max widths where appropriate.

The intent is to:

- Support brand-aligned typography
- Allow better control over widget “shape”
- Reflect these in Layer Inspector, Style Guide, and Canvas

Again, ThemeTokensLite schema should remain conceptually the same; we’re adding or wiring through existing typography/layout fields, not changing overall structure.

---

### **12.7.2 Typography Tokens — Roles & Structure**

Ensure ThemeTokensLite includes a typography section, or wire it to the existing shape if already present:

```ts
typography: {
  heading: {
    fontFamily: string;
    fontSize: number;     // px
    fontWeight: number;   // 400, 500, 600
    lineHeight: number;   // unitless multiple
  };
  body: {
    fontFamily: string;
    fontSize: number;
    fontWeight: number;
    lineHeight: number;
  };
  button: {
    fontFamily: string;
    fontSize: number;
    fontWeight: number;
    letterSpacing?: number;
    lineHeight: number;
  };
}
```

If these already exist, Phase 4.7 focuses on **exposing and editing** them via UI.

---

### **12.7.3 Typography Editing UI**

Enhance the Theme Editor and/or Layer Inspector:

- Add a **Typography** section in Theme Editor:
  - Controls for:
    - Heading font family (text input or dropdown)
    - Heading size (number input, px)
    - Body size
    - Button size
    - Heading/body/button font weights (dropdown: 400, 500, 600, 700)
  - Use a consistent UI with labels and small helper text.

- Wire these controls to Token Manager:
  - Use `updateToken("typography.heading.fontSize", newSize, { source: "themeEditor" })`, etc.

Optional:

- Allow editing `lineHeight` and `letterSpacing` in an “Advanced” subsection.

---

### **12.7.4 Layout Tokens**

Define or wire layout-related tokens in ThemeTokensLite:

```ts
layout: {
  borderRadius: {
    widget: number;   // px
    button: number;
    option: number;
    input: number;
  };
  spacing: {
    optionGap: number;     // px
    widgetPadding: number; // px
    sectionSpacing: number;
  };
  maxWidth: {
    widget: number; // px, e.g. 420
  };
}
```

(If `layout` already exists in some shape, adapt to your actual schema and ensure Token Manager is aware.)

Expose layout controls in Theme Editor (e.g., under Layout section):

- Numeric inputs for:
  - Widget border radius
  - CTA button border radius
  - Option border radius
  - Widget max width
  - Option vertical spacing
- All wired via Token Manager’s `updateToken`.

---

### **12.7.5 Canvas, Layers, and Style Guide Integration**

Ensure:

- Canvas (preview templates / SCSS) actually use the `typography` and `layout` tokens:
  - Heading/body/button font sizes/weights/family applied to text.
  - Border radii applied from layout tokens.
  - Spacing tokens applied to option gaps and widget padding.

- Layer Inspector shows typography/layout info for relevant layers:
  - For text layers (heading/body/button):
    - Display token path and current size/weight.
  - For container layers (Widget container, CTA Button, Single Choice):
    - Show border radius and relevant layout tokens.

- Style Guide updates:
  - Typography section shows current roles using the updated tokens.
  - Components reflect updated border radius and spacing.

---

### **12.7.6 Analyzer & Defaults (Light Touch)**

Optional but recommended:

- When generating themes from analysis:
  - Use detected heading/body font sizes and families to set `typography.heading` and `typography.body`.
  - Derive button size from heading/body, if possible.

Phase 4.7 can keep this simple:

- If analyzer doesn’t detect typography details, fall back to sensible defaults.

---

### **12.7.7 State & UX Considerations**

- Typography changes should be reflected immediately in:
  - Canvas (interact + edit)
  - Style Guide
- Layout changes (border radius, spacing) should be immediately visible in:
  - Canvas (device previews)
  - Layers Inspector previews
  - Style Guide component cards

Undo/redo (from Phase 4.6) should work seamlessly for all typography/layout changes.

---

### **12.7.8 Out of Scope**

- Per-device typography/layout (desktop vs mobile-specific tokens).
- Advanced CSS features (e.g. variable fonts, responsive fluid type).
- AI-based typography suggestions.
- Template-specific type/layout overrides.

These can be considered for future 5.x phases.

---








## **13.0 Phase 5.0 – Pulse Markup Integration (Static Templates)**

### **13.0.1 Goals**

Phase 5.0 transitions the Theme Designer from using simplified “lab” markup to using **real Pulse widget markup** in the preview templates, while:

- Preserving the current Canvas, Layers, Style Guide, and Token Manager architecture.
- Maintaining the ability to switch between simplified and real markup via the existing **template registry + Advanced Configuration**.
- Ensuring real markup still supports:
  - Layer selection / data-layer mapping
  - Theme tokens → CSS styling
  - Device-aware templates (Desktop / iPhone / Android)

This phase uses **static Pulse markup snapshots** (HTML/JSX equivalents) rather than dynamically calling the live Pulse backend. A later phase can introduce fully “live” snippet integration if desired.

---

### **13.0.2 Strategy Overview**

We will:

1. Treat Pulse markup as **new template versions** in the `PreviewTemplate` registry.
2. Bring the real HTML structure (classes, wrappers, DOM hierarchy) into the app as React/JSX or raw HTML.
3. Add `data-layer` attributes to relevant elements to preserve the Layer system.
4. Update the SCSS/Theme→CSS layer to match Pulse’s classnames and DOM structure.
5. Let Advanced Config choose between:
   - Simplified templates (lab / v1)
   - Real Pulse templates (pulse-v1 / v2, etc.)

No change to ThemeTokensLite or Token Manager is required; only templates and SCSS.

---

### **13.0.3 Template Version Naming & Registry**

In `src/preview/templates.ts`, introduce a new family of template IDs for real Pulse markup:

Examples (for docked + single-choice):

- Simplified (already exists):
  - `docked-single-desktop-v1`
  - `docked-single-iphone-v1`
  - `docked-single-android-v1`
- **New Pulse-based templates:**
  - `docked-single-desktop-pulse-v1`
  - `docked-single-iphone-pulse-v1`
  - `docked-single-android-pulse-v1`

Each `PreviewTemplate` entry:

```ts
{
  id: "docked-single-desktop-pulse-v1",
  label: "Docked / Single Choice / Desktop / Pulse Markup v1",
  version: "pulse-v1",
  widgetType: "docked",
  questionType: "single-choice",
  deviceType: "desktop",
  generateHTML: renderDockedSingleDesktopPulseV1,
  layers: dockedSinglePulseLayersV1
}
```

These live side-by-side with existing simplified templates and are selectable through Advanced Config.

---

### **13.0.4 Importing Real Pulse Markup**

For each supported combination (start with docked + single choice):

1. **Extract canonical Pulse HTML**  
   From the Rails app or snippet output:
   - The DOM structure of the docked widget for a single-choice question.
   - Relevant classes and attributes.

2. **Convert to JSX or string template**
   - Prefer React JSX if possible (easier to manage dynamic bits).
   - If JSX is too coupled, wrap actual HTML with `dangerouslySetInnerHTML`.

3. **Instrument with `data-layer` attributes**  
   Map LayerDefinitions to actual elements:

   - Widget container → outermost `.pi-widget` or equivalent:
     - `data-layer="widget-container"`
   - Widget header (title bar) → header wrapper:
     - `data-layer="widget-header"`
   - Widget body → main content area:
     - `data-layer="widget-body"`
   - Single-choice option (default) → appropriate option wrapper:
     - `data-layer="single-choice-default"`
   - Single-choice option (active) → same structure but state class:
     - `data-layer="single-choice-active"`
   - CTA Button:
     - `data-layer="cta-button-bg"` (and maybe `data-layer="cta-button-text"` if separate text span)
   - Text input:
     - `data-layer="text-input-border"` and `data-layer="text-input-text"`

4. **Remove or neutralize live behaviors in Edit mode**  
   - Keep markup, but in Edit mode we still rely on our own interaction model (hover/select).
   - Interact mode can use Pulse’s behavior where sensible, but this phase can still simulate, as we already do.

---

### **13.0.5 Layer Definitions for Pulse Markup**

Create a new `LayerDefinition[]` set for Pulse-based templates, e.g.:

```ts
export const dockedSinglePulseLayersV1: LayerDefinition[] = [
  {
    id: "widget-container",
    displayName: "Widget Container",
    selector: "[data-layer='widget-container']",
    mappings: [
      { tokenPath: "components.widget.bodyBg", role: "background" },
      { tokenPath: "components.widget.bodyFg", role: "text" }
    ],
    group: "widget"
  },
  // …others: widget-header, single-choice-default, single-choice-active, cta-button, text-input, etc.
];
```

These LayerDefinitions should match the actual pulse DOM structure and selectors.

Templates and LayerDefinitions must always be in sync.

---

### **13.0.6 SCSS / Theme Application to Real Markup**

Update or extend the existing SCSS theme template so it **targets real Pulse classnames** in addition to, or instead of, the simplified markup.

Strategies:

- If your current SCSS is already based on real Pulse classnames → just ensure the markup uses those classes.
- If the SCSS was simplified for the lab markup:
  - Add a new SCSS partial for Pulse markup:
    - e.g. `_pulse-widget.scss`
  - Map ThemeTokensLite → CSS variables or classes used in Pulse markup.

Key requirements:

- `components.singleChoice.*` tokens must affect the correct `.pi-option` or equivalent.
- `components.ctaButton.*` tokens must affect the actual button.
- `components.widget.*` tokens must affect local containers.

The goal: switching to a Pulse template makes the preview *really look* like Pulse, but still driven by our theme tokens.

---

### **13.0.7 Advanced Config Integration**

Update **Advanced Configuration** (Phase 4.2) so the Template Version matrix can:

- Show both simplified and Pulse-based template versions in the dropdowns.
- E.g.:

  - Simplified: `v1 – Lab`
  - Pulse Markup: `Pulse v1`

For now, default configuration might remain the lab version, with Pulse markup opt-in:

- For internal debugging: use Pulse templates.
- For CSM/client-facing sessions: choose Pulse or lab as desired.

---

### **13.0.8 QA & Behavior Expectations**

In Canvas:

- Edit mode:
  - Layer highlighting & selection must still work.
  - Layer Inspector must still correctly reflect mapped tokens.
- Interact mode:
  - Behavior should be at least as good as the current simulation.
  - Full fidelity to Pulse behavior can be gradually introduced later (e.g. Phase 5.1 with real snippet execution).

In Style Guide:

- No structural changes needed; just ensure the visual differences from Pulse markup are expected.

---

### **13.0.9 Out of Scope for Phase 5.0**

- Embedding the **real Pulse JS snippet** and making remote calls to the Pulse backend.
- Supporting all widget types and question types:
  - Phase 5.0 can start with:
    - `widgetType = "docked"`
    - `questionType = "single-choice"`
  - Others can continue using simplified templates until future phases.
- Device-specific Pulse markup variants (e.g., custom mobile markup beyond CSS).
- Any changes to ThemeTokensLite, Token Manager, or analyzer.

Those can be addressed in **Phase 5.1+** (e.g. “Live Snippet Mode”).

---





## **13.1 Phase 5.0a – Docked Desktop: Single-Choice Standard Buttons + Thank-You**

### **13.1.1 Goals**

Phase 5.0a introduces the first real Pulse markup into the Theme Designer:

1. Add Pulse-markup templates for:

   * **Docked widget (desktop) – Single Choice (Standard Buttons)**
   * **Docked widget (desktop) – Thank You state**

2. Build new `PreviewTemplate` entries under a new template family:

   * `pulse-v1`

3. Define Pulse-specific `LayerDefinition[]` sets mapped to the real DOM.

4. Add `data-layer` attributes to the imported markup to support:

   * Hover/selection in Edit mode
   * Layer Inspector mapping
   * Canvas visual highlights

5. Ensure theme tokens apply correctly via SCSS:

   * Widget container background, text, radius
   * Question text
   * Standard button tokens (default / active)
   * CTA area (if present)
   * Thank-you text styling

6. Expose the Pulse templates in **Advanced Configuration**, alongside Lab templates.

This phase uses **static markup only**, not the live Pulse JS snippet.

---

### **13.1.2 Template Registry Additions**

Add two new `PreviewTemplate` entries:

#### **Single-Choice Standard Buttons (Pulse V1)**

```ts
{
  id: "docked-single-standard-desktop-pulse-v1",
  label: "Docked / Single Choice (Buttons) / Desktop — Pulse v1",
  version: "pulse-v1",
  widgetType: "docked",
  questionType: "single-choice-standard",
  deviceType: "desktop",
  generateHTML: renderDockedSingleStandardDesktopPulseV1,
  layers: dockedSingleStandardPulseLayersDesktopV1
}
```

#### **Thank-You View (Pulse V1)**

```ts
{
  id: "docked-thank-you-desktop-pulse-v1",
  label: "Docked / Thank You / Desktop — Pulse v1",
  version: "pulse-v1",
  widgetType: "docked",
  questionType: "thank-you",
  deviceType: "desktop",
  generateHTML: renderDockedThankYouDesktopPulseV1,
  layers: dockedThankYouPulseLayersDesktopV1
}
```

These should appear in Advanced Config for the `docked` + `single-choice-standard` and `docked` + `thank-you` rows.

---

### **13.1.3 Docked Shell Wrapper**

Create a shared React component used by both template renderers:

```tsx
function DockedShell({ children, questionType }: { 
  children: React.ReactNode; 
  questionType: string; 
}) {
  return (
    <div id="_pi_surveyWidgetContainer" data-layer="widget-container">
      <div id="_pi_surveyWidget"
           role="application"
           survey-widget-type="dockedwidgetsurvey"
           data-question-type={questionType}>
        <span className="_pi_accessibilityHidden">Survey</span>

        <div className="_pi_closeButton" aria-label="Close Survey" role="button">×</div>

        <div className="_pi_widgetContentContainer" data-layer="widget-body">
          {children}
        </div>

        <a className="_pi_branding" target="_blank" href="https://www.pulseinsights.com">
          Crafted with Pulse Insights
        </a>
      </div>
    </div>
  );
}
```

This wrapper matches Pulse structure and provides consistent `data-layer="widget-container"` and `data-layer="widget-body"` placement.

---

### **13.1.4 Single-Choice (Standard Buttons) Template**

Base markup from your file:
**`single_choice_standard_buttons.html`**

Wrap the inner markup with `<DockedShell>`:

```tsx
export function renderDockedSingleStandardDesktopPulseV1() {
  return (
    <DockedShell questionType="single_choice_question">
      <div className="_pi_question _pi_question_single_choice_question" 
           id="_pi_question_0"
           data-layer="question-text">
        Standard Buttons
      </div>

      <div className="_pi_scale_container _pi_scale_container_before" aria-hidden="true">
        <span>{/* Scale labels (if any) */}</span>
      </div>

      <ul className="_pi_answers_container" data-layer="answers-container">
        {/* For each answer option: */}
        <li data-layer="single-choice-default">
          <a role="button">
            <label>Answer 1</label>
          </a>
        </li>
        <li data-layer="single-choice-active">
          <a role="button">
            <label>Answer 2</label>
          </a>
        </li>
        {/* Additional li… */}
      </ul>

      <div className="_pi_scale_container _pi_scale_container_after" aria-hidden="true">
        <span></span>
      </div>
    </DockedShell>
  );
}
```

Notes:

* Active-state markup (`single-choice-active`) reflects actual Pulse initial state and may be styled by SCSS tokens.
* This template should be **static** (no internal state yet). Interact mode can toggle selection visually through CSS classes if desired, but this is optional for Phase 5.0a.

---

### **13.1.5 Thank-You Template**

From your file:
**`thank_you.html`**

Template:

```tsx
export function renderDockedThankYouDesktopPulseV1() {
  return (
    <DockedShell questionType="thank_you">
      <div className="_pi_thankYouSurvey" data-layer="thank-you-text">
        Thank you!
      </div>
    </DockedShell>
  );
}
```

Simple and fully compatible with existing layer tooling.

---

### **13.1.6 Pulse-Specific Layer Definitions**

Create new entries, e.g.:

`src/layers/pulse/dockedSingleStandard.ts`

```ts
export const dockedSingleStandardPulseLayersDesktopV1: LayerDefinition[] = [
  {
    id: "widget-container",
    displayName: "Widget Container",
    selector: "[data-layer='widget-container']",
    group: "widget",
    mappings: [
      { tokenPath: "components.widget.bodyBg", role: "background" }
    ]
  },
  {
    id: "widget-body",
    displayName: "Widget Body",
    selector: "[data-layer='widget-body']",
    group: "widget",
    mappings: [
      { tokenPath: "components.widget.bodyFg", role: "text" }
    ]
  },
  {
    id: "question-text",
    displayName: "Question Text",
    selector: "[data-layer='question-text']",
    group: "question",
    mappings: [
      { tokenPath: "typography.body.fontFamily", role: "text" },
      { tokenPath: "typography.body.fontSize", role: "size" }
    ]
  },
  {
    id: "single-choice-default",
    displayName: "Single Choice (Default)",
    selector: "[data-layer='single-choice-default']",
    group: "question",
    mappings: [
      { tokenPath: "components.singleChoice.default.bg", role: "background" },
      { tokenPath: "components.singleChoice.default.fg", role: "text" },
      { tokenPath: "components.singleChoice.default.border", role: "border" }
    ]
  },
  {
    id: "single-choice-active",
    displayName: "Single Choice (Active)",
    selector: "[data-layer='single-choice-active']",
    group: "question",
    mappings: [
      { tokenPath: "components.singleChoice.active.bg", role: "background" },
      { tokenPath: "components.singleChoice.active.fg", role: "text" },
      { tokenPath: "components.singleChoice.active.border", role: "border" }
    ]
  }
];
```

And for thank-you:

`src/layers/pulse/dockedThankYou.ts`

```ts
export const dockedThankYouPulseLayersDesktopV1: LayerDefinition[] = [
  {
    id: "thank-you-text",
    displayName: "Thank You Text",
    selector: "[data-layer='thank-you-text']",
    group: "widget",
    mappings: [
      { tokenPath: "typography.heading.fontFamily", role: "text" },
      { tokenPath: "typography.heading.fontSize", role: "size" }
    ]
  }
];
```

---

### **13.1.7 SCSS Integration (Theme Application)**

Update or add a SCSS partial matching Pulse DOM:

* `._pi_widgetContentContainer` → widget body tokens
* `. _pi_question_single_choice_question` → question text tokens
* `. _pi_answers_container li[data-layer="single-choice-default"]` → use default tokens
* `. _pi_answers_container li[data-layer="single-choice-active"]` → use active tokens
* `. _pi_thankYouSurvey` → thank-you styles via heading tokens

Ensure SCSS imports into the compiled preview CSS.

---

### **13.1.8 Advanced Configuration**

Update Advanced Config drop-downs to show the new Pulse templates:

* For `docked` + `single-choice-standard` + `desktop`:

  * “Lab v1” (existing)
  * “Pulse v1” (new)
* For `docked` + `thank-you` + `desktop`:

  * “Pulse v1”

Selecting “Pulse v1” must route to the new templates.

---

### **13.1.9 Non-Goals**

* No mobile templates yet (mobile comes in 5.0b/5.0c).
* No radio-button / dropdown / multiple-choice templates.
* No free-text templates.
* No intro / multi-step.
* No live Pulse JS snippet execution.
* No Pulse CSS imports (you re-theme using your own SCSS).

Those are addressed in subsequent micro-phases.