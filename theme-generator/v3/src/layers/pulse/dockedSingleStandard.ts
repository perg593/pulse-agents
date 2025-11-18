/**
 * Phase 5.0a: Layer Definitions for Docked Single Choice (Standard Buttons) Pulse Template
 */

import type { LayerDefinition } from '../../types/layers';

export const dockedSingleStandardPulseLayersDesktopV1: LayerDefinition[] = [
  {
    id: 'widget-container',
    displayName: 'Widget Container',
    selector: "[data-layer='widget-container']",
    group: 'widget',
    mappings: [
      { tokenPath: 'components.widget.bodyBg', role: 'background' }
    ]
  },
  {
    id: 'widget-body',
    displayName: 'Widget Body',
    selector: "[data-layer='widget-body']",
    group: 'widget',
    mappings: [
      { tokenPath: 'components.widget.bodyText', role: 'text' }
    ]
  },
  {
    id: 'question-text',
    displayName: 'Question Text',
    selector: "[data-layer='question-text']",
    group: 'question',
    mappings: [
      { tokenPath: 'typography.body.fontFamily', role: 'text' },
      { tokenPath: 'typography.body.fontSize', role: 'text' }
    ]
  },
  {
    id: 'single-choice-default',
    displayName: 'Single Choice (Default)',
    selector: "[data-layer='single-choice-default']",
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
    selector: "[data-layer='single-choice-active']",
    group: 'question',
    mappings: [
      { tokenPath: 'components.singleChoice.bgActive', role: 'background' },
      { tokenPath: 'components.singleChoice.textActive', role: 'text' },
      { tokenPath: 'components.singleChoice.borderActive', role: 'border' }
    ]
  }
];

