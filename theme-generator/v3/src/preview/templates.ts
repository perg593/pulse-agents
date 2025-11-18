/**
 * Phase 4.0: Preview Template Config
 * Central registry of preview templates with versioning
 */

import type {
  PreviewTemplateConfig,
  LayerDefinition,
  WidgetType,
  QuestionType,
  DeviceType
} from '../types/layers';
import { LAYER_DEFINITIONS } from '../layers/definitions';
import {
  renderDockedSingleDesktopPulseV1,
  renderDockedSingleIphonePulseV1,
  renderDockedSingleAndroidPulseV1,
  renderDockedSingleStandardDesktopPulseV1,
  renderDockedThankYouDesktopPulseV1
} from './pulseTemplates';
import {
  dockedSinglePulseLayersDesktopV1,
  dockedSinglePulseLayersMobileV1
} from '../layers/pulseDefinitions';
import { dockedSingleStandardPulseLayersDesktopV1 } from '../layers/pulse/dockedSingleStandard';
import { dockedThankYouPulseLayersDesktopV1 } from '../layers/pulse/dockedThankYou';

/**
 * Generate the default single-choice survey HTML
 * Phase 4.1: Updated with proper data-layer attributes matching layer definitions
 */
function generateSingleChoiceHTML(compiledCSS: string): string {
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
          <div id="_pi_surveyWidget" data-layer="widget-body">
            <div class="_pi_question" data-layer="widget-header">
              What's your biggest CX Challenge?
            </div>
            
            <ul class="_pi_answers_container">
              <li data-layer="single-choice-default">
                <a href="#">Customer service quality</a>
              </li>
              <li data-layer="single-choice-default">
                <a href="#">Response time</a>
              </li>
              <li data-layer="single-choice-default">
                <a href="#">Product availability</a>
              </li>
            </ul>
            
            <input
              type="text"
              class="_pi_free_text_question_field"
              data-layer="text-input-text"
              data-layer-border="text-input-border"
              placeholder="Enter your answer here..."
            />
            
            <input
              type="button"
              class="_pi_all_questions_submit_button"
              data-layer="cta-button-bg"
              value="Submit"
            />
          </div>
        </div>
      </body>
    </html>
  `;
}

/**
 * Layer definitions for single-choice question type
 * Phase 4.1: Use centralized layer definitions
 */
const singleChoiceLayers: LayerDefinition[] = LAYER_DEFINITIONS;

/**
 * Phase 4.2: Template: Docked widget, single-choice question, desktop, v1
 */
export const templateDockedSingleDesktopV1: PreviewTemplateConfig = {
  id: 'docked-single-desktop-v1',
  label: 'Docked / Single Choice / Desktop / v1',
  version: 'v1',
  widgetType: 'docked',
  questionType: 'single-choice',
  deviceType: 'desktop',
  generateHTML: generateSingleChoiceHTML,
  layers: singleChoiceLayers
};

/**
 * Phase 4.2: Template: Docked widget, single-choice question, iPhone, v1
 */
export const templateDockedSingleIphoneV1: PreviewTemplateConfig = {
  id: 'docked-single-iphone-v1',
  label: 'Docked / Single Choice / iPhone / v1',
  version: 'v1',
  widgetType: 'docked',
  questionType: 'single-choice',
  deviceType: 'mobile',
  generateHTML: generateSingleChoiceHTML,
  layers: singleChoiceLayers
};

/**
 * Phase 4.2: Template: Docked widget, single-choice question, Android, v1
 */
export const templateDockedSingleAndroidV1: PreviewTemplateConfig = {
  id: 'docked-single-android-v1',
  label: 'Docked / Single Choice / Android / v1',
  version: 'v1',
  widgetType: 'docked',
  questionType: 'single-choice',
  deviceType: 'mobile',
  generateHTML: generateSingleChoiceHTML,
  layers: singleChoiceLayers
};

/**
 * Phase 5.0: Template: Docked widget, single-choice question, desktop, Pulse v1
 */
export const templateDockedSingleDesktopPulseV1: PreviewTemplateConfig = {
  id: 'docked-single-desktop-pulse-v1',
  label: 'Docked / Single Choice / Desktop / Pulse v1',
  version: 'pulse-v1',
  widgetType: 'docked',
  questionType: 'single-choice',
  deviceType: 'desktop',
  generateHTML: renderDockedSingleDesktopPulseV1,
  layers: dockedSinglePulseLayersDesktopV1
};

/**
 * Phase 5.0: Template: Docked widget, single-choice question, iPhone, Pulse v1
 */
export const templateDockedSingleIphonePulseV1: PreviewTemplateConfig = {
  id: 'docked-single-iphone-pulse-v1',
  label: 'Docked / Single Choice / iPhone / Pulse v1',
  version: 'pulse-v1',
  widgetType: 'docked',
  questionType: 'single-choice',
  deviceType: 'mobile',
  generateHTML: renderDockedSingleIphonePulseV1,
  layers: dockedSinglePulseLayersMobileV1
};

/**
 * Phase 5.0: Template: Docked widget, single-choice question, Android, Pulse v1
 */
export const templateDockedSingleAndroidPulseV1: PreviewTemplateConfig = {
  id: 'docked-single-android-pulse-v1',
  label: 'Docked / Single Choice / Android / Pulse v1',
  version: 'pulse-v1',
  widgetType: 'docked',
  questionType: 'single-choice',
  deviceType: 'mobile',
  generateHTML: renderDockedSingleAndroidPulseV1,
  layers: dockedSinglePulseLayersMobileV1
};

/**
 * Phase 5.0a: Template: Docked widget, single-choice-standard (buttons), desktop, Pulse v1
 */
export const templateDockedSingleStandardDesktopPulseV1: PreviewTemplateConfig = {
  id: 'docked-single-standard-desktop-pulse-v1',
  label: 'Docked / Single Choice (Buttons) / Desktop — Pulse v1',
  version: 'pulse-v1',
  widgetType: 'docked',
  questionType: 'single-choice-standard',
  deviceType: 'desktop',
  generateHTML: renderDockedSingleStandardDesktopPulseV1,
  layers: dockedSingleStandardPulseLayersDesktopV1
};

/**
 * Phase 5.0a: Template: Docked widget, thank-you, desktop, Pulse v1
 */
export const templateDockedThankYouDesktopPulseV1: PreviewTemplateConfig = {
  id: 'docked-thank-you-desktop-pulse-v1',
  label: 'Docked / Thank You / Desktop — Pulse v1',
  version: 'pulse-v1',
  widgetType: 'docked',
  questionType: 'thank-you',
  deviceType: 'desktop',
  generateHTML: renderDockedThankYouDesktopPulseV1,
  layers: dockedThankYouPulseLayersDesktopV1
};

/**
 * Phase 4.2: Registry of all available templates
 * Phase 5.0: Added Pulse-based templates
 * Phase 5.0a: Added Standard Buttons and Thank You templates
 */
export const TEMPLATE_REGISTRY: PreviewTemplateConfig[] = [
  // Lab templates (v1)
  templateDockedSingleDesktopV1,
  templateDockedSingleIphoneV1,
  templateDockedSingleAndroidV1,
  // Pulse templates (pulse-v1)
  templateDockedSingleDesktopPulseV1,
  templateDockedSingleIphonePulseV1,
  templateDockedSingleAndroidPulseV1,
  // Phase 5.0a: Pulse Standard Buttons and Thank You
  templateDockedSingleStandardDesktopPulseV1,
  templateDockedThankYouDesktopPulseV1
];

/**
 * Get template by ID
 */
export function getTemplateById(id: string): PreviewTemplateConfig | undefined {
  return TEMPLATE_REGISTRY.find(t => t.id === id);
}

/**
 * Phase 4.2: Get templates by widget/question/device combination
 */
export function getTemplatesByCombination(
  widgetType: WidgetType,
  questionType: QuestionType,
  deviceType: DeviceType
): PreviewTemplateConfig[] {
  return TEMPLATE_REGISTRY.filter(
    t =>
      t.widgetType === widgetType &&
      t.questionType === questionType &&
      t.deviceType === deviceType
  );
}

/**
 * Phase 4.2: Get templates compatible with CanvasDeviceType
 * Maps iphone/android to mobile deviceType for template lookup
 */
export function getTemplatesForCanvasDevice(
  widgetType: WidgetType,
  questionType: QuestionType,
  canvasDeviceType: import('../types/layers').CanvasDeviceType
): PreviewTemplateConfig[] {
  const deviceType: DeviceType = canvasDeviceType === 'desktop' ? 'desktop' : 'mobile';
  return getTemplatesByCombination(widgetType, questionType, deviceType);
}

/**
 * Phase 4.2: Get all available template IDs for a combination
 */
export function getAvailableTemplateIds(
  widgetType: WidgetType,
  questionType: QuestionType,
  deviceType: DeviceType
): string[] {
  return getTemplatesByCombination(widgetType, questionType, deviceType).map(t => t.id);
}

