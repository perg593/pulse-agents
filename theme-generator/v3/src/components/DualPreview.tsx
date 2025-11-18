import { useEffect, useState } from 'react';
import { useThemeStore } from '../stores/themeStore';
import { DEVICE_WIDTHS, type DeviceType } from '../types/theme';
import { compileTheme } from '../theme/compileTheme';
import { getTemplateById, TEMPLATE_REGISTRY } from '../preview/templates';
import { InspectablePreview } from './InspectablePreview';
import { CanvasModeToggle } from './CanvasModeToggle';
import { DeviceSelector } from './DeviceSelector';
import { ContextModeToggle } from './ContextModeToggle';
import { LayerInspector } from './LayerInspector';
import { UndoRedoButtons } from './UndoRedoButtons';
import type { LayerDefinition } from '../types/layers';

type PreviewMode = 'clean' | 'context';
type CanvasMode = 'edit' | 'interact';

interface DualPreviewProps {
  previewMode: PreviewMode;
  onPreviewModeChange: (mode: PreviewMode) => void;
  canvasMode: CanvasMode;
  onCanvasModeChange: (mode: CanvasMode) => void;
  selectedLayerId: string | null;
  onLayerSelect: (layer: LayerDefinition | null) => void;
  onAdvancedClick: () => void;
}

export function DualPreview({ 
  previewMode,
  onPreviewModeChange,
  canvasMode, 
  onCanvasModeChange,
  selectedLayerId,
  onLayerSelect,
  onAdvancedClick
}: DualPreviewProps) {
  const activeTheme = useThemeStore((state) => state.getActiveTheme());
  const activeProject = useThemeStore((state) => state.getActiveProject());
  const getTemplateIdForDevice = useThemeStore((state) => state.getTemplateIdForDevice);
  const [compiledCSS, setCompiledCSS] = useState<string>('');
  const [device, setDevice] = useState<DeviceType>('desktop');

  // Phase 4.2: Get active template based on current widget/question/device
  const widgetType: import('../types/layers').WidgetType = 'docked';
  const questionType: import('../types/layers').QuestionType = 'single-choice';
  
  // Phase 4.2: Look up template ID using TemplateSelection state
  const templateId = getTemplateIdForDevice(widgetType, questionType, device);

  // Compile theme to CSS whenever theme changes
  useEffect(() => {
    if (!activeTheme) {
      setCompiledCSS('');
      return;
    }
    
    try {
      const css = compileTheme(activeTheme);
      setCompiledCSS(css);
    } catch (error) {
      console.error('Failed to compile theme:', error);
      setCompiledCSS('');
    }
  }, [activeTheme]);

  if (!activeTheme) {
    return (
      <div className="dual-preview">
        <div className="preview-empty">
          <p>Select a theme to see preview</p>
        </div>
      </div>
    );
  }

  // Phase 4.0: Single device preview
  const deviceWidth = DEVICE_WIDTHS[device];

  // Context mode background
  const backgroundStyle: React.CSSProperties = previewMode === 'context' && activeProject?.screenshotUrl
    ? {
        backgroundImage: `url(${activeProject.screenshotUrl})`,
        backgroundSize: 'cover',
        backgroundPosition: 'center',
        backgroundRepeat: 'no-repeat',
        position: 'relative'
      }
    : {
        background: '#f5f5f5'
      };

  // Phase 4.2: Get template using TemplateSelection state
  const template = getTemplateById(templateId) || TEMPLATE_REGISTRY[0];
  const previewHTML = template.generateHTML(compiledCSS);

  return (
    <div className="canvas-container" style={backgroundStyle}>
      {previewMode === 'context' && activeProject?.screenshotUrl && (
        <div className="context-overlay" />
      )}
      
      {/* Phase 4.5: Canvas header with grouped clusters */}
      {/* Phase 4.6: Added Undo/Redo buttons */}
      <div className="canvas-header">
        <div className="canvas-header-cluster">
          <CanvasModeToggle mode={canvasMode} onChange={onCanvasModeChange} />
        </div>
        <div className="canvas-header-cluster">
          <DeviceSelector device={device} onChange={setDevice} />
        </div>
        <div className="canvas-header-cluster">
          <UndoRedoButtons />
          <ContextModeToggle
            mode={previewMode}
            onChange={onPreviewModeChange}
            hasScreenshot={!!activeProject?.screenshotUrl}
          />
          <button
            type="button"
            className="advanced-config-button"
            onClick={onAdvancedClick}
            title="Advanced Configuration"
          >
            ⚙️
          </button>
        </div>
      </div>
      
      {/* Phase 4.5: Single device preview with device-specific frames */}
      <div className="canvas-preview-wrapper">
        <div className={`canvas-preview-frame`} data-device={device}>
          {device === 'iphone' || device === 'android' ? (
            <div className="preview-inner">
              <InspectablePreview
                html={previewHTML}
                layers={template.layers}
                inspectMode={canvasMode === 'edit'}
                selectedLayerId={selectedLayerId}
                onLayerSelect={onLayerSelect}
                width={deviceWidth}
                title={`${device} Preview`}
              />
            </div>
          ) : (
            <InspectablePreview
              html={previewHTML}
              layers={template.layers}
              inspectMode={canvasMode === 'edit'}
              selectedLayerId={selectedLayerId}
              onLayerSelect={onLayerSelect}
              width={deviceWidth}
              title={`${device} Preview`}
            />
          )}
        </div>
      </div>
      
      {/* Phase 4.1: Layer Inspector (only in Edit mode) */}
      {canvasMode === 'edit' && selectedLayerId && (
        <LayerInspector
          layer={template.layers.find((l) => l.id === selectedLayerId) || null}
          onClose={() => onLayerSelect(null)}
        />
      )}
    </div>
  );
}

