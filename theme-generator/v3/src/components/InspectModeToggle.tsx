/**
 * Phase 4.0: Inspect vs Interact Mode Toggle
 */

type PreviewBehavior = 'interact' | 'inspect';

interface InspectModeToggleProps {
  mode: PreviewBehavior;
  onChange: (mode: PreviewBehavior) => void;
}

export function InspectModeToggle({ mode, onChange }: InspectModeToggleProps) {
  return (
    <div className="inspect-mode-toggle">
      <span className="toggle-label">Preview Behavior:</span>
      <div className="toggle-buttons">
        <button
          type="button"
          className={`toggle-button ${mode === 'interact' ? 'active' : ''}`}
          onClick={() => onChange('interact')}
        >
          Interact
        </button>
        <button
          type="button"
          className={`toggle-button ${mode === 'inspect' ? 'active' : ''}`}
          onClick={() => onChange('inspect')}
        >
          Inspect
        </button>
      </div>
    </div>
  );
}

