/**
 * @fileoverview DOM Selector Constants
 * 
 * Centralized DOM selector constants to eliminate magic strings throughout the codebase.
 */

/**
 * Widget element IDs
 */
const WIDGET_IDS = {
  /** Survey widget container ID */
  SURVEY_WIDGET_CONTAINER: '_pi_surveyWidgetContainer',
  
  /** Survey widget ID */
  SURVEY_WIDGET: '_pi_surveyWidget',
  
  /** Survey widget custom ID */
  SURVEY_WIDGET_CUSTOM: '_pi_surveyWidgetCustom',
  
  /** Modal widget container ID */
  MODAL_WIDGET_CONTAINER: '_pi_modalWidgetContainer',
  
  /** Inline widget ID */
  INLINE_WIDGET: '_pi_inlineWidget',
  
  /** Survey invite ID */
  SURVEY_INVITE: '_pi_surveyInvite',
  
  /** ID not found overlay ID */
  ID_NOT_FOUND_OVERLAY: 'pi-present-id-not-found'
};

/**
 * CSS classes
 */
const CSS_CLASSES = {
  /** Survey overlay container class */
  SURVEY_OVERLAY_CONTAINER: 'survey-overlay-container',
  
  /** ID not found overlay class */
  ID_NOT_FOUND_OVERLAY: 'pi-present-id-not-found',
  
  /** Widget position classes */
  WIDGET_POSITION_BR: 'pi-widget--position-br',
  WIDGET_POSITION_BL: 'pi-widget--position-bl',
  WIDGET_POSITION_TR: 'pi-widget--position-tr',
  WIDGET_POSITION_TL: 'pi-widget--position-tl',
  
  /** Widget type classes */
  WIDGET_INLINE: 'pi-widget-inline',
  WIDGET_MODAL: 'pi-widget-modal',
  WIDGET_DOCKED: 'pi-widget-docked'
};

/**
 * Data attributes
 */
const DATA_ATTRIBUTES = {
  /** Widget root data attribute */
  WIDGET_ROOT: 'data-pi-widget-root',
  
  /** Widget data attribute */
  WIDGET: 'data-pi-widget',
  
  /** Placement data attribute */
  PLACEMENT: 'data-pi-placement',
  
  /** Position data attribute (legacy) */
  POSITION: 'data-pi-position'
};

/**
 * CSS selectors for widget detection
 */
const SELECTORS = {
  /** Widget root selector */
  WIDGET_ROOT: '[data-pi-widget-root], [data-pi-widget]',
  
  /** Widget type selectors */
  WIDGET_INLINE: '.pi-widget-inline',
  WIDGET_MODAL: '.pi-widget-modal',
  WIDGET_DOCKED: '.pi-widget-docked',
  
  /** Widget container selector */
  WIDGET_CONTAINER: '#_pi_surveyWidgetContainer'
};

module.exports = {
  WIDGET_IDS,
  CSS_CLASSES,
  DATA_ATTRIBUTES,
  SELECTORS
};

