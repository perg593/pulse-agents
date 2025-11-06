# Theme Generator Token Implementation Plan

## Goals

- Translate the legacy token inventory into a modern, semantic design-token layer that feeds the new, demo-focused theme generator.
- Ensure the generator emits browser-ready CSS variables that approximate production styling across widget and question types without requiring a build step.
- Provide light-touch migration notes for legacy assets while prioritizing a fast workflow for non-technical users who need to showcase survey themes quickly.

## Inputs

- Reference analysis: `docs/plan/2025-10-29_1110 theme-framework-token-reference.md`
- Legacy SCSS sources (`sass-framework/01-css-pulse/*.scss`, `/02-css-clients/**`)
- Existing generator code (`theme-generator/src`, `preview/basic/theme-css.js`)

## Deliverables

1. **Design Token Schema**
   - JSON (or JS module) describing semantic tokens with desktop/mobile variants, states, and “core vs. advanced” flags for UI exposure.
   - Mapping table from legacy token names (`$color-2`) to new schema keys for reference when approximating existing themes, including new global shape/accessibility tokens (e.g., `$btn-border-radius`, focus outlines).

2. **Generator Enhancements**
   - Browser-side CSS generator that produces custom-property (CSS variable) bundles for each theme variation and injects them into previews.
   - Selector coverage for modern markup, with an optional legacy `_pi_` layer that can be toggled on for archival demos.
   - State machine logic mirroring the 2025 `standardButton` mixin so hover/selected/active/focus interactions can be expressed via CSS variables instead of duplicated rules.

3. **Migration Toolkit**
   - Lightweight script or documented workflow that ingests legacy client overrides and outputs suggested token JSON plus comparison notes.
   - Optional compatibility stylesheet for legacy embeds when running side-by-side demos (no automated repo writes).

4. **Documentation**
   - Developer notes describing how to extend the token schema and generator modules.
   - User-facing guide focused on the quick-demo flow (analyze site → adjust core tokens → preview/download).

## Workstreams & Tasks

### 1. Token Schema Definition

- **Audit Legacy Tokens:** Parse `_variables.scss` and client overrides to enumerate unique token roles.
- **Semantic Renaming:** Propose new token IDs (`color.answer.single.bg.default`) and store in `theme-generator/src/tokens/schema.json`, tagging each as `core` or `advanced`.
- **State Modeling:** Add structures for state (`default`, `hover`, `focus`, `error`) and device (`desktop`, `mobile`) so demos can react consistently across interactions.
- **Accessibility Tokens:** Fold in focus-outline variables and global radii inspired by `_modules/_focusStates.scss` and `exampleVariables.scss`.
- **Validation Tooling:** Build a lint script that checks token files for required keys and warns when advanced-only tokens are missing.

### 2. Generator Core Updates

- **Token Loader:** Replace hard-coded constants in `preview/basic/theme-css.js` with helpers reading from the schema and returning CSS custom property sets.
- **Widget Modules:** Create per-widget builders (`buildTopbarCSS`, `buildDockedCSS`, etc.) that accept token subsets and output scoped selectors.
- **Question Modules:** Introduce dedicated functions for single-choice, multi-choice, free-text, slider, NPS, and custom content styling.
- **Answer Layout Engine:** Implement `generateAnswerLayoutCSS` covering legacy `data-answer-widths` and modern `data-answers-layout` attributes with responsive duplicates.
- **Interaction States:** Add hover/focus/AAO rules using tokenized values rather than baked constants.
- **Logo Color Harvesting:** Extend analysis to detect likely logo assets (inline SVG, `<img>`/background images referencing “logo”, favicons/OG images) and extract dominant colors via canvas sampling or SVG `fill`/`stroke` parsing; feed these swatches into the token suggestions when CSS lacks brand colors.
- **Button State Engine:** Reproduce the `standardButton` pattern by emitting CSS variables for default/hover/selected/active/focus states and wiring them to the appropriate selectors.
- **Focus Utilities:** Generate optional focus-style overlays (outline color, width, offset, border-radius) similar to `_modules/_focusStates.scss`, letting demos toggle accessibility emphasis.
- **Output Optimization:** Emit CSS variables and scoped rules that work without `!important`; legacy selectors remain optional add-ons for advanced previews.

### 3. Migration & Compatibility

- **Legacy Mapping Script:** Provide a read-only CLI (or documented script) that reads `/02-css-clients/**/_default-1-variables.scss`, outputs suggested token JSON, and highlights unmapped values.
- **Diff Reports:** Generate comparison summaries (css diff or visual notes) to show how closely the new output matches legacy themes—informational only.
- **Fallback Stylesheet:** Maintain an optional layer that maps new tokens back onto `_pi_` selectors for archives; ship it separately so the default demo payload stays lean.
- **Toggle Strategy:** Add generator options to include/exclude the legacy layer and advanced question types, keeping the default experience fast and understandable.

### 4. Documentation & UI Integration

- **Developer Docs:** Update `/docs/theme-generator/` (or create equivalent) explaining schema, builder modules, and contribution workflow.
- **UI Wiring:** Ensure new tokens and CSS outputs pipe through the dedicated interface (`/preview/theme-generator/app.js`) with instant previews for each widget/question type.
- **Preset & Advanced UX:** Implement preset dropdowns and an “Advanced settings” accordion so non-technical users can stop at the essentials while experts can dive deeper.
- **Testing Matrix:** Document required QA scenarios (widget type × question type × state × device) and integrate them into manual tests; automated coverage can focus on generator output snapshots.

## Milestones

| Milestone | Target | Summary |
| --- | --- | --- |
| Token schema draft | Week 1 | Produce semantic token file, core/advanced tagging, and review with design/dev. |
| Generator core refactor | Week 2 | Implement token-driven builders emitting CSS variables and preview injection, including button state engine scaffolding. |
| Answer layout & interactions | Week 3 | Complete layout engine, hover/focus coverage (focus utility overlay), optional legacy layer. |
| Demo UX & presets | Week 4 | Wire schema into UI, create presets, advanced accordion, and quick-download flow. |
| Migration notes (optional) | Week 5 | Ship read-only mapping script and comparison summaries (can slip if demo goals met sooner). |

## Risks & Mitigations

- **Selector Drift:** Modern embeds may not use `_pi_` IDs. Mitigation: maintain selector abstraction layer and allow per-project overrides.
- **Token Explosion:** Legacy tokens are verbose; standardize naming and allow optional/advanced groups to keep base schema manageable.
- **Regression Potential:** Refactor touches core CSS output. Mitigation: snapshot testing against curated CSS and legacy exports.
- **Client Overrides:** Legacy overrides might contain bespoke values outside the base schema. Provide escape hatches (`custom.css` injection) and log unmapped tokens during migration.
- **Non-technical Workflows:** Too many exposed controls can overwhelm demo users. Mitigation: prioritize presets and keep advanced settings hidden by default.

## Decisions

- **Output Format:** Move fully to CSS variables with runtime theming; no SCSS export in the primary flow.
- **Migration Behavior:** Offer read-only reports and token JSON suggestions; do not write back to client repositories automatically.
- **Advanced Tokens UX:** Keep a slim “core” control set front-and-center, with advanced geometry/spacing controls behind an optional accordion and documented expert path.
