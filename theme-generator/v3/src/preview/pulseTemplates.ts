/**
 * Phase 5.0: Pulse Markup Templates
 * Renderer functions for real Pulse widget markup
 * Phase 5.0a: Added Standard Buttons and Thank You templates
 */

/**
 * Phase 5.0a: Shared Docked Widget Shell HTML Generator
 * Generates the outer Pulse widget structure
 */
function generateDockedShellHTML(childrenHTML: string, questionType: string): string {
  return `
    <div id="_pi_surveyWidgetContainer" data-layer="widget-container">
      <div
        id="_pi_surveyWidget"
        role="application"
        survey-widget-type="dockedwidgetsurvey"
        data-question-type="${questionType}"
        data-layer="widget-body"
      >
        <span class="_pi_accessibilityHidden" style="display: none;">Survey</span>
        <div class="_pi_closeButton" aria-label="Close Survey" tabindex="0" role="button">×</div>
        <div class="_pi_widgetContentContainer" data-layer="widget-body">
          ${childrenHTML}
        </div>
        <a class="_pi_branding" target="_blank" href="https://www.pulseinsights.com" rel="noopener noreferrer">
          Crafted with Pulse Insights
        </a>
      </div>
    </div>
  `;
}

/**
 * Generate Pulse-based single-choice survey HTML for desktop
 * Uses real Pulse class names and DOM structure
 */
export function renderDockedSingleDesktopPulseV1(compiledCSS: string): string {
  return `
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          ${compiledCSS}
        </style>
      </head>
      <body>
        <div id="_pi_surveyWidgetContainer" data-layer="widget-container">
          <div 
            id="_pi_surveyWidget" 
            role="application" 
            aria-label="Survey"
            survey-widget-type="dockedwidgetsurvey"
            data-layer="widget-body"
          >
            <span class="_pi_accessibilityHidden" style="display: none;">Survey</span>
            <div class="_pi_closeButton" aria-label="Close Survey" tabindex="0" role="button">×</div>
            <div class="_pi_widgetContentContainer">
              <div class="_pi_question _pi_question_single_choice_question" data-layer="widget-header">
                What's your biggest CX Challenge?
              </div>
              <ul class="_pi_answers_container" role="radiogroup">
                <li data-layer="single-choice-default">
                  <a href="javascript:void(0)" role="radio" tabindex="0">
                    <span class="_pi_radio_button_outer">
                      <span class="_pi_radio_button_inner"></span>
                    </span>
                    <label tabindex="0" role="presentation" data-layer="single-choice-default">Customer service quality</label>
                  </a>
                </li>
                <li data-layer="single-choice-default">
                  <a href="javascript:void(0)" role="radio" tabindex="0">
                    <span class="_pi_radio_button_outer">
                      <span class="_pi_radio_button_inner"></span>
                    </span>
                    <label tabindex="0" role="presentation" data-layer="single-choice-default">Response time</label>
                  </a>
                </li>
                <li data-layer="single-choice-default">
                  <a href="javascript:void(0)" role="radio" tabindex="0">
                    <span class="_pi_radio_button_outer">
                      <span class="_pi_radio_button_inner"></span>
                    </span>
                    <label tabindex="0" role="presentation" data-layer="single-choice-default">Product availability</label>
                  </a>
                </li>
              </ul>
              <div class="_pi_free_text_question_field_container">
                <input
                  type="text"
                  class="_pi_free_text_question_field"
                  data-layer="text-input-text"
                  data-layer-border="text-input-border"
                  placeholder="Enter your answer here..."
                />
              </div>
              <div class="_pi_all_questions_submit_button_container">
                <input
                  type="button"
                  class="_pi_all_questions_submit_button"
                  data-layer="cta-button-bg"
                  value="Submit Feedback"
                />
                <span data-layer="cta-button-text" style="display: none;">Submit Feedback</span>
              </div>
            </div>
            <a class="_pi_branding" href="#" target="_blank">Crafted with Pulse Insights</a>
          </div>
        </div>
      </body>
    </html>
  `;
}

/**
 * Generate Pulse-based single-choice survey HTML for iPhone
 * Same structure as desktop, device-specific styling handled via CSS
 */
export function renderDockedSingleIphonePulseV1(compiledCSS: string): string {
  return renderDockedSingleDesktopPulseV1(compiledCSS);
}

/**
 * Generate Pulse-based single-choice survey HTML for Android
 * Same structure as desktop, device-specific styling handled via CSS
 */
export function renderDockedSingleAndroidPulseV1(compiledCSS: string): string {
  return renderDockedSingleDesktopPulseV1(compiledCSS);
}

/**
 * Phase 5.0a: Generate Pulse-based single-choice (standard buttons) survey HTML for desktop
 * Uses button-style options instead of radio buttons
 */
export function renderDockedSingleStandardDesktopPulseV1(compiledCSS: string): string {
  const childrenHTML = `
    <div
      class="_pi_question _pi_question_single_choice_question"
      id="_pi_question_0"
      data-layer="question-text"
    >
      Standard Buttons
    </div>
    <ul class="_pi_answers_container" data-layer="answers-container">
      <li data-layer="single-choice-default">
        <a href="javascript:void(0)" role="button">
          <label>Answer 1</label>
        </a>
      </li>
      <li data-layer="single-choice-active">
        <a href="javascript:void(0)" role="button">
          <label>Answer 2</label>
        </a>
      </li>
    </ul>
  `;

  const shellHTML = generateDockedShellHTML(childrenHTML, 'single_choice_question');

  return `
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          ${compiledCSS}
        </style>
      </head>
      <body>
        ${shellHTML}
      </body>
    </html>
  `;
}

/**
 * Phase 5.0a: Generate Pulse-based thank you screen HTML for desktop
 */
export function renderDockedThankYouDesktopPulseV1(compiledCSS: string): string {
  const childrenHTML = `
    <div class="_pi_thankYouSurvey" data-layer="thank-you-text">
      Thank you!
    </div>
  `;

  const shellHTML = generateDockedShellHTML(childrenHTML, 'thank_you');

  return `
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          ${compiledCSS}
        </style>
      </head>
      <body>
        ${shellHTML}
      </body>
    </html>
  `;
}

