/**
 * Phase 4.0: Layers Tab
 * Shows a list of all layers for the current widget/question/device combination
 */

import { getLayersByGroup } from '../layers/definitions';
import { LayerInspector } from './LayerInspector';
import type { LayerDefinition } from '../types/layers';

type CanvasMode = 'edit' | 'interact';

interface LayersTabProps {
  selectedLayerId: string | null;
  onLayerSelect: (layer: LayerDefinition | null) => void;
  canvasMode: CanvasMode;
}

export function LayersTab({ selectedLayerId, onLayerSelect, canvasMode }: LayersTabProps) {
  // Phase 4.1: Use centralized layer definitions
  const widgetLayers = getLayersByGroup('widget');
  const questionLayers = getLayersByGroup('question');
  const controlsLayers = getLayersByGroup('controls');
  
  const selectedLayer = selectedLayerId
    ? [...widgetLayers, ...questionLayers, ...controlsLayers].find(l => l.id === selectedLayerId)
    : null;

  return (
    <div className="layers-tab">
      <div className="layers-tab-header">
        <h2>Layers</h2>
        {canvasMode === 'interact' && (
          <div className="layers-mode-notice">
            Switch to Edit mode to select layers
          </div>
        )}
      </div>
      
      <div className="layers-content">
        <div className="layers-list">
          {/* Widget Group */}
          <div className="layer-group">
            <div className="layer-group-header">Widget</div>
            <div className="layer-group-items">
              {widgetLayers.map((layer) => (
                <button
                  key={layer.id}
                  type="button"
                  className={`layer-item ${selectedLayerId === layer.id ? 'selected' : ''}`}
                  onClick={() => canvasMode === 'edit' && onLayerSelect(layer)}
                  disabled={canvasMode === 'interact'}
                >
                  <div className="layer-item-name">{layer.displayName}</div>
                  <div className="layer-item-tokens">
                    {layer.mappings.map((mapping, index) => (
                      <code key={index} className="token-path-small">
                        {mapping.tokenPath.split('.').pop()}
                      </code>
                    ))}
                  </div>
                </button>
              ))}
            </div>
          </div>
          
          {/* Question Group */}
          <div className="layer-group">
            <div className="layer-group-header">Question</div>
            <div className="layer-group-items">
              {questionLayers.map((layer) => (
                <button
                  key={layer.id}
                  type="button"
                  className={`layer-item ${selectedLayerId === layer.id ? 'selected' : ''}`}
                  onClick={() => canvasMode === 'edit' && onLayerSelect(layer)}
                  disabled={canvasMode === 'interact'}
                >
                  <div className="layer-item-name">{layer.displayName}</div>
                  <div className="layer-item-tokens">
                    {layer.mappings.map((mapping, index) => (
                      <code key={index} className="token-path-small">
                        {mapping.tokenPath.split('.').pop()}
                      </code>
                    ))}
                  </div>
                </button>
              ))}
            </div>
          </div>
          
          {/* Controls Group */}
          <div className="layer-group">
            <div className="layer-group-header">Controls</div>
            <div className="layer-group-items">
              {controlsLayers.map((layer) => (
                <button
                  key={layer.id}
                  type="button"
                  className={`layer-item ${selectedLayerId === layer.id ? 'selected' : ''}`}
                  onClick={() => canvasMode === 'edit' && onLayerSelect(layer)}
                  disabled={canvasMode === 'interact'}
                >
                  <div className="layer-item-name">{layer.displayName}</div>
                  <div className="layer-item-tokens">
                    {layer.mappings.map((mapping, index) => (
                      <code key={index} className="token-path-small">
                        {mapping.tokenPath.split('.').pop()}
                      </code>
                    ))}
                  </div>
                </button>
              ))}
            </div>
          </div>
        </div>
        
        {/* Phase 4.1: Layer Inspector side panel */}
        {canvasMode === 'edit' && selectedLayer && (
          <div className="layers-inspector-panel">
            <LayerInspector
              layer={selectedLayer}
              onClose={() => onLayerSelect(null)}
            />
          </div>
        )}
      </div>
    </div>
  );
}

