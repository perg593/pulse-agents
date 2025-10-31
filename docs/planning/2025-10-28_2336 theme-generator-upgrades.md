# Theme Generator CSS Enhancement Plan

## Overview

Update `theme-generator/src/theme-css.js` and `preview/basic/theme-css.js` to generate production-ready CSS that matches the structure and completeness of the curated CSS files in `preview/styles/examples/curated/`.

## Current State

The existing `theme-css.js` generates basic theme CSS with:

- CSS custom properties (variables)
- Basic widget shells and typography
- Simple answer container spacing
- Radio button styles (dot/tile modes)
- Basic input and button styling

**Missing:** Comprehensive answer layout patterns, all question types, legacy compatibility, and complete responsive behaviors.

## Required Enhancements

### 1. Answer Layout System

Add complete CSS generation for answer distribution and alignment:

**A. Legacy System (data-answer-widths)**

- `data-answer-widths="fixed"` - Fixed width layout with per-row configurations (1-14)
- `data-answer-widths="variable-left"` - Variable width, left-aligned
- `data-answer-widths="variable-center"` - Variable width, center-aligned

**B. Modern System (data-answers-layout + data-answers-alignment)**

- `data-answers-layout="fixed"` with `data-answers-per-row="1"` through `"14"`
- `data-answers-layout="variable"` with min-width constraints
- `data-answers-alignment` values: `left`, `center`, `right`, `space-between`, `space-around`, `space-evenly`

**Implementation in theme-css.js:**

- Introduce a `FIXED_WIDTH_PERCENTAGES` constant that captures the curated flex values instead of recomputing with `calc`. Use the table below verbatim for both `flex-basis`/`max-width` pairs:

  | answers-per-row | width |
  | --- | --- |
  | 1 | `86%` (with `margin: 5px 7% !important`) |
  | 2 | `48%` |
  | 3 | `31.5%` |
  | 4 | `23%` |
  | 5 | `18%` |
  | 6 | `14.5%` |
  | 7 | `12.25%` |
  | 8 | `10.5%` |
  | 9 | `9.1%` |
  | 10 | `8%` |
  | 11 | `7%` |
  | 12 | `6.3%` |
  | 13 | `5.6%` |
  | 14 | `5.1%` |

  All rows beyond the single-column case keep the curated `margin: 5px 0.9% !important`.

- Generate rule blocks with the same specificity tiers used by the curated themes. Each logical rule needs the following selector permutations:
  1. `#_pi_surveyWidgetContainer ul._pi_answers_container[...]`
  2. `div#_pi_surveyWidgetContainer.mobile-enabled ul._pi_answers_container[...]`
  3. `div[data-answer-widths="…"] ul._pi_answers_container[...]`
  4. `div[data-answer-widths="…"][data-answers-per-row="…"] ul._pi_answers_container li`
  5. Optional `div#_pi_surveyWidgetContainer div#_pi_surveyWidget ...` wrappers for cases where curated CSS nests through the widget element (e.g. slider, alignment tweaks).

  Build a small helper inside `generateAnswerLayoutCSS` to emit the legacy (`data-answer-widths`) block and then layer any modern `data-answers-layout` selectors on top so we deduplicate declarations while still matching markup specificity.

- Legacy coverage:
  * `div[data-answer-widths="fixed"] ul._pi_answers_container` + row-specific descendants using the width table.
  * `div[data-answer-widths="variable-left"]` and `div[data-answer-widths="variable-center"]` variants that set `justify-content` and `margin: 5px 1% !important`.
  * Legacy checkbox alignment (`div[data-answer-widths="fixed"] ul._pi_answers_container li label._pi-control-checkbox`).

- Modern coverage (current markup audit):
  * We only observe `data-answers-layout="variable"` on the `ul`, always paired with the legacy attributes for widths. Keep the generator ready to emit `data-answers-layout="fixed"` selectors, but gate them behind a check so we do not output empty branches today.
  * `data-answers-alignment` lives on `div#_pi_surveyWidget`, not the list. Add rules like `div#_pi_surveyWidgetContainer:not(.all-at-once) div#_pi_surveyWidget[data-answers-alignment="center"] ._pi_question` for text alignment, plus flexbox `justify-content` on the `ul` for the modern API.

- Mobile overrides come from duplicating the relevant rules under `div#_pi_surveyWidgetContainer.mobile-enabled` and adjusting min-widths (`60px` for variable answers) without dropping the desktop selectors.

- Emit `display:flex`/`flex-wrap` on the exact selectors from the curated CSS (`div[data-answer-widths="fixed"] ul._pi_answers_container`, etc.) so the generator’s output can override base widget styles without resorting to `!important` everywhere (we inherit the existing curated `!important` usage only where present).

### 2. Question Type Specific Styles

Add CSS for all question types with proper selectors:

**Question Types to Support:**

- `single_choice_question` - Radio buttons with various layouts
- `multiple_choices_question` - Checkboxes with styling
- `free_text_question` - Text inputs and textareas
- `slider_question` - Slider controls
- `custom_content_question` - Custom HTML content
- `nps_question` - Net Promoter Score (0-10 scale)

**Key Patterns from Curated CSS:**

- **Single choice / Radio**  
  - Toggle visibility of `. _pi_radio_button_outer` via `div[data-radio-button="off"]` and `div[data-radio-button="on"]`.  
  - Alignment selectors: `div[data-radio-button="off"] ul._pi_answers_container li a label` (center) vs. `div[data-radio-button="on"] ul._pi_answers_container li` (force `justify-content:flex-start`).  
  - NPS modifier: `ul._pi_answers_container[data-question-type="single_choice_question"][data-question-nps="t"] li` (tight spacing, `text-transform:none`, background tweaks) plus mobile duplicates.
- **Multiple choice / Checkbox**  
  - Base container: `#_pi_surveyWidgetContainer ul._pi_answers_container[data-question-type="multiple_choices_question"] li` (border, radius).  
  - Indicator state: `. _pi-control-indicator`, `. _pi-control-indicator::after`, and hover/active/focus variants.  
  - All-at-once duplicates: `div#_pi_surveyWidgetContainer.all-at-once ...` for simultaneous question view.
- **Free text**  
  - Field selectors: `div#_pi_surveyWidget div._pi_widgetContentContainer ul._pi_answers_container[data-question-type="free_text_question"] ._pi_free_text_question_field_container input[type="text"]`, same for textarea.  
  - Error states: `[aria-invalid="true"]` border overrides, placeholder styling, focus-visible handling.  
  - Character counter: `. _pi_free_text_question_characters_count`, `.danger`, `.error`, and mobile variant under `.mobile-enabled`.
- **Slider**  
  - Container: `ul._pi_answers_container[data-question-type="slider_question"] ._pi_slider_question_container` (padding, border).  
  - noUi details: `. _pi_slider .noUi-base`, `.noUi-connects`, `.noUi-handle`, `.noUi-pips .noUi-value`, `.noUi-pips .noUi-marker`.  
  - Engaged state: `. _pi_slider_question_container.engaged` ensures the active track color changes when the user touches the slider.  
  - Hidden input focus: `. _pi_hidden_slider:focus ~ ._pi_slider .noUi-handle` etc. for accessibility outlines, plus submit button container `. _pi_slider_question_submit_button_container`.
- **Custom content**  
  - `div#_pi_surveyWidget[data-question-type="custom_content_question"]` often removes padding/margins; ensure we expose knobs for background, typography, and brand link placement.
- **NPS (when backed by single choice)**  
  - `ul._pi_answers_container[data-question-nps="t"] li a label` (font weight, spacing).  
  - Scale container: `. _pi_scale` and `. _pi_answer_text` overrides, including mobile-specific paddings.

Map each selector group into dedicated helper generators (`buildRadioRules`, `buildFreeTextRules`, etc.) so the plan ties back to concrete implementation entry points.

### 3. Widget Type Specific Styles

Enhance widget-specific CSS generation for all 5 widget types:

**Widget Types:**

- `topbarsurvey` - Top bar with shadow
- `bottombarsurvey` - Bottom bar with shadow
- `dockedwidgetsurvey` - Docked widget (side)
- `inlinesurvey` - Inline embedded widget
- `fullscreensurvey` - Full screen overlay

**Current Implementation:** Basic widget shells exist in `buildWidgetRules()` function.

**Enhancement:** Ensure all widget types have proper defaults for:

- Background colors and borders
- Box shadows (for bar widgets)
- Padding and margins
- Z-index layering
- Close button visibility/opacity

### 4. All-At-Once Mode Support

Add CSS for the "all-at-once" display mode where multiple questions show simultaneously:

```css
div#_pi_surveyWidgetContainer.all-at-once 
._pi_answers_container[data-question-type="multiple_choices_question"]
li label._pi-control._pi-control-checkbox {
  color: var(--pi-text);
}
```

### 5. Responsive Behavior

Ensure mobile-specific overrides are comprehensive:

- Mobile typography sizes (already exists via `modes.mobile`)
- Mobile answer min-widths (add to answer layout section)
- Mobile button padding (already exists)
- Mobile gap spacing (already exists)

### 6. Additional UI Elements

Add CSS for elements currently missing:

**Invitation Screen:**

```css
div._pi_invitationTextContainer {
  color: var(--pi-text);
  font-family: var(--pi-font);
  font-size: var(--pi-question-size);
  text-align: center;
}
```

**Thank You Screen:**

```css
div._pi_thankYouSurvey {
  color: var(--pi-text);
  font-family: var(--pi-font);
  font-size: var(--pi-question-size);
  text-align: center;
}
```

- **CTA Buttons:** The generator already ships the curated start/submit button block (`#_pi_surveyWidgetContainer a._pi_startButton`, etc.). Keep the block in place but refactor it into `generateCTACSS()` so invitation/thank-you additions do not duplicate padding/color rules. Confirm hover/active states match curated examples and extend only if we find missing selectors.

## Implementation Steps

### Step 1: Update theme-css.js Structure

Modify `theme-generator/src/theme-css.js` (and sync to `preview/basic/theme-css.js`):

1. Define shared constants (`FIXED_WIDTH_PERCENTAGES`, selector templates) near the top of the module so both generator builds stay in sync.
2. Add `generateAnswerLayoutCSS()` after line ~540, using the constants and selector helper described above.
3. Add `generateQuestionTypeCSS()` for question-specific styles (radio, checkbox, free text, slider, NPS, custom content).
4. Add `generateUIElementsCSS()` for invitation/thank-you copy and `generateCTACSS()` that encapsulates the existing start/submit button rules.
5. Update `stringifyThemeCSS()` to include all new sections in curated order.

### Step 2: Insert Generated CSS in Proper Order

Update the `stringifyThemeCSS()` return statement to match curated file structure:

```javascript
return `
/* === Pulse Insights Theme: ${cssEsc(theme.name || 'Custom')} === */

/* CSS Variables */
#_pi_surveyWidgetContainer { ... }

/* Widget Shells */
${widgetCSS}

/* Close Button */
...

/* Typography & Content */
...

/* Answer Layout System */
${generateAnswerLayoutCSS(theme)}

/* Question Type Specific */
${generateQuestionTypeCSS(theme)}

/* UI Elements */
${generateUIElementsCSS(theme)}

/* Radio Buttons */
...

/* Inputs & Buttons */
...

/* Mobile Responsive */
@media ... { ... }
`;
```

### Step 3: Validate Against Curated Examples

After implementation:

1. Generate test themes for known sites (e.g., IKEA, Crocs, Bayer)
2. Compare generated CSS structure to curated files
3. Verify all selectors are present
4. Test with preview widgets to ensure visual correctness

## Files to Modify

1. **`theme-generator/src/theme-css.js`** - Primary implementation (Node.js version)
2. **`preview/basic/theme-css.js`** - Browser version (keep in sync)

## Success Criteria

- Generated CSS includes all answer layout patterns (fixed 1-14, variable with all alignments)
- All question types have proper styling
- All widget types have complete CSS
- Legacy `data-answer-widths` system is supported
- Modern `data-answers-layout` + `data-answers-alignment` system is supported
- Mobile responsive overrides are comprehensive
- Generated CSS structure matches curated examples
- No visual regressions in preview widgets

## Testing Strategy

1. Generate themes for test sites
2. Apply generated CSS to preview widgets
3. Test all widget types (topbar, bottombar, docked, inline, fullscreen)
4. Test all question types (single choice, multiple choice, free text, slider, NPS)
5. Test all answer layouts (fixed 1-14 per row, variable with all alignments)
6. Test mobile responsive behavior
7. Compare visual output to curated examples
