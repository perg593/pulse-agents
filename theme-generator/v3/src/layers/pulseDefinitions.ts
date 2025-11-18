/**
 * Phase 5.0: Pulse-Specific Layer Definitions
 * Layer definitions for Pulse-based templates using real Pulse markup
 */

import type { LayerDefinition } from '../types/layers';

/**
 * Layer definitions for docked single-choice Pulse templates (desktop)
 */
export const dockedSinglePulseLayersDesktopV1: LayerDefinition[] = [
  // Widget group
  {
    id: 'widget-container',
    displayName: 'Widget Container',
    selector: '[data-layer="widget-container"]',
    group: 'widget',
    mappings: [
      { tokenPath: 'components.widget.bodyBg', role: 'background' },
      { tokenPath: 'components.widget.bodyText', role: 'text' }
    ]
  },
  {
    id: 'widget-header',
    displayName: 'Widget Header',
    selector: '[data-layer="widget-header"]',
    group: 'widget',
    mappings: [
      { tokenPath: 'components.widget.headerBg', role: 'background' },
      { tokenPath: 'components.widget.headerText', role: 'text' }
    ]
  },
  {
    id: 'widget-body',
    displayName: 'Widget Body',
    selector: '[data-layer="widget-body"]',
    group: 'widget',
    mappings: [
      { tokenPath: 'components.widget.bodyBg', role: 'background' },
      { tokenPath: 'components.widget.bodyText', role: 'text' },
      { tokenPath: 'components.widget.borderColor', role: 'border' }
    ]
  },
  
  // Question group
  {
    id: 'single-choice-default',
    displayName: 'Single Choice (Default)',
    selector: '[data-layer="single-choice-default"]',
    group: 'question',
    mappings: [
      { tokenPath: 'components.singleChoice.bgDefault', role: 'background' },
      { tokenPath: 'components.singleChoice.textDefault', role: 'text' },
      { tokenPath: 'components.singleChoice.borderDefault', role: 'border' }
    ]
  },
  {
    id: 'single-choice-active',
    displayName: 'Single Choice (Active)',
    selector: '[data-layer="single-choice-default"].selected, [data-layer="single-choice-default"]:hover',
    group: 'question',
    mappings: [
      { tokenPath: 'components.singleChoice.bgActive', role: 'background' },
      { tokenPath: 'components.singleChoice.textActive', role: 'text' },
      { tokenPath: 'components.singleChoice.borderActive', role: 'border' }
    ]
  },
  
  // Controls group
  {
    id: 'cta-button-bg',
    displayName: 'CTA Button',
    selector: '[data-layer="cta-button-bg"]',
    group: 'controls',
    mappings: [
      { tokenPath: 'components.ctaButton.bg', role: 'background' },
      { tokenPath: 'components.ctaButton.text', role: 'text' }
    ]
  },
  {
    id: 'cta-button-text',
    displayName: 'CTA Button Text',
    selector: '[data-layer="cta-button-text"]',
    group: 'controls',
    mappings: [
      { tokenPath: 'components.ctaButton.text', role: 'text' }
    ]
  },
  {
    id: 'text-input-border',
    displayName: 'Text Input Border',
    selector: '[data-layer-border="text-input-border"]',
    group: 'controls',
    mappings: [
      { tokenPath: 'palette.brandPrimary', role: 'border' }
    ]
  },
  {
    id: 'text-input-text',
    displayName: 'Text Input',
    selector: '[data-layer="text-input-text"]',
    group: 'controls',
    mappings: [
      { tokenPath: 'palette.textPrimary', role: 'text' }
    ]
  }
];

/**
 * Layer definitions for docked single-choice Pulse templates (mobile)
 * Reuse desktop definitions as DOM structure is similar
 */
export const dockedSinglePulseLayersMobileV1: LayerDefinition[] = dockedSinglePulseLayersDesktopV1;

