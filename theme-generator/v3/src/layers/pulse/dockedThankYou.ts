/**
 * Phase 5.0a: Layer Definitions for Docked Thank You Pulse Template
 */

import type { LayerDefinition } from '../../types/layers';

export const dockedThankYouPulseLayersDesktopV1: LayerDefinition[] = [
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
    id: 'thank-you-text',
    displayName: 'Thank You Text',
    selector: "[data-layer='thank-you-text']",
    group: 'widget',
    mappings: [
      { tokenPath: 'typography.heading.fontFamily', role: 'text' },
      { tokenPath: 'typography.heading.fontSize', role: 'text' }
    ]
  }
];

