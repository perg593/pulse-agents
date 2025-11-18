/**
 * Phase 4.1: Layer Definitions
 * Centralized layer definitions for the current widget/question/device combination
 */

import type { LayerDefinition } from '../types/layers';

/**
 * Initial layer set for single-choice, docked widget
 * These layers map to ThemeTokensLite paths
 */
export const LAYER_DEFINITIONS: LayerDefinition[] = [
  // Widget group
  {
    id: 'widget-container',
    displayName: 'Container',
    selector: '[data-layer="widget-container"]',
    group: 'widget',
    mappings: [
      { tokenPath: 'components.widget.bodyBg', role: 'background' },
      { tokenPath: 'components.widget.bodyText', role: 'text' }
    ]
  },
  {
    id: 'widget-header',
    displayName: 'Header',
    selector: '[data-layer="widget-header"]',
    group: 'widget',
    mappings: [
      { tokenPath: 'components.widget.headerBg', role: 'background' },
      { tokenPath: 'components.widget.headerText', role: 'text' }
    ]
  },
  {
    id: 'widget-body',
    displayName: 'Body',
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
    selector: '[data-layer="single-choice-default"].active',
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
 * Get layers by group
 */
export function getLayersByGroup(group: 'widget' | 'question' | 'controls'): LayerDefinition[] {
  return LAYER_DEFINITIONS.filter(layer => layer.group === group);
}

/**
 * Get layer by ID
 */
export function getLayerById(id: string): LayerDefinition | undefined {
  return LAYER_DEFINITIONS.find(layer => layer.id === id);
}

