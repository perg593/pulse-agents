/**
 * Phase 4.6: Undo/Redo Buttons Component
 * Displays undo/redo controls in the Canvas header
 */

import { undoTokenChange, redoTokenChange, getUndoStackLength, getRedoStackLength } from '../theme/tokenManager';
import { useState, useEffect } from 'react';

export function UndoRedoButtons() {
  const [undoCount, setUndoCount] = useState(0);
  const [redoCount, setRedoCount] = useState(0);
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  // Update counts when stacks change
  useEffect(() => {
    const updateCounts = () => {
      setUndoCount(getUndoStackLength());
      setRedoCount(getRedoStackLength());
    };
    
    updateCounts();
    // Poll for changes (could be improved with event system later)
    const interval = setInterval(updateCounts, 100);
    return () => clearInterval(interval);
  }, []);

  const handleUndo = () => {
    const change = undoTokenChange();
    if (change) {
      const tokenMeta = require('../theme/tokenManager').getTokenMeta(change.tokenPath);
      const label = tokenMeta?.label || change.tokenPath;
      setToastMessage(`Undone: ${label}`);
      setTimeout(() => setToastMessage(null), 2000);
      setUndoCount(getUndoStackLength());
      setRedoCount(getRedoStackLength());
    }
  };

  const handleRedo = () => {
    const change = redoTokenChange();
    if (change) {
      const tokenMeta = require('../theme/tokenManager').getTokenMeta(change.tokenPath);
      const label = tokenMeta?.label || change.tokenPath;
      setToastMessage(`Redone: ${label}`);
      setTimeout(() => setToastMessage(null), 2000);
      setUndoCount(getUndoStackLength());
      setRedoCount(getRedoStackLength());
    }
  };

  return (
    <>
      <div className="undo-redo-buttons">
        <button
          type="button"
          className="undo-redo-button"
          onClick={handleUndo}
          disabled={undoCount === 0}
          title="Undo last change"
        >
          ↶
        </button>
        <button
          type="button"
          className="undo-redo-button"
          onClick={handleRedo}
          disabled={redoCount === 0}
          title="Redo last undone change"
        >
          ↷
        </button>
      </div>
      {toastMessage && (
        <div className="undo-redo-toast">
          {toastMessage}
        </div>
      )}
    </>
  );
}

