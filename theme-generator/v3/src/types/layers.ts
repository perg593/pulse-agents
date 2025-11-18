/**
 * Phase 4.0: Layer Model & Token Mapping
 * Defines the layer system for Inspect & Edit mode
 */

// Phase 4.2: DeviceType for templates (desktop vs mobile for template matching)
export type DeviceType = 'desktop' | 'mobile';

// Phase 4.2: CanvasDeviceType for UI (desktop/iphone/android)
export type CanvasDeviceType = 'desktop' | 'iphone' | 'android';

export type WidgetType = 'docked' | 'inline' | 'top-bar' | 'bottom-bar' | 'fullscreen' | 'modal';

export type QuestionType = 'single-choice' | 'single-choice-standard' | 'multi-choice' | 'slider' | 'nps' | 'free-text' | 'thank-you';

export type TokenRole = 'background' | 'text' | 'border' | 'icon';

/**
 * Maps a layer to one or more theme tokens
 */
export interface LayerTokenMapping {
  /**
   * Path to the token in ThemeTokensLite, e.g.:
   * - "palette.brandPrimary"
   * - "components.ctaButton.bg"
   * - "components.widget.bodyBg"
   */
  tokenPath: string;
  
  /**
   * Role of this token for the layer
   */
  role: TokenRole;
}

/**
 * Defines a semantic design layer that can be inspected and edited
 */
export interface LayerDefinition {
  /**
   * Unique identifier, e.g. "cta-button-bg"
   */
  id: string;
  
  /**
   * Human-readable display name, e.g. "CTA Button – Background"
   */
  displayName: string;
  
  /**
   * CSS selector or data-layer attribute, e.g.:
   * - "[data-layer='cta-button']"
   * - "#_pi_surveyWidget"
   * - "input._pi_all_questions_submit_button"
   */
  selector: string;
  
  /**
   * Theme tokens that control this layer
   */
  mappings: LayerTokenMapping[];
  
  /**
   * Optional: Group/category for organization (e.g. "Widget", "Question", "Controls")
   */
  group?: string;
}

/**
 * Phase 4.2: Preview template configuration with versioning
 */
export interface PreviewTemplateConfig {
  /**
   * Unique template ID, e.g. "docked-single-desktop-v1"
   */
  id: string;
  
  /**
   * Phase 4.2: Human-readable label, e.g. "Docked / Single Choice / Desktop / v1"
   */
  label: string;
  
  /**
   * Version string, e.g. "v1"
   */
  version: string;
  
  /**
   * Widget type this template is for
   */
  widgetType: WidgetType;
  
  /**
   * Question type this template is for
   */
  questionType: QuestionType;
  
  /**
   * Device type this template is for (desktop vs mobile)
   */
  deviceType: DeviceType;
  
  /**
   * Function that generates the preview HTML
   * Takes compiled CSS and returns HTML string
   */
  generateHTML: (compiledCSS: string) => string;
  
  /**
   * Layer definitions for this template
   */
  layers: LayerDefinition[];
}

/**
 * Phase 4.2: Template selection key
 */
export interface TemplateSelectionKey {
  widgetType: WidgetType;
  questionType: QuestionType;
  deviceType: CanvasDeviceType; // desktop | iphone | android
}

/**
 * Phase 4.2: Active template selection per widget/question/device combination
 */
export interface TemplateSelection {
  /**
   * Selection key identifying widget/question/device combination
   */
  key: TemplateSelectionKey;
  
  /**
   * Active template ID for this combination
   */
  templateId: string;
}

/**
 * Phase 4.2: Advanced configuration options
 */
export interface AdvancedConfigOptions {
  /**
   * Rendering options
   */
  rendering: {
    enableAnimations: boolean;
    cacheTemplates: boolean;
    maxCacheSizeMB: number;
  };
  
  /**
   * Editor options
   */
  editor: {
    autoSaveChanges: boolean;
    debugMode: boolean;
  };
}

