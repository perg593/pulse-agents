# Old Pulse Theme Framework Token Reference

## Purpose

- Capture the complete token surface area exposed by the legacy CodeKit-based SCSS framework under `sass-framework/01-css-pulse`.
- Translate the plain-language comments ("Multiple-choice border", "Submit button bg hover", etc.) into a reusable knowledge base for the modern, demo-focused theme generator.
- Document where each legacy token is consumed so we can validate coverage, spot gaps, and decide which semantics are still relevant when producing quick "looks like your site" demos.

## Architecture Snapshot

- **Token Source:** `_variables.scss` defines raw values and includes explanatory comments for every widget part (`sass-framework/01-css-pulse/_variables.scss`).
- **Distribution Maps:** `_maps.scss` groups those values by component/state (backgrounds, typography, borders, spacing, etc.) so selectors can consume them.
- **Selector Dictionary:** `_selectors.scss` lists every DOM slice touched by the framework, including widget types, question types, pseudo-states, and mobile variants.
- **Rule Assembly:** `_theme-structure.scss` combines selector strings with the `@include builder(...)` mixin to emit the final CSS.
- **Client Overrides:** `/02-css-clients/{client}/_default-1-variables.scss` mirrors `_variables.scss`, confirming which tokens were expected to change per brand.
- **2025 Additions:** The updated drop (`sass-framework`) introduces helper modules (`02-css-clients/_modules`) for button states and focus outlines, plus `exampleVariables.scss` that demonstrates consolidated tokens (e.g., `$btn-border-radius`) and a CSS-variable driven approach to interactive states.

## Token Families & Semantics

### Foundational Color Roles

| Token | Legacy Comment | Usage Highlights |
| --- | --- | --- |
| `$color-1` | “Question, thank you, before/after question header” | Primary text for questions, thank-you, invitation, header copy. |
| `$color-1-alt` | Alternate headline/brand accent | Header hover states, emphasis text, character-count error color. |
| `$color-2` / `$color-2-font` | “Single-choice button bg / border”, etc. | Forms the base button and answer shell. `$color-2-font` handles button text legibility. |
| `$color-3` / `$color-3-font` | Hover states | Deployed on single-choice hover bg, submit hover, and close button hover. |
| `$color-4` / `$color-4-font` | Multi-choice default | Checkbox backgrounds/text. |
| `$color-5` / `$color-5-font` | Multi-choice hover | Checkbox hover backgrounds/text. |
| `$color-6` | Radio/checkbox inner | Fills inner dot/check, doubles as outer ring hover color. |
| `$color-7` | “Branding, character count, maximum selected” | Secondary informational text. |
| `$color-8` / `$color-9` | Free-text field & placeholder | Inputs/textarea default text and placeholder. |

Backdrops, branding blocks, and widget shells inherit from `$background-1`/`$background-2`, showing a clear expectation for dual-surface theming (primary vs. fullscreen/custom).

### Typography Roles

- **Large (`$font-lg-*`):** Questions, thank-you, invitation. Includes mobile overrides (`$font-lg-size-mobi`) and AAO-alignment tokens.
- **Header (`$font-header-*`):** “Before/After question header” callouts.
- **Scale (`$font-scale-*`):** Slider/NPS scale labels.
- **Medium (`$font-md-*`):** Single/multi-choice text, custom content, and poll titles. Hover/focus variants keep text legible against changed backgrounds.
- **Small (`$font-sm-*`):** Branding footers, character counts, limit notices, progress indicators, with dedicated hover color for links.
- **Button (`$font-button-*`):** Submit/invitation buttons share medium metrics but independent family/weight toggles.
- **Close (`$close-*`):** Independent size/line-height per widget presentation, plus mobile overrides.

### Structural Tokens

- **Spacing:** Every major element (answers container, invitation, branding, question block) has paddings and margins with mobile counterparts (`$question-default-padding`, `$button-padding-lg`, `$branding-margin`, etc.).
- **Sizing:** Width/min/max tokens handle responsive constraints (widget containers, buttons, invitation, media).
- **Borders & Radii:** Widgets, answers, radio rings, checkboxes, submit buttons each get independent border width/color/style/radius entries, often with hover states.
- **Global Radii (2025):** `exampleVariables.scss` introduces `$btn-border-radius` and pipes it into answer options and buttons, hinting at a higher-level “shape” token the generator should expose.
- **Box Shadows & Z-Index:** Widget type-specific shadows (`$shadow-docked`) and stacking context tokens (`$z-index-widget-docked`).
- **Opacity:** Limited usage (`$opacity-widget-custom`) but signals the framework expected dialable transparency per widget.

### Interaction & State Tokens

- **Answer States:** Distinguish `single-choice` vs. `multi-choice` backgrounds, border colors, hover states, and text padding for radio vs. non-radio answers.
- **Radio Buttons:** Nested tokens control outer/inner ring colors, hover behavior, width/margin overrides, broadcasting the need for separate state management in the generator.
- **Checkboxes:** Equivalent granularity for outer box, checkmark dimensions, hover transitions, and mobile offsets.
- **Buttons:** Submit/Invitation cover color, border, radius, line-height, alignment, plus hover decorations.
- **Button State Mixins (2025):** `_modules/_buttonMixins.scss` wraps these states in a mixin that sets CSS custom properties (`--standard-btn-fill`, `--standard-btn-border`, etc.) for default/hover/selected/active/focus combinations—evidence that a modern implementation can drive interactions via custom properties rather than raw declarations.
- **Close Button:** Background/margin/padding/size for each widget mode, with hover tokens to control accent color change.
- **All-at-Once Mode:** Inline comments and selectors show multi-question context, confirming that all token groups must work under `div#_pi_surveyWidgetContainer.all-at-once`.
- **Focus States (2025):** `_modules/_focusStates.scss` defines reusable `@mixin focusStyles` and `@mixin setupFocusStyles`, applying consistent `:focus-visible` handling across answers, inputs, sliders, and submit buttons. These mixins expect configurable outline color/width/offset and reuse `$btn-border-radius`, suggesting focus styling belongs inside the token set.

### Widget-Type Coverage

Tokens exist for default, inline, bottombar, docked, topbar, and fullscreen widgets, each with unique background, border, radius, shadow, padding, margin, and z-index values. This reinforces the need for the theme generator to emit widget-scoped CSS rather than assuming a single presentation.

## Selector Groupings That Matter

- **Widget Containers:** `div#_pi_surveyWidget` variants for each widget type, with separate mobile selectors.
- **Card Types:** Each question type gets a selector cluster (`data-question-type="single_choice_question"`, etc.), indicating generator output must target type + state combos.
- **Pseudo States:** Hover/focus/after selectors for close buttons, answers, and branding links show how the tokens map to specific interactions.
- **Answer Layout:** Legacy `data-answer-widths="..."` and AAO selectors highlight the importance of covering both historical and modern data attributes.
- **Mobile Mirroring:** Every selector has a `.mobile-enabled` counterpart, signaling the need for systematic mobile variants in generated CSS.

## Demo-Oriented Extraction Guidance

1. **Token Taxonomy Backbone**
   - Use the legacy comments as canonical descriptions when defining new design tokens (e.g., `color.answer.single.bg.default`).
   - Retain separation between component types and state (default vs. hover vs. focus) since the old framework exposes them explicitly.
   - Flag “instant impact” tokens (primary text, backgrounds, button styles) for front-and-center exposure in the demo UI; relegate geometry/details to advanced controls.

2. **Widget Presentation Layer**
   - Generate per-widget CSS blocks with discrete tokens for background, border, shadow, radius, padding, and z-index.
   - Ensure close button spacing/size tokens are parameterized per widget mode, including fullscreen-specific adjustments.

3. **Question & Answer Recipes**
   - Model radio vs. checkbox vs. free-text requirements separately.
   - Capture radio-on/off, hover, and multi-choice checkmark geometry as tokenized structures for the generator.
   - Account for AAO selectors to keep consistent styling when multiple questions render simultaneously.

4. **Typography & Hierarchy**
   - Provide generator knobs for large/header/scale/medium/small/button/close typography groups with desktop + mobile overrides.
   - Preserve per-role alignment/transform/decoration tokens to avoid hardcoding assumptions into templates.

5. **Responsive Strategy**
   - Mirror the legacy `.mobile-enabled` sections by producing mobile overrides whenever desktop tokens diverge (font size, padding, margins, widths).

6. **Legacy Compatibility Layer**
   - Maintain the ability to output selectors that match the CodeKit era markup (`data-answer-widths`, `_pi_` classes) so demo themes can be previewed against archived widgets when needed.
   - Keep a separate modern selector strategy (`data-answers-layout`, new class names) so the generator can support both without duplicating logic, but make legacy selectors optional to keep demo payloads light.
   - Consider offering mixin-style “overlays” (akin to `_modules/_focusStates.scss`) for accessibility or regulatory tweaks so demos can toggle them without regenerating the entire theme.

## Practical Reuse Patterns

- **Token Normalization:** Convert `$color-2` style names into semantic references in the new system while keeping the mapping table for legacy migration.
- **Value Catalog:** Treat `_variables.scss` as the exhaustive list of knobs that client teams expected; no new generator should expose fewer configuration points without explicit deprecation decisions.
- **Demo Defaults:** Pre-populate token groups with curated defaults that “look good” out of the box so non-technical users can generate believable mockups without touching every knob.
- **Audit Checklist:** When adding new generator features (e.g., slider support, NPS), cross-check against selector groups in `_selectors.scss` to ensure all surfaces are covered.
- **Module Inspiration:** Treat `_modules/_buttonMixins.scss` and `_modules/_focusStates.scss` as UX patterns—state-driven CSS variables and consistent focus outlines—that the generator can replicate with lighter-weight output.
- **Asset-Based Branding:** When CSS inspection misses brand colors (e.g., logos embedded as images/SVGs), plan to sample dominant colors from those assets—canvas analysis for rasters and `fill`/`stroke` parsing for SVGs—to keep the generator’s palette faithful.

## Known Gaps / Cautions

- Many outputs rely on `!important` to beat upstream CSS. Plan to adjust specificity in the generator so we can minimize `!important` use.
- Selector strings rely on hard-coded IDs (`div#_pi_surveyWidget`), which may not exist in modern embeds; document required adapters when porting tokens.
- Client overrides replicate the full token file, implying that per-brand changes were manual and prone to drift. Design future tooling around diffable token sets rather than full file copies.
- The legacy value ranges may produce overly subtle differences; define guardrails (min/max, sensible defaults) so demo users see immediate visual feedback when tweaking tokens.
- The 2025 modules show deeper reliance on CSS custom properties—ensure the new generator resolves token conflicts (e.g., hover vs. selected) in an order that mirrors these patterns so demos behave predictably.
