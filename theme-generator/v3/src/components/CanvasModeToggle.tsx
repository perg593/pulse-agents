/**
 * Phase 4.0: Canvas Mode Toggle (Edit vs Interact)
 */

type CanvasMode = 'edit' | 'interact';

interface CanvasModeToggleProps {
  mode: CanvasMode;
  onChange: (mode: CanvasMode) => void;
}

export function CanvasModeToggle({ mode, onChange }: CanvasModeToggleProps) {
  return (
    <div className="canvas-mode-toggle">
      <span className="toggle-label">Canvas Mode:</span>
      <div className="toggle-buttons">
        <button
          type="button"
          className={`toggle-button ${mode === 'edit' ? 'active' : ''}`}
          onClick={() => onChange('edit')}
        >
          Edit
        </button>
        <button
          type="button"
          className={`toggle-button ${mode === 'interact' ? 'active' : ''}`}
          onClick={() => onChange('interact')}
        >
          Interact
        </button>
      </div>
    </div>
  );
}

