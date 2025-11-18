import { compileString } from 'sass';
import type { ThemeTokensLite } from '../types/theme';

// SCSS template content - in Phase 1, we inline it for simplicity
// Later phases can load from file
const SCSS_TEMPLATE = `
// Theme Template v1 - Preview Only
// Base styles
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: $pi-font-base;
  background: #f5f5f5;
  padding: 20px;
}

// Widget Container
// Phase 5.0: Pulse markup support
#_pi_surveyWidgetContainer {
  max-width: 100%;
  margin: 0 auto;
  font-family: $pi-font-base;
  position: relative;
  z-index: 2147483647;
}

// Phase 5.0: Pulse-specific widget content container
._pi_widgetContentContainer {
  position: relative;
}

// Phase 5.0: Pulse close button
._pi_closeButton {
  position: absolute;
  top: 6px;
  right: 10px;
  color: $pi-widget-header-text;
  cursor: pointer;
  font-size: 20px;
  line-height: 1;
  z-index: 10;
  transition: opacity 0.2s;
  
  &:hover {
    opacity: 0.7;
  }
}

// Widget (Phase 3.95: Use widget component tokens)
// Phase 4.7: Use enhanced layout tokens
#_pi_surveyWidget {
  background-color: $pi-widget-body-bg;
  border-radius: $pi-border-radius;
  color: $pi-widget-body-text;
  padding: $pi-widget-padding;
  max-width: $pi-widget-max-width;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  border: 1px solid $pi-widget-border-color;
}

// Question
// Phase 4.7: Use enhanced typography tokens
._pi_question {
  color: $pi-text-primary;
  font-family: $pi-font-heading;
  font-size: $pi-font-size-heading;
  font-weight: $pi-font-weight-heading;
  line-height: $pi-line-height-heading;
  margin-bottom: $pi-section-spacing;
}

// Answers Container
// Phase 4.7: Use enhanced layout tokens
ul._pi_answers_container {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: $pi-spacing-md;
  margin-bottom: $pi-section-spacing;
}

ul._pi_answers_container li {
  background-color: $pi-single-choice-bg-default;
  border: 2px solid $pi-single-choice-border-default;
  border-radius: $pi-border-radius-option;
  padding: 16px;
  cursor: pointer;
  transition: all 0.2s;
  position: relative;
  
  &:hover,
  &.active,
  &.selected {
    background-color: $pi-single-choice-bg-active;
    border-color: $pi-single-choice-border-active;
    color: $pi-single-choice-text-active;
  }
  
  a {
    color: $pi-single-choice-text-default;
    text-decoration: none;
    display: block;
    font-family: $pi-font-base;
    font-size: $pi-font-size-body;
    font-weight: $pi-font-weight-body;
    line-height: $pi-line-height-body;
    position: relative;
    padding-left: 30px;
    
    &:hover {
      color: $pi-single-choice-text-active;
    }
  }
  
  &:hover a,
  &.active a,
  &.selected a {
    color: $pi-single-choice-text-active;
  }
  
  // Phase 5.0: Pulse radio button styles
  ._pi_radio_button_outer {
    position: absolute;
    top: 10px;
    left: 0;
    display: inline-block;
    border: 2px solid $pi-single-choice-border-default;
    border-radius: 50%;
    width: 18px;
    height: 18px;
    transition: border-color 0.2s;
  }
  
  ._pi_radio_button_inner {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background-color: transparent;
    transition: background-color 0.2s;
  }
  
  &:hover ._pi_radio_button_outer,
  &.active ._pi_radio_button_outer,
  &.selected ._pi_radio_button_outer {
    border-color: $pi-single-choice-border-active;
  }
  
  &:hover ._pi_radio_button_inner,
  &.active ._pi_radio_button_inner,
  &.selected ._pi_radio_button_inner {
    background-color: $pi-single-choice-text-active;
  }
  
  label {
    color: $pi-single-choice-text-default;
    cursor: pointer;
    display: block;
    
    &:hover {
      color: $pi-single-choice-text-active;
    }
  }
  
  &:hover label,
  &.active label,
  &.selected label {
    color: $pi-single-choice-text-active;
  }
}

// Free Text Input
// Phase 4.7: Use enhanced layout and typography tokens
// Phase 5.0: Pulse markup support
._pi_free_text_question_field_container {
  margin: 0 18px 10px 18px;
}

input._pi_free_text_question_field,
textarea._pi_free_text_question_field {
  width: 100%;
  padding: $pi-spacing-md;
  margin-bottom: $pi-section-spacing;
  border: none;
  border-bottom: 2px solid $pi-brand-primary;
  border-radius: $pi-border-radius-input;
  background: transparent;
  color: $pi-text-primary;
  font-family: $pi-font-base;
  font-size: $pi-font-size-body;
  font-weight: $pi-font-weight-body;
  line-height: $pi-line-height-body;
  outline: none;
  box-sizing: border-box;
  
  &:focus {
    border-bottom-color: $pi-brand-secondary;
  }
  
  &::placeholder {
    color: $pi-text-secondary;
  }
  
  &:hover {
    border-bottom-color: $pi-brand-secondary;
  }
}

// Submit Button (Phase 3.95: Use CTA button component tokens)
// Phase 4.7: Use enhanced typography and layout tokens
// Phase 5.0: Pulse markup support
._pi_all_questions_submit_button_container {
  margin-bottom: 25px;
  clear: both;
  text-align: center;
}

input._pi_all_questions_submit_button {
  background-color: $pi-cta-button-bg;
  color: $pi-cta-button-text;
  border-radius: $pi-border-radius-button;
  font-family: $pi-font-base;
  font-size: $pi-font-size-button;
  font-weight: $pi-font-weight-button;
  line-height: $pi-line-height-button;
  letter-spacing: $pi-letter-spacing-button;
  padding: 12px 24px;
  border: none;
  cursor: pointer;
  transition: background-color 0.2s, color 0.2s;
  
  &:hover {
    background-color: $pi-cta-button-bg-hover;
    color: $pi-cta-button-text-hover;
  }
  
  &:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
  
  &:hover:disabled {
    background-color: $pi-cta-button-bg;
  }
}

// Phase 5.0: Pulse branding link
._pi_branding {
  position: absolute;
  bottom: 8px;
  left: 8px;
  font-size: 10px;
  color: $pi-text-secondary;
  text-decoration: none;
  
  &:hover {
    text-decoration: underline;
  }
}

// Phase 5.0: Accessibility hidden text
._pi_accessibilityHidden {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  border: 0;
}

// Phase 5.0a: Standard Buttons (single-choice-standard) styles
._pi_question_single_choice_question[data-layer="question-text"] {
  font-family: $pi-font-base;
  font-size: $pi-font-size-body;
  color: $pi-text-primary;
  margin-bottom: $pi-section-spacing;
}

._pi_answers_container[data-layer="answers-container"] li[data-layer="single-choice-default"] a {
  background: $pi-single-choice-bg-default;
  color: $pi-single-choice-text-default;
  border: 2px solid $pi-single-choice-border-default;
  border-radius: $pi-border-radius-option;
  padding: 12px 24px;
  display: block;
  text-decoration: none;
  transition: all 0.2s;
  
  &:hover {
    background: $pi-single-choice-bg-active;
    color: $pi-single-choice-text-active;
    border-color: $pi-single-choice-border-active;
  }
  
  label {
    cursor: pointer;
    display: block;
    font-family: $pi-font-base;
    font-size: $pi-font-size-body;
    font-weight: $pi-font-weight-body;
  }
}

._pi_answers_container[data-layer="answers-container"] li[data-layer="single-choice-active"] a {
  background: $pi-single-choice-bg-active;
  color: $pi-single-choice-text-active;
  border: 2px solid $pi-single-choice-border-active;
  border-radius: $pi-border-radius-option;
  padding: 12px 24px;
  display: block;
  text-decoration: none;
  
  label {
    cursor: pointer;
    display: block;
    font-family: $pi-font-base;
    font-size: $pi-font-size-body;
    font-weight: $pi-font-weight-body;
  }
}

// Phase 5.0a: Thank You screen styles
._pi_thankYouSurvey[data-layer="thank-you-text"] {
  font-family: $pi-font-heading;
  font-size: $pi-font-size-heading;
  font-weight: $pi-font-weight-heading;
  line-height: $pi-line-height-heading;
  color: $pi-text-primary;
  text-align: center;
  padding: 40px 20px;
}
`;

/**
 * Compiles ThemeTokensLite to CSS using SCSS template
 * @param theme - ThemeTokensLite instance
 * @returns Compiled CSS string
 */
export function compileTheme(theme: ThemeTokensLite): string {
  // Generate SCSS variables from theme tokens
  const scssVariables = generateSCSSVariables(theme);
  
  // Combine variables + template
  const scssContent = `${scssVariables}\n\n${SCSS_TEMPLATE}`;

  try {
    // Compile SCSS to CSS
    const result = compileString(scssContent, {
      style: 'expanded',
      sourceMap: false
    });
    
    return result.css;
  } catch (error) {
    console.error('SCSS compilation error:', error);
    // Fallback to inline CSS if compilation fails
    return generateFallbackCSS(theme);
  }
}

/**
 * Generates SCSS variable declarations from ThemeTokensLite
 * Phase 3.95: Added widget component tokens
 */
function generateSCSSVariables(theme: ThemeTokensLite): string {
  const { palette, typography, layout, components } = theme;
  
  return `
// Theme: ${theme.name}
// Generated from ThemeTokensLite

// Palette
$pi-bg: ${palette.background};
$pi-surface: ${palette.surface};
$pi-surface-alt: ${palette.surfaceAlt};
$pi-text-primary: ${palette.textPrimary};
$pi-text-secondary: ${palette.textSecondary};
$pi-brand-primary: ${palette.brandPrimary};
$pi-brand-secondary: ${palette.brandSecondary};
$pi-accent: ${palette.accent};
$pi-danger: ${palette.danger};
$pi-success: ${palette.success};

// Typography
// Phase 4.7: Use enhanced typography roles with fallbacks
$pi-font-base: ${typography.heading?.fontFamily || typography.fontFamilyHeading || typography.fontFamilyBase};
$pi-font-heading: ${typography.heading?.fontFamily || typography.fontFamilyHeading || typography.fontFamilyBase};
$pi-font-size-base: ${typography.body?.fontSize || typography.baseFontSize}px;
$pi-font-size-heading: ${typography.heading?.fontSize || typography.headingSize}px;
$pi-font-size-body: ${typography.body?.fontSize || typography.bodySize}px;
$pi-font-size-button: ${typography.button?.fontSize || typography.buttonSize}px;
$pi-font-weight-heading: ${typography.heading?.fontWeight || 600};
$pi-font-weight-body: ${typography.body?.fontWeight || 400};
$pi-font-weight-button: ${typography.button?.fontWeight || 600};
$pi-line-height-heading: ${typography.heading?.lineHeight || 1.3};
$pi-line-height-body: ${typography.body?.lineHeight || 1.5};
$pi-line-height-button: ${typography.button?.lineHeight || 1.4};
$pi-letter-spacing-button: ${typography.button?.letterSpacing || 0.5}px;

// Layout
// Phase 4.7: Use enhanced layout tokens with fallbacks
$pi-border-radius: ${layout.borderRadiusTokens?.widget || layout.borderRadius}px;
$pi-border-radius-button: ${layout.borderRadiusTokens?.button || layout.borderRadius}px;
$pi-border-radius-option: ${layout.borderRadiusTokens?.option || layout.borderRadius}px;
$pi-border-radius-input: ${layout.borderRadiusTokens?.input || 4}px;
$pi-spacing-md: ${layout.spacing?.optionGap || layout.spacingMd}px;
$pi-widget-padding: ${layout.spacing?.widgetPadding || 24}px;
$pi-section-spacing: ${layout.spacing?.sectionSpacing || 20}px;
$pi-widget-max-width: ${layout.maxWidth?.widget || 420}px;

// Widget Components (Phase 3.95)
$pi-widget-header-bg: ${components.widget.headerBg};
$pi-widget-header-text: ${components.widget.headerText};
$pi-widget-body-bg: ${components.widget.bodyBg};
$pi-widget-body-text: ${components.widget.bodyText};
$pi-widget-border-color: ${components.widget.borderColor};

// Single Choice Components (Phase 3.95)
$pi-single-choice-bg-default: ${components.singleChoice.bgDefault};
$pi-single-choice-bg-active: ${components.singleChoice.bgActive};
$pi-single-choice-text-default: ${components.singleChoice.textDefault};
$pi-single-choice-text-active: ${components.singleChoice.textActive};
$pi-single-choice-border-default: ${components.singleChoice.borderDefault};
$pi-single-choice-border-active: ${components.singleChoice.borderActive};

// CTA Button Components (Phase 3.95)
$pi-cta-button-bg: ${components.ctaButton.bg};
$pi-cta-button-text: ${components.ctaButton.text};
$pi-cta-button-bg-hover: ${components.ctaButton.bgHover};
$pi-cta-button-text-hover: ${components.ctaButton.textHover};
`;
}

/**
 * Fallback CSS generation if SCSS compilation fails
 * Phase 3.95: Updated to use widget component tokens
 */
function generateFallbackCSS(theme: ThemeTokensLite): string {
  const { palette, typography, layout, components } = theme;
  const { singleChoice, ctaButton, widget } = components;
  
  return `
#_pi_surveyWidgetContainer {
  font-family: ${typography.fontFamilyBase};
}

#_pi_surveyWidget {
  background-color: ${widget.bodyBg};
  border-radius: ${layout.borderRadius}px;
  color: ${widget.bodyText};
  padding: 30px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  border: 1px solid ${widget.borderColor};
}

._pi_question {
  color: ${palette.textPrimary};
  font-family: ${typography.fontFamilyHeading || typography.fontFamilyBase};
  font-size: ${typography.headingSize}px;
  font-weight: 600;
  margin-bottom: 20px;
}

ul._pi_answers_container {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: ${layout.spacingMd}px;
  margin-bottom: 20px;
}

ul._pi_answers_container li {
  background-color: ${singleChoice.bgDefault};
  border: 2px solid ${singleChoice.borderDefault};
  border-radius: ${layout.borderRadius}px;
  padding: 16px;
  cursor: pointer;
  transition: all 0.2s;
}

ul._pi_answers_container li:hover,
ul._pi_answers_container li.active {
  background-color: ${singleChoice.bgActive};
  border-color: ${singleChoice.borderActive};
  color: ${singleChoice.textActive};
}

ul._pi_answers_container li a {
  color: ${singleChoice.textDefault};
  text-decoration: none;
  display: block;
  font-size: ${typography.bodySize}px;
}

ul._pi_answers_container li:hover a,
ul._pi_answers_container li.active a {
  color: ${singleChoice.textActive};
}

input._pi_free_text_question_field {
  width: 100%;
  padding: ${layout.spacingMd}px;
  margin-bottom: 20px;
  border: none;
  border-bottom: 2px solid ${palette.brandPrimary};
  background: transparent;
  color: ${palette.textPrimary};
  font-family: ${typography.fontFamilyBase};
  font-size: ${typography.bodySize}px;
  outline: none;
}

input._pi_free_text_question_field:focus {
  border-bottom-color: ${palette.brandSecondary};
}

input._pi_all_questions_submit_button {
  background-color: ${ctaButton.bg};
  color: ${ctaButton.text};
  border-radius: ${layout.borderRadius}px;
  font-family: ${typography.fontFamilyBase};
  font-size: ${typography.buttonSize}px;
  font-weight: 600;
  padding: 12px 24px;
  border: none;
  cursor: pointer;
  transition: background-color 0.2s, color 0.2s;
}

input._pi_all_questions_submit_button:hover {
  background-color: ${ctaButton.bgHover};
  color: ${ctaButton.textHover};
}
`;
}
