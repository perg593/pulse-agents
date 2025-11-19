import {
  TOKEN_SCHEMA,
  CORE_TOKEN_PATHS,
  DEFAULT_TOKEN_VALUES,
  applyTokenDefaults,
  buildCssVariableMap,
  getPath,
  setPath
} from '../theme-generator/tokens/schema.js';

const DEFAULT_OPTIONS = {
  includeLegacyLayer: false,
  includeFocusStyles: true,
  includeSliderStyles: true,
  includeAllAtOnceStyles: true
};

const REQUIRED_FIELDS = CORE_TOKEN_PATHS.map((path) => ({
  path,
  description: path.join('.'),
  type: 'string'
}));

const DEFAULTS = DEFAULT_TOKEN_VALUES;

/**
 * Fixed width percentages for answers-per-row configurations
 * Based on curated CSS patterns from production themes
 */
const FIXED_WIDTH_PERCENTAGES = {
  1: '86%',      // Special case: margin 5px 7%
  2: '48%',
  3: '31.5%',    // Default for fixed layout
  4: '23%',
  5: '18%',
  6: '14.5%',
  7: '12.25%',
  8: '10.5%',
  9: '9.1%',
  10: '8%',
  11: '7%',
  12: '6.3%',
  13: '5.6%',
  14: '5.1%'
};

const cssEsc = (value) => String(value ?? '').replace(/[\n\r]+/g, ' ');

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function parseColor(value) {
  if (typeof value !== 'string') return null;
  const input = value.trim();
  if (!input || input.toLowerCase() === 'transparent') return null;
  if (/^#([\da-f]{3}|[\da-f]{6})$/i.test(input)) {
    const hex = input.slice(1);
    const expand = hex.length === 3 ? hex.split('').map((c) => c + c).join('') : hex;
    const intValue = parseInt(expand, 16);
    if (Number.isNaN(intValue)) return null;
    return {
      r: (intValue >> 16) & 255,
      g: (intValue >> 8) & 255,
      b: intValue & 255
    };
  }
  const rgbMatch = input.match(/^rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)(?:\s*,\s*([\d.]+))?\s*\)$/i);
  if (!rgbMatch) return null;
  return {
    r: clampChannel(parseFloat(rgbMatch[1])),
    g: clampChannel(parseFloat(rgbMatch[2])),
    b: clampChannel(parseFloat(rgbMatch[3]))
  };
}

function clampChannel(value) {
  return Math.round(Math.max(0, Math.min(255, value)));
}

function relativeLuminance(rgb) {
  if (!rgb) return 0;
  const channel = (c) => {
    const v = c / 255;
    return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
  };
  const [sr, sg, sb] = [channel(rgb.r), channel(rgb.g), channel(rgb.b)];
  return 0.2126 * sr + 0.7152 * sg + 0.0722 * sb;
}

function contrastRatio(a, b) {
  const [lumA, lumB] = [relativeLuminance(a), relativeLuminance(b)];
  const [lighter, darker] = lumA >= lumB ? [lumA, lumB] : [lumB, lumA];
  return (lighter + 0.05) / (darker + 0.05);
}

function rgbToHex({ r, g, b }) {
  const toHex = (channel) => {
    const hex = channel.toString(16);
    return hex.length === 1 ? `0${hex}` : hex;
  };
  return `#${toHex(r)}${toHex(g)}${toHex(b)}`;
}

function lighten(color, amount = 0.18) {
  const rgb = parseColor(color);
  if (!rgb) return color;
  const factor = Math.max(0, Math.min(1, amount));
  const mix = (channel) => clampChannel(channel + (255 - channel) * factor);
  return rgbToHex({ r: mix(rgb.r), g: mix(rgb.g), b: mix(rgb.b) });
}

function darken(color, amount = 0.18) {
  const rgb = parseColor(color);
  if (!rgb) return color;
  const factor = Math.max(0, Math.min(1, amount));
  const mix = (channel) => clampChannel(channel * (1 - factor));
  return rgbToHex({ r: mix(rgb.r), g: mix(rgb.g), b: mix(rgb.b) });
}

function valueOr(tokens, path, fallback) {
  const value = getPath(tokens, path);
  return value === undefined || value === null || value === '' ? fallback : value;
}

function ensureOnPrimary(tokens) {
  const primary = parseColor(tokens.colors.primary);
  if (!primary) return;
  const desired = tokens.colors.onPrimary;
  const defaultContrast = desired ? contrastRatio(primary, parseColor(desired)) : 0;
  if (desired && defaultContrast >= 4.5) return;
  const whiteContrast = contrastRatio(primary, parseColor('#ffffff'));
  const darkContrast = contrastRatio(primary, parseColor('#111827'));
  tokens.colors.onPrimary = whiteContrast >= darkContrast ? '#ffffff' : '#111827';
}

function ensureButtonStates(tokens) {
  const states = tokens.states.button;
  const primary = tokens.colors.primary;
  const hover = tokens.colors.primaryHover || darken(primary, 0.1);
  const active = tokens.colors.primaryActive || darken(primary, 0.2);
  const onPrimary = tokens.colors.onPrimary;

  states.default.fill = valueOr(tokens, ['states', 'button', 'default', 'fill'], primary);
  states.default.border = valueOr(tokens, ['states', 'button', 'default', 'border'], `1px solid ${primary}`);
  states.default.shadow = valueOr(tokens, ['states', 'button', 'default', 'shadow'], '0 2px 6px rgba(37, 99, 235, 0.35)');
  states.default.color = valueOr(tokens, ['states', 'button', 'default', 'color'], onPrimary);

  states.hover.fill = valueOr(tokens, ['states', 'button', 'hover', 'fill'], hover);
  states.hover.border = valueOr(tokens, ['states', 'button', 'hover', 'border'], `1px solid ${hover}`);
  states.hover.shadow = valueOr(tokens, ['states', 'button', 'hover', 'shadow'], '0 4px 10px rgba(29, 78, 216, 0.30)');
  states.hover.color = valueOr(tokens, ['states', 'button', 'hover', 'color'], onPrimary);

  states.active.fill = valueOr(tokens, ['states', 'button', 'active', 'fill'], active);
  states.active.border = valueOr(tokens, ['states', 'button', 'active', 'border'], `1px solid ${active}`);
  states.active.shadow = valueOr(tokens, ['states', 'button', 'active', 'shadow'], '0 2px 4px rgba(30, 58, 138, 0.35)');
  states.active.color = valueOr(tokens, ['states', 'button', 'active', 'color'], onPrimary);

  states.focus.fill = valueOr(tokens, ['states', 'button', 'focus', 'fill'], hover);
  states.focus.border = valueOr(tokens, ['states', 'button', 'focus', 'border'], '2px solid #ffffff');
  states.focus.shadow = valueOr(tokens, ['states', 'button', 'focus', 'shadow'], '0 0 0 4px rgba(29, 78, 216, 0.25)');
  states.focus.color = valueOr(tokens, ['states', 'button', 'focus', 'color'], onPrimary);

  states.selected.fill = valueOr(tokens, ['states', 'button', 'selected', 'fill'], '#ffffff');
  states.selected.border = valueOr(tokens, ['states', 'button', 'selected', 'border'], `2px solid ${primary}`);
  states.selected.shadow = valueOr(tokens, ['states', 'button', 'selected', 'shadow'], '0 0 0 2px rgba(37, 99, 235, 0.2)');
  states.selected.color = valueOr(tokens, ['states', 'button', 'selected', 'color'], primary);
}

function ensureFocusDefaults(tokens) {
  if (!tokens.focus.radius || tokens.focus.radius === 'var(--pi-shape-control-radius)') {
    tokens.focus.radius = tokens.shape.controlRadius;
  }
}

function normalizeTokens(rawTokens = {}) {
  const tokens = applyTokenDefaults(rawTokens);
  ensureOnPrimary(tokens);
  ensureButtonStates(tokens);
  ensureFocusDefaults(tokens);
  return tokens;
}

function buildVariablesBlock(tokens) {
  const map = buildCssVariableMap(tokens);
  const lines = Object.entries(map).map(([name, value]) => `  ${name}: ${cssEsc(value)};`);
  return [
    '#_pi_surveyWidgetContainer {',
    ...lines,
    '}'
  ].join('\n');
}

function buildBaseCss(tokens, options) {
  const parts = [];
  const radioDisplay = tokens.answers.radioStyle === 'tile' ? 'none' : 'inline-flex';
  const radioAlign = tokens.answers.radioStyle === 'tile' ? tokens.answers.textAlignWhenRadioOff : tokens.answers.textAlignWhenRadioOn;

  parts.push(`
/* CSS Isolation: Reset common properties to prevent host page CSS interference */
#_pi_surveyWidgetContainer,
#_pi_surveyWidgetContainer *,
#_pi_surveyWidgetContainer *::before,
#_pi_surveyWidgetContainer *::after {
  box-sizing: border-box !important;
  -webkit-font-smoothing: antialiased !important;
  -moz-osx-font-smoothing: grayscale !important;
  appearance: none !important;
  -webkit-appearance: none !important;
  -moz-appearance: none !important;
}

/* Reset list styles specifically - high specificity to override host page rules */
#_pi_surveyWidgetContainer ul,
#_pi_surveyWidgetContainer ol,
#_pi_surveyWidgetContainer ul li,
#_pi_surveyWidgetContainer ol li,
#_pi_surveyWidgetContainer ._pi_answers_container,
#_pi_surveyWidgetContainer ._pi_answers_container li {
  list-style: none !important;
  list-style-type: none !important;
  margin: 0 !important;
  padding: 0 !important;
}

/* Reset typography properties on li elements that commonly get overridden by host pages */
/* Note: These are reset values - actual widget styles will override via more specific selectors */
#_pi_surveyWidgetContainer li {
  text-decoration: none !important;
  text-transform: none !important;
  letter-spacing: normal !important;
  word-spacing: normal !important;
}

/* Base container styles */
#_pi_surveyWidgetContainer,
#_pi_surveyWidgetContainer * {
  box-sizing: border-box;
  font-family: var(--pi-typography-font-family);
  color: var(--pi-color-text);
}

#_pi_surveyWidgetContainer {
  background-color: var(--pi-color-background);
  padding: 24px;
}

#_pi_surveyWidgetContainer ._pi_widgetContentContainer {
  display: flex;
  flex-direction: column;
  gap: var(--pi-layout-gap-row);
}

#_pi_surveyWidget {
  background-color: var(--pi-color-background);
  border-radius: var(--pi-shape-widget-radius);
  box-shadow: var(--pi-shadow-widget);
  padding: 24px;
}

#_pi_surveyWidget[survey-widget-type="bottombarsurvey"],
#_pi_surveyWidget[survey-widget-type="dockedwidgetsurvey"],
#_pi_surveyWidget[survey-widget-type="topbarsurvey"] {
  box-shadow: var(--pi-shadow-bar);
}

#_pi_surveyWidget ._pi_question {
  font-size: var(--pi-typography-size-question);
  font-weight: var(--pi-typography-weight-question);
  line-height: var(--pi-typography-line-height-question);
  margin: 0 0 16px;
  text-align: center;
}

#_pi_surveyWidget ._pi_question._pi_question_custom_content_question {
  font-size: var(--pi-typography-size-body);
  font-weight: var(--pi-typography-weight-body);
}

#_pi_surveyWidget ._pi_header {
  font-size: var(--pi-typography-size-caption);
  font-weight: var(--pi-typography-weight-caption);
  margin: 0;
  color: var(--pi-color-muted);
  text-align: center;
}

#_pi_surveyWidget ._pi_branding,
#_pi_surveyWidget ._pi_free_text_question_characters_count,
#_pi_surveyWidget ._pi_multiple_choices_count {
  font-size: var(--pi-typography-size-caption);
  font-weight: var(--pi-typography-weight-caption);
  color: var(--pi-color-muted);
}

#_pi_surveyWidget ._pi_answers_container {
  display: flex !important;
  flex-direction: column;
  gap: var(--pi-layout-gap-row);
  padding: 0;
  margin: 0;
  list-style: none;
}

#_pi_surveyWidget ._pi_answers_container li {
  list-style: none !important;
  list-style-type: none !important;
  display: flex !important;
  align-items: center !important;
  min-height: var(--pi-answers-tile-min-height) !important;
  border-radius: var(--pi-shape-control-radius) !important;
  border: 1px solid var(--pi-color-answer-border) !important;
  background-color: rgba(255, 255, 255, 0.9) !important;
  transition: background-color 0.18s ease, border-color 0.18s ease, box-shadow 0.18s ease !important;
  overflow: visible !important;
  margin: 0 !important;
  padding: 0 !important;
  position: relative !important;
}

#_pi_surveyWidget ._pi_answers_container li a {
  width: 100%;
  text-decoration: none;
}

#_pi_surveyWidget ._pi_answers_container li label {
  display: flex !important;
  align-items: center !important;
  gap: 12px !important;
  padding: 14px 18px !important;
  border-radius: var(--pi-shape-control-radius) !important;
  font-size: var(--pi-typography-size-answer) !important;
  font-weight: var(--pi-typography-weight-answer) !important;
  line-height: var(--pi-typography-line-height-answer) !important;
  color: var(--pi-color-text) !important;
  cursor: pointer !important;
  transition: color 0.18s ease, background-color 0.18s ease, border-color 0.18s ease, box-shadow 0.18s ease !important;
  margin: 0 !important;
  text-align: left !important;
  text-decoration: none !important;
  text-transform: none !important;
  letter-spacing: normal !important;
}

#_pi_surveyWidget ._pi_answers_container li ._pi_radio_button_outer {
  display: ${radioDisplay};
  width: var(--pi-answers-radio-outer-size);
  height: var(--pi-answers-radio-outer-size);
  min-height: var(--pi-answers-radio-outer-size);
  min-width: var(--pi-answers-radio-outer-size);
  border-radius: 999px;
  border: var(--pi-answers-radio-border-width) solid var(--pi-color-radio-border);
  align-items: center;
  justify-content: center;
  background-color: #ffffff;
}

#_pi_surveyWidget ._pi_answers_container li ._pi_radio_button_inner {
  display: block;
  width: var(--pi-answers-radio-inner-size);
  height: var(--pi-answers-radio-inner-size);
  border-radius: 999px;
  background-color: var(--pi-color-primary);
  opacity: 0;
  transition: opacity 0.18s ease;
}

#_pi_surveyWidget ._pi_answers_container[data-question-type="single_choice_question"] li {
  --pi-answer-fill: var(--pi-button-fill-default);
  --pi-answer-border: var(--pi-button-border-default);
  --pi-answer-shadow: var(--pi-button-shadow-default);
  --pi-answer-color: var(--pi-button-color-default);
  background-color: var(--pi-answer-fill);
  border: var(--pi-answer-border);
  box-shadow: var(--pi-answer-shadow);
}

#_pi_surveyWidget ._pi_answers_container[data-question-type="single_choice_question"] li label {
  color: var(--pi-answer-color);
  text-align: ${radioAlign};
}

#_pi_surveyWidget ._pi_answers_container[data-question-type="single_choice_question"] li:hover {
  --pi-answer-fill: var(--pi-button-fill-hover);
  --pi-answer-border: var(--pi-button-border-hover);
  --pi-answer-shadow: var(--pi-button-shadow-hover);
  --pi-answer-color: var(--pi-button-color-hover);
}

#_pi_surveyWidget ._pi_answers_container[data-question-type="single_choice_question"] li.selected {
  --pi-answer-fill: var(--pi-button-fill-selected);
  --pi-answer-border: var(--pi-button-border-selected);
  --pi-answer-shadow: var(--pi-button-shadow-selected);
  --pi-answer-color: var(--pi-button-color-selected);
}

#_pi_surveyWidget ._pi_answers_container[data-question-type="single_choice_question"] li.selected ._pi_radio_button_inner {
  opacity: 1;
}

#_pi_surveyWidget ._pi_answers_container[data-question-type="multiple_choices_question"] li {
  border: 1px solid var(--pi-color-answer-border);
  background-color: rgba(255, 255, 255, 0.92);
}

#_pi_surveyWidget ._pi_answers_container[data-question-type="multiple_choices_question"] li:hover {
  border-color: var(--pi-color-primary);
}

#_pi_surveyWidget ._pi_answers_container[data-question-type="multiple_choices_question"] li.selected {
  border: var(--pi-button-border-selected);
  background-color: rgba(37, 99, 235, 0.08);
}

#_pi_surveyWidget ._pi_answers_container[data-question-type="free_text_question"] ._pi_free_text_question_field_container {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

#_pi_surveyWidget ._pi_free_text_question_field,
#_pi_surveyWidget textarea._pi_free_text_question_field {
  width: 100%;
  min-height: var(--pi-input-height);
  padding: 12px 16px;
  border-radius: var(--pi-input-radius);
  border: 1px solid var(--pi-color-input-border);
  font-size: var(--pi-typography-size-body);
  font-weight: var(--pi-typography-weight-body);
  transition: border-color 0.18s ease, box-shadow 0.18s ease;
}

#_pi_surveyWidget ._pi_free_text_question_field:focus,
#_pi_surveyWidget textarea._pi_free_text_question_field:focus {
  outline: none;
  border-color: var(--pi-color-input-focus);
  box-shadow: 0 0 0 3px rgba(29, 78, 216, 0.2);
}

#_pi_surveyWidget ._pi_free_text_question_submit_button_container,
#_pi_surveyWidget ._pi_multiple_choices_question_submit_button_container,
#_pi_surveyWidget ._pi_slider_question_submit_button_container,
#_pi_surveyWidget ._pi_all_questions_submit_button_container {
  margin-top: 16px;
  display: flex;
  justify-content: center;
}

#_pi_surveyWidget ._pi_free_text_question_submit_button,
#_pi_surveyWidget ._pi_multiple_choices_question_submit_button,
#_pi_surveyWidget ._pi_slider_question_submit_button,
#_pi_surveyWidget ._pi_all_questions_submit_button,
#_pi_surveyWidget ._pi_invitationTextContainer a._pi_startButton,
#_pi_surveyWidget a._pi_startButton {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: var(--pi-shape-button-radius);
  padding: var(--pi-button-padding-desktop);
  font-size: var(--pi-typography-size-answer);
  font-weight: var(--pi-button-font-weight);
  letter-spacing: 0.01em;
  background-color: var(--pi-button-fill-default);
  border: var(--pi-button-border-default);
  color: var(--pi-button-color-default);
  box-shadow: var(--pi-button-shadow-default);
  cursor: pointer;
  transition: transform 0.12s ease, background-color 0.18s ease, color 0.18s ease, box-shadow 0.18s ease;
  text-decoration: none;
}

#_pi_surveyWidget ._pi_free_text_question_submit_button:hover,
#_pi_surveyWidget ._pi_multiple_choices_question_submit_button:hover,
#_pi_surveyWidget ._pi_slider_question_submit_button:hover,
#_pi_surveyWidget ._pi_all_questions_submit_button:hover,
#_pi_surveyWidget ._pi_invitationTextContainer a._pi_startButton:hover,
#_pi_surveyWidget a._pi_startButton:hover {
  background-color: var(--pi-button-fill-hover);
  border: var(--pi-button-border-hover);
  color: var(--pi-button-color-hover);
  box-shadow: var(--pi-button-shadow-hover);
  transform: translateY(-1px);
}

#_pi_surveyWidget ._pi_free_text_question_submit_button:active,
#_pi_surveyWidget ._pi_multiple_choices_question_submit_button:active,
#_pi_surveyWidget ._pi_slider_question_submit_button:active,
#_pi_surveyWidget ._pi_all_questions_submit_button:active,
#_pi_surveyWidget ._pi_invitationTextContainer a._pi_startButton:active,
#_pi_surveyWidget a._pi_startButton:active {
  background-color: var(--pi-button-fill-active);
  border: var(--pi-button-border-active);
  color: var(--pi-button-color-active);
  box-shadow: var(--pi-button-shadow-active);
  transform: translateY(0);
}

#_pi_surveyWidget ._pi_branding {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  color: var(--pi-color-muted);
  text-decoration: none;
}

#_pi_surveyWidget ._pi_closeButton,
#_pi_surveyWidget ._pi_closeCustomButton {
  font-family: var(--pi-typography-close-family);
  font-size: var(--pi-typography-close-size);
  color: var(--pi-color-muted);
  cursor: pointer;
  border: none;
  background: transparent;
}

@media (max-width: 768px) {
  #_pi_surveyWidget {
    padding: 18px;
  }

  #_pi_surveyWidget ._pi_free_text_question_submit_button,
  #_pi_surveyWidget ._pi_multiple_choices_question_submit_button,
  #_pi_surveyWidget ._pi_slider_question_submit_button,
  #_pi_surveyWidget ._pi_all_questions_submit_button,
  #_pi_surveyWidget ._pi_invitationTextContainer a._pi_startButton,
  #_pi_surveyWidget a._pi_startButton {
    padding: var(--pi-button-padding-mobile);
  }
}
`);

  if (options.includeSliderStyles) {
    parts.push(`
#_pi_surveyWidget ._pi_slider_question_container {
  border: 1px solid var(--pi-color-answer-border);
  border-radius: var(--pi-shape-control-radius);
  padding: 18px;
  background-color: rgba(255, 255, 255, 0.92);
  box-shadow: 0 2px 6px rgba(15, 23, 42, 0.08);
}

#_pi_surveyWidget ._pi_slider_question_container ._pi_slider {
  margin: 24px 0 12px;
  position: relative;
}

#_pi_surveyWidget ._pi_slider .noUi-base,
#_pi_surveyWidget ._pi_slider .noUi-target {
  height: 6px;
  border-radius: 999px;
  background: linear-gradient(90deg, rgba(37, 99, 235, 0.12), rgba(37, 99, 235, 0.32));
}

#_pi_surveyWidget ._pi_slider .noUi-connect {
  background: var(--pi-color-primary);
}

#_pi_surveyWidget ._pi_slider .noUi-handle {
  width: 24px;
  height: 24px;
  border-radius: 12px;
  border: 3px solid #ffffff;
  background: var(--pi-color-primary);
  box-shadow: 0 4px 14px rgba(37, 99, 235, 0.25);
}

#_pi_surveyWidget ._pi_slider_question_container ._pi_slider_labels {
  display: flex;
  justify-content: space-between;
  font-size: var(--pi-typography-size-caption);
  color: var(--pi-color-muted);
}
`);
  }

  if (options.includeAllAtOnceStyles) {
    parts.push(`
div#_pi_surveyWidgetContainer.all-at-once ._pi_answers_container {
  flex-direction: row;
  flex-wrap: wrap;
  gap: var(--pi-layout-gap-col);
}

div#_pi_surveyWidgetContainer.all-at-once ._pi_answers_container li {
  width: calc(50% - var(--pi-layout-gap-col));
}

@media (max-width: 640px) {
  div#_pi_surveyWidgetContainer.all-at-once ._pi_answers_container {
    flex-direction: column;
  }

  div#_pi_surveyWidgetContainer.all-at-once ._pi_answers_container li {
    width: 100%;
  }
}
`);
  }

  return parts.join('\n');
}

function buildFocusStyles() {
  return `
#_pi_surveyWidgetContainer ._pi_answers_container li label,
#_pi_surveyWidgetContainer ._pi_free_text_question_field,
#_pi_surveyWidgetContainer textarea._pi_free_text_question_field,
#_pi_surveyWidgetContainer ._pi_free_text_question_submit_button,
#_pi_surveyWidgetContainer ._pi_multiple_choices_question_submit_button,
#_pi_surveyWidgetContainer ._pi_slider_question_submit_button,
#_pi_surveyWidgetContainer ._pi_all_questions_submit_button,
#_pi_surveyWidgetContainer ._pi_invitationTextContainer a._pi_startButton,
#_pi_surveyWidgetContainer a._pi_startButton {
  outline: none;
}

#_pi_surveyWidgetContainer ._pi_answers_container li label:focus-visible,
#_pi_surveyWidgetContainer ._pi_free_text_question_field:focus-visible,
#_pi_surveyWidgetContainer textarea._pi_free_text_question_field:focus-visible,
#_pi_surveyWidgetContainer ._pi_free_text_question_submit_button:focus-visible,
#_pi_surveyWidgetContainer ._pi_multiple_choices_question_submit_button:focus-visible,
#_pi_surveyWidgetContainer ._pi_slider_question_submit_button:focus-visible,
#_pi_surveyWidgetContainer ._pi_all_questions_submit_button:focus-visible,
#_pi_surveyWidgetContainer ._pi_invitationTextContainer a._pi_startButton:focus-visible,
#_pi_surveyWidgetContainer a._pi_startButton:focus-visible {
  outline: var(--pi-focus-outline-width) var(--pi-focus-outline-style) var(--pi-focus-outline-color);
  outline-offset: var(--pi-focus-outline-offset);
  box-shadow: var(--pi-button-shadow-focus);
  border-radius: var(--pi-focus-outline-radius);
}

#_pi_surveyWidgetContainer ._pi_hidden_slider:focus-visible ~ ._pi_slider .noUi-handle {
  outline: var(--pi-focus-outline-width) var(--pi-focus-outline-style) var(--pi-focus-outline-color);
  outline-offset: var(--pi-focus-outline-offset);
}
`;
}

function generateAnswerLayoutCSS() {
  const parts = [];

  parts.push(`
/* ======================= Answer Layout System ======================= */

/* ------------------------------ Modern System: Variable Width ------------------------------ */
ul[data-answers-layout="variable"],
div[data-answers-layout="variable"]:not([data-survey-display="all-at-once"]) ul._pi_answers_container {
  display: flex !important;
  flex-direction: row !important;
  flex-wrap: wrap !important;
}

ul[data-answers-layout="variable"] li,
div[data-answers-layout="variable"]:not([data-survey-display="all-at-once"]) ul._pi_answers_container li {
  min-width: 80px;
  flex-grow: 0;
  flex-shrink: 0;
  flex-basis: auto;
}

div#_pi_surveyWidgetContainer.mobile-enabled ul[data-answers-layout="variable"] li,
div#_pi_surveyWidgetContainer.mobile-enabled div[data-answers-layout="variable"]:not([data-survey-display="all-at-once"]) ul._pi_answers_container li {
  min-width: 60px;
}

/* ------------------------------ Modern System: Fixed Width - Default (3 per row) ------------------------------ */
ul[data-answers-layout="fixed"],
div[data-answers-layout="fixed"]:not([data-survey-display="all-at-once"]) ul._pi_answers_container {
  display: flex !important;
  flex-direction: row !important;
  flex-wrap: wrap !important;
}

ul[data-answers-layout="fixed"] li,
div[data-answers-layout="fixed"]:not([data-survey-display="all-at-once"]) ul._pi_answers_container li {
  flex: 0 0 calc((100% / 3) - 2%) !important;
  max-width: calc((100% / 3) - 2%) !important;
}
`);

  // Generate per-row configurations (1-14)
  Object.entries(FIXED_WIDTH_PERCENTAGES).forEach(([count, width]) => {
    const margin = count === '1' ? '5px 7%' : '5px 0.9%';
    parts.push(`
ul[data-answers-layout="fixed"][data-answers-per-row="${count}"] li,
div[data-answers-layout="fixed"][data-answers-per-row="${count}"]:not([data-survey-display="all-at-once"]) ul._pi_answers_container li {
  margin: ${margin} !important;
  flex: 0 0 ${width} !important;
  max-width: ${width} !important;
}
`);
  });

  // Modern alignment system
  const alignments = [
    { value: 'left', justify: 'flex-start' },
    { value: 'center', justify: 'center' },
    { value: 'right', justify: 'flex-end' },
    { value: 'space-between', justify: 'space-between' },
    { value: 'space-around', justify: 'space-around' },
    { value: 'space-evenly', justify: 'space-evenly' }
  ];

  parts.push(`
/* ------------------------------ Modern System: Alignment Controls ------------------------------ */
`);
  alignments.forEach(({ value, justify }) => {
    parts.push(`
div[data-answers-alignment="${value}"]:not([data-survey-display="all-at-once"]) ul._pi_answers_container,
ul[data-answers-alignment="${value}"] {
  justify-content: ${justify};
}

div[data-answers-alignment="${value}"]:not([data-survey-display="all-at-once"]) ul._pi_answers_container li,
ul[data-answers-alignment="${value}"] li {
  box-sizing: border-box !important;
  margin: 5px 1% !important;
}
`);
  });

  // Legacy system support
  parts.push(`
/* ------------------------------ Legacy System: data-answer-widths ------------------------------ */

/* Legacy: Fixed width default */
ul[data-answer-widths="fixed"],
div[data-answer-widths="fixed"] ul._pi_answers_container {
  display: flex !important;
  flex-direction: row !important;
  flex-wrap: wrap !important;
  justify-content: flex-start;
}

ul[data-answer-widths="fixed"] li,
div[data-answer-widths="fixed"] ul._pi_answers_container li {
  margin: 5px 0.9% !important;
}

/* Legacy: Fixed width default flex (3 per row) */
ul[data-answer-widths="fixed"] li,
div[data-answer-widths="fixed"] ul._pi_answers_container li {
  flex: 0 0 31%;
  max-width: 31%;
}

/* Legacy: Variable width - left aligned */
ul[data-answer-widths="variable-left"],
div[data-answer-widths="variable-left"] ul._pi_answers_container {
  display: flex !important;
  flex-direction: row !important;
  flex-wrap: wrap !important;
  justify-content: flex-start;
}

ul[data-answer-widths="variable-left"] li,
div[data-answer-widths="variable-left"] ul._pi_answers_container li {
  margin: 5px 1% !important;
  flex-grow: 0;
  flex-shrink: 0;
  flex-basis: auto;
}

/* Legacy: Variable width - center aligned */
ul[data-answer-widths="variable-center"],
div[data-answer-widths="variable-center"] ul._pi_answers_container {
  display: flex !important;
  flex-direction: row !important;
  flex-wrap: wrap !important;
  justify-content: center;
}

ul[data-answer-widths="variable-center"] li,
div[data-answer-widths="variable-center"] ul._pi_answers_container li {
  margin: 5px 1% !important;
  flex-grow: 0;
  flex-shrink: 0;
  flex-basis: auto;
}
`);

  // Legacy per-row configurations
  Object.entries(FIXED_WIDTH_PERCENTAGES).forEach(([count, width]) => {
    const margin = count === '1' ? '5px 7%' : '5px 0.9%';
    parts.push(`
ul[data-answer-widths="fixed"][data-answers-per-row="${count}"] li,
div[data-answer-widths="fixed"][data-answers-per-row="${count}"] ul._pi_answers_container li {
  margin: ${margin} !important;
  flex: 0 0 ${width} !important;
  max-width: ${width} !important;
}
`);
  });

  // Legacy checkbox alignment
  parts.push(`
/* Legacy checkbox text alignment */
ul[data-answer-widths="fixed"] li label._pi-control-checkbox,
div[data-answer-widths="fixed"] ul._pi_answers_container li label._pi-control-checkbox {
  text-align: left !important;
}
`);

  return parts.join('\n');
}

function buildLegacyOverlay() {
  return `
/* Legacy overlay for classic Pulse markup */
div#_pi_surveyWidget[data-question-type="multiple_choices_question"] li label._pi-control._pi-control-checkbox,
div#_pi_surveyWidgetContainer.all-at-once ._pi_answers_container[data-question-type="multiple_choices_question"] li label._pi-control._pi-control-checkbox {
  color: var(--pi-color-text);
}

div#_pi_surveyWidget[data-question-type="multiple_choices_question"] li label._pi-control._pi-control-checkbox:hover,
div#_pi_surveyWidgetContainer.all-at-once ._pi_answers_container[data-question-type="multiple_choices_question"] li label._pi-control._pi-control-checkbox:hover {
  color: var(--pi-color-primary);
}

div#_pi_surveyWidget[data-question-type="free_text_question"] input._pi_free_text_question_field,
div#_pi_surveyWidget[data-question-type="free_text_question"] textarea._pi_free_text_question_field {
  color: var(--pi-color-text);
  padding: 1rem !important;
}

._pi_free_text_question_characters_count.danger {
  color: var(--pi-color-muted);
}

._pi_free_text_question_characters_count.error {
  color: var(--pi-color-primary);
}
`;
}

function validateTheme(tokens) {
  const errors = [];
  const warnings = [];

  CORE_TOKEN_PATHS.forEach((path) => {
    const value = getPath(tokens, path);
    if (value === undefined || value === null || value === '') {
      errors.push(`Missing token: ${path.join('.')}`);
    }
  });

  const primary = parseColor(tokens.colors.primary);
  const onPrimary = parseColor(tokens.colors.onPrimary);
  if (primary && onPrimary && contrastRatio(primary, onPrimary) < 3) {
    warnings.push('Button text contrast may be insufficient for accessibility.');
  }

  return { errors, warnings };
}

function compileTheme(rawTheme = {}, options = {}) {
  const mergedOptions = { ...DEFAULT_OPTIONS, ...(options || {}) };
  const normalized = normalizeTokens(rawTheme);
  const { errors, warnings } = validateTheme(normalized);

  if (errors.length) {
    return { css: null, theme: normalized, warnings, errors };
  }

  const cssSections = [
    buildVariablesBlock(normalized),
    buildBaseCss(normalized, mergedOptions),
    generateAnswerLayoutCSS()
  ];

  if (mergedOptions.includeFocusStyles) {
    cssSections.push(buildFocusStyles());
  }

  if (mergedOptions.includeLegacyLayer) {
    cssSections.push(buildLegacyOverlay());
  }

  const css = cssSections.join('\n\n');
  return { css, theme: normalized, warnings, errors: [] };
}

export {
  compileTheme,
  validateTheme,
  REQUIRED_FIELDS,
  DEFAULTS,
  parseColor,
  contrastRatio,
  relativeLuminance
};
