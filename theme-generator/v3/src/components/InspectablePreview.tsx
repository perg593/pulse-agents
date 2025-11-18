/**
 * Phase 4.0: Inspectable Preview Component
 * Handles inspect mode hover/click interactions with iframe content
 */

import { useEffect, useRef, useState } from 'react';
import type { LayerDefinition } from '../types/layers';

interface InspectablePreviewProps {
  html: string;
  layers: LayerDefinition[];
  inspectMode: boolean;
  selectedLayerId: string | null;
  onLayerHover?: (layer: LayerDefinition | null) => void;
  onLayerSelect?: (layer: LayerDefinition | null) => void;
  width: number;
  title: string;
}

export function InspectablePreview({
  html,
  layers,
  inspectMode,
  selectedLayerId,
  onLayerHover,
  onLayerSelect,
  width,
  title
}: InspectablePreviewProps) {
  const iframeRef = useRef<HTMLIFrameElement>(null);
  const [hoveredLayer, setHoveredLayer] = useState<LayerDefinition | null>(null);

  useEffect(() => {
    const iframe = iframeRef.current;
    if (!iframe || !inspectMode) return;

    function setupInspectMode(iframeDoc: Document) {
      // Inject inspect mode CSS
      const styleId = 'inspect-mode-styles';
      let styleEl = iframeDoc.getElementById(styleId);
      if (!styleEl) {
        styleEl = iframeDoc.createElement('style');
        styleEl.id = styleId;
        iframeDoc.head.appendChild(styleEl);
      }
      // Phase 4.0: Only inject inspect styles in Edit mode
      styleEl.textContent = `
        [data-layer] {
          position: relative;
          cursor: ${inspectMode ? 'pointer' : 'default'};
        }
        ${inspectMode ? `
        [data-layer].inspect-hover {
          outline: 2px solid #2563eb;
          outline-offset: 2px;
          background-color: rgba(37, 99, 235, 0.1) !important;
        }
        [data-layer].inspect-selected {
          outline: 3px solid #9333ea;
          outline-offset: 2px;
          background-color: rgba(147, 51, 234, 0.15) !important;
        }
        ` : ''}
      `;

      // Find layer at point
      const findLayersAtPoint = (x: number, y: number): LayerDefinition[] => {
        const elements = iframeDoc.elementsFromPoint(x, y);
        const foundLayers: LayerDefinition[] = [];

        for (const element of elements) {
          const layerId = element.getAttribute('data-layer');
          if (layerId) {
            const layer = layers.find(l => l.id === layerId);
            if (layer && !foundLayers.find(l => l.id === layer.id)) {
              foundLayers.push(layer);
            }
          }
        }

        return foundLayers;
      };

      // Highlight layer
      const highlightLayer = (layer: LayerDefinition | null) => {
        // Remove all highlights
        iframeDoc.querySelectorAll('[data-layer], [data-layer-border]').forEach(el => {
          el.classList.remove('inspect-hover', 'inspect-selected');
        });

        if (layer) {
          const elements = iframeDoc.querySelectorAll(layer.selector);
          elements.forEach(el => {
            if (layer.id === selectedLayerId) {
              el.classList.add('inspect-selected');
            } else {
              el.classList.add('inspect-hover');
            }
          });
        }
      };

      // Mouse move handler
      const handleMouseMove = (e: MouseEvent) => {
        if (!inspectMode) return;

        const layersAtPoint = findLayersAtPoint(e.clientX, e.clientY);
        const topLayer = layersAtPoint[0] || null;

        if (topLayer?.id !== hoveredLayer?.id) {
          setHoveredLayer(topLayer);
          onLayerHover?.(topLayer);
          highlightLayer(topLayer);
        }
      };

      // Click handler (Phase 4.0: Only in Edit mode)
      const handleClick = (e: MouseEvent) => {
        if (!inspectMode) return; // Interact mode: let normal survey behavior happen

        e.preventDefault();
        e.stopPropagation();

        // Phase 4.1: Collect all ancestor layers
        const layersAtPoint = findLayersAtPoint(e.clientX, e.clientY);
        
        // Also check ancestors for overlapping layers
        const target = e.target as HTMLElement;
        if (target) {
          let current: HTMLElement | null = target;
          while (current && current !== iframeDoc.body) {
            // Phase 4.1: Check both data-layer and data-layer-border attributes
            const layerId = current.getAttribute('data-layer') || current.getAttribute('data-layer-border');
            if (layerId) {
              const layer = layers.find(l => l.id === layerId);
              if (layer && !layersAtPoint.find(l => l.id === layer.id)) {
                layersAtPoint.push(layer);
              }
            }
            current = current.parentElement;
          }
        }

        if (layersAtPoint.length === 1) {
          // Single layer - select it
          onLayerSelect?.(layersAtPoint[0]);
        } else if (layersAtPoint.length > 1) {
          // Multiple layers - show popup (for now, just select topmost)
          // TODO: Implement layer picker popup menu
          onLayerSelect?.(layersAtPoint[0]);
        } else {
          // No layer - deselect
          onLayerSelect?.(null);
        }
      };

      // Prevent default interactions in Edit mode (Phase 4.0)
      const handleMouseDown = (e: MouseEvent) => {
        if (inspectMode) {
          // In Edit mode, prevent form interactions to allow layer selection
          if (e.target instanceof HTMLInputElement || e.target instanceof HTMLButtonElement) {
            e.preventDefault();
          }
        }
        // In Interact mode, let normal behavior happen
      };

      iframeDoc.addEventListener('mousemove', handleMouseMove);
      iframeDoc.addEventListener('click', handleClick);
      iframeDoc.addEventListener('mousedown', handleMouseDown);

      // Initial highlight for selected layer
      if (selectedLayerId) {
        const selectedLayer = layers.find(l => l.id === selectedLayerId);
        if (selectedLayer) {
          highlightLayer(selectedLayer);
        }
      }

      return () => {
        iframeDoc.removeEventListener('mousemove', handleMouseMove);
        iframeDoc.removeEventListener('click', handleClick);
        iframeDoc.removeEventListener('mousedown', handleMouseDown);
      };
    }

    // Wait for iframe to load
    const handleLoad = () => {
      const iframeDoc = iframe.contentDocument || iframe.contentWindow?.document;
      if (!iframeDoc) return;
      
      setupInspectMode(iframeDoc);
    };

    iframe.addEventListener('load', handleLoad);
    
    // Try immediately in case iframe is already loaded
    const iframeDoc = iframe.contentDocument || iframe.contentWindow?.document;
    if (iframeDoc && iframeDoc.readyState === 'complete') {
      setupInspectMode(iframeDoc);
    }

    return () => {
      iframe.removeEventListener('load', handleLoad);
    };
  }, [inspectMode, layers, selectedLayerId, hoveredLayer, onLayerHover, onLayerSelect]);

  return (
    <div className="inspectable-preview-frame" style={{ width }}>
      <iframe
        ref={iframeRef}
        srcDoc={html}
        title={title}
        style={{
          width: '100%',
          height: '600px',
          border: '1px solid #e5e7eb',
          borderRadius: '8px',
          backgroundColor: '#ffffff',
          pointerEvents: inspectMode ? 'auto' : 'auto'
        }}
      />
    </div>
  );
}
