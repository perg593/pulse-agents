import { useEffect, useState } from 'react';
import { ProjectSelector } from './components/ProjectSelector';
import { ThemeSelector } from './components/ThemeSelector';
import { ThemeEditor } from './components/ThemeEditor';
import { DualPreview } from './components/DualPreview';
import { StyleGuide } from './components/StyleGuide';
import { LayersTab } from './components/LayersTab';
import { AdvancedConfig } from './components/AdvancedConfig';
import { TopBar } from './components/TopBar';
import { useThemeStore } from './stores/themeStore';
import './App.css';
import './ui/containers.css';

type ViewMode = 'canvas' | 'style-guide' | 'layers';
type PreviewMode = 'clean' | 'context';
type CanvasMode = 'edit' | 'interact';

function App() {
  const initializeFromStorage = useThemeStore((state) => state.initializeFromStorage);
  const [viewMode, setViewMode] = useState<ViewMode>('canvas');
  const [previewMode, setPreviewMode] = useState<PreviewMode>('clean');
  const [canvasMode, setCanvasMode] = useState<CanvasMode>('edit');
  const [showAdvancedConfig, setShowAdvancedConfig] = useState(false);
  const [selectedLayerId, setSelectedLayerId] = useState<string | null>(null);

  useEffect(() => {
    initializeFromStorage();
  }, [initializeFromStorage]);

  return (
    <div className="app">
      {/* Top Bar */}
      <TopBar />
      
      {/* Main Content Area */}
      <div className="app-main-layout">
        {/* Left Panel - Fixed Width, Independent Scroll */}
        <aside className="app-left-panel">
          <div className="left-panel-content">
            <ProjectSelector />
            <ThemeSelector />
            <ThemeEditor />
          </div>
        </aside>
        
        {/* Right Panel - Flex Width, Independent Scroll */}
        <main className="app-right-panel">
          <div className="right-panel-header">
            <div className="view-tabs">
              <button
                className={`tab-button ${viewMode === 'canvas' ? 'active' : ''}`}
                onClick={() => setViewMode('canvas')}
              >
                Canvas
              </button>
              <button
                className={`tab-button ${viewMode === 'style-guide' ? 'active' : ''}`}
                onClick={() => setViewMode('style-guide')}
              >
                Style Guide
              </button>
              <button
                className={`tab-button ${viewMode === 'layers' ? 'active' : ''}`}
                onClick={() => setViewMode('layers')}
              >
                Layers
              </button>
            </div>
            
            <div className="right-panel-header-actions">
              {viewMode !== 'canvas' && (
                <button
                  type="button"
                  className="advanced-config-button"
                  onClick={() => setShowAdvancedConfig(true)}
                >
                  Advanced
                </button>
              )}
            </div>
          </div>
          
          <div className="right-panel-content">
            {viewMode === 'canvas' ? (
              <DualPreview 
                previewMode={previewMode}
                onPreviewModeChange={setPreviewMode}
                canvasMode={canvasMode}
                onCanvasModeChange={setCanvasMode}
                selectedLayerId={selectedLayerId}
                onLayerSelect={(layer) => setSelectedLayerId(layer?.id || null)}
                onAdvancedClick={() => setShowAdvancedConfig(true)}
              />
            ) : viewMode === 'style-guide' ? (
              <StyleGuide />
            ) : (
              <LayersTab
                selectedLayerId={selectedLayerId}
                onLayerSelect={(layer) => setSelectedLayerId(layer?.id || null)}
                canvasMode={canvasMode}
              />
            )}
          </div>
          
          {showAdvancedConfig && (
            <AdvancedConfig onClose={() => setShowAdvancedConfig(false)} />
          )}
        </main>
      </div>
    </div>
  );
}

export default App;
