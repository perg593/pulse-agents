type PreviewMode = 'clean' | 'context';

interface ContextModeToggleProps {
  mode: PreviewMode;
  onChange: (mode: PreviewMode) => void;
  hasScreenshot: boolean;
}

export function ContextModeToggle({ mode, onChange, hasScreenshot }: ContextModeToggleProps) {
  return (
    <div className="context-mode-toggle">
      <span className="toggle-label">Preview Mode:</span>
      <div className="toggle-buttons">
        <button
          className={`toggle-button ${mode === 'clean' ? 'active' : ''}`}
          onClick={() => onChange('clean')}
        >
          Clean
        </button>
        <button
          className={`toggle-button ${mode === 'context' ? 'active' : ''}`}
          onClick={() => onChange('context')}
          disabled={!hasScreenshot}
          title={!hasScreenshot ? 'No screenshot available. Analyze a site first.' : 'Show widget on site screenshot'}
        >
          Context
        </button>
      </div>
    </div>
  );
}

