# Theme Generator Parity Plan

Date: 2025-10-29 00:15 (Mountain Time)

## Objective

Elevate the generated CSS output so it aligns with curated themes (e.g., `crocs_theme.css`) across baseline scaffolding, layout systems, question types, widgets, and legacy browser coverage.

## Workstreams & Subtasks

1. **Baseline Scaffold & Defaults**
   1. Audit curated “DEFAULT START” blocks to catalogue required resets and container rules.
   2. Implement `generateBaseScaffoldCSS()` that emits appearance, box-sizing, container borders, and widget typography.
   3. Wire the helper into `stringifyThemeCSS` (Node + browser builds) ahead of variables; add unit coverage if feasible.
   4. Re-run diff to confirm the top of generated CSS matches curated scaffolding.

2. **Answer Layout Fidelity**
   1. Extend `generateAnswerLayoutCSS` to include `div#_pi_surveyWidget …` wrapper selectors and vendor-prefixed displays.
   2. Emit per-row width blocks using the curated table and add legacy flex declarations (`-webkit-flex`, `-moz-box-flex`).
   3. Layer in mobile/all-at-once overrides and ensure `gap` values mirror curated `var(--pi-gap-*)` usage.
   4. Add optional modern layout support behind feature flags without breaking legacy output.
   5. Diff fixed/variable sections against curated files; adjust until only comments/ordering differ.

3. **Question-Type Modules**
   1. Create helper functions for single-choice (radio), multiple-choice (checkbox), free text, dropdown/select, custom content, and NPS.
   2. Port hover/focus states, placeholder styling, tile-mode radios, and `.all-at-once` selectors from curated CSS into each helper.
   3. Ensure mobile duplicates (`div#_pi_surveyWidgetContainer.mobile-enabled …`) are emitted alongside desktop rules.
   4. Integrate helpers into `stringifyThemeCSS` beneath the answer layout block and perform targeted diffs for each question type.

4. **Slider & Specialized Widgets**
   1. Build `generateSliderCSS()` that mirrors curated noUi styles (container sizing, pip labels, markers, engaged states).
   2. Add per-answer-count selectors (`data-possible-answers`) and slider submit button container styling.
   3. Hook slider CSS into the question-type section or as a dedicated block; diff slider subsections against curated output.
   4. Identify any other specialized widgets (e.g., rating scales) and repeat the porting process.

5. **CTA, Branding, Invitation/Thank-You**
   1. Expand CTA helper to include hover/focus, disabled states, and legacy selectors (desktop + mobile).
   2. Emit branding link overrides and invitation/thank-you blocks with mobile variants.
   3. Add consent-banner hiding snippets if curated files depend on them.
   4. Diff CTA and UI element sections against curated files to confirm parity.

6. **Legacy / Prefix Coverage**
   1. Inventory vendor-prefixed declarations in curated files (e.g., `-webkit-box`, `-moz-box-flex`).
   2. Add a utility for emitting prefixed declarations to keep generator code maintainable.
   3. Backfill other legacy selectors (`div[data-answer-widths] ul`, older container forms) across helpers.
   4. Run diffs to ensure prefixed lines now match the curated output.

7. **Verification & Diffing**
   1. Regenerate `preview/styles/examples/generated-for-diff/*.css` after each workstream finishes.
   2. Use `diff -u` against curated themes and document residual gaps in a running checklist.
   3. Smoke-test preview widgets (desktop + mobile) across question types/layouts to catch visual regressions.
   4. Final pass: ensure generator output is stable, comment structure is consistent, and both builds stay synchronized.

## Dependencies/Notes

- Keep `theme-generator/src/theme-css.js` and `preview/basic/theme-css.js` synchronized after each change.
- Maintain ASCII output; leverage existing helper structure to avoid duplication.
- Prioritize regression safety: run preview smoke tests before marking the parity workstream complete.
