import { useState } from 'react';
import { useThemeStore } from '../stores/themeStore';

export function ThemeSelector() {
  const activeProject = useThemeStore((state) => state.getActiveProject());
  const setActiveTheme = useThemeStore((state) => state.setActiveTheme);
  const createTheme = useThemeStore((state) => state.createTheme);
  const renameTheme = useThemeStore((state) => state.renameTheme);
  const duplicateTheme = useThemeStore((state) => state.duplicateTheme);
  const deleteTheme = useThemeStore((state) => state.deleteTheme);
  
  const [isRenaming, setIsRenaming] = useState<string | null>(null);
  const [renameValue, setRenameValue] = useState('');
  const [showDeleteConfirm, setShowDeleteConfirm] = useState<string | null>(null);
  
  if (!activeProject) {
    return null;
  }
  
  const handleRenameStart = (themeId: string, currentName: string) => {
    setIsRenaming(themeId);
    setRenameValue(currentName);
  };
  
  const handleRenameSubmit = (themeId: string) => {
    if (renameValue.trim()) {
      renameTheme(activeProject.id, themeId, renameValue.trim());
    }
    setIsRenaming(null);
    setRenameValue('');
  };
  
  const handleRenameCancel = () => {
    setIsRenaming(null);
    setRenameValue('');
  };
  
  const handleDelete = (themeId: string) => {
    if (showDeleteConfirm === themeId) {
      deleteTheme(activeProject.id, themeId);
      setShowDeleteConfirm(null);
    } else {
      setShowDeleteConfirm(themeId);
    }
  };
  
  return (
    <div className="theme-selector">
      <div className="selector-header">
        <h2>Themes</h2>
        <button
          className="btn-create"
          onClick={() => createTheme(activeProject.id)}
          title="Create New Theme"
        >
          + New
        </button>
      </div>
      
      <div className="theme-list">
        {activeProject.themes.map((theme) => (
          <div
            key={theme.id}
            className={`theme-item ${theme.id === activeProject.activeThemeId ? 'active' : ''}`}
          >
            {isRenaming === theme.id ? (
              <div className="theme-rename">
                <input
                  type="text"
                  value={renameValue}
                  onChange={(e) => setRenameValue(e.target.value)}
                  onBlur={() => handleRenameSubmit(theme.id)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') {
                      handleRenameSubmit(theme.id);
                    } else if (e.key === 'Escape') {
                      handleRenameCancel();
                    }
                  }}
                  autoFocus
                  className="rename-input"
                />
              </div>
            ) : (
              <>
                <button
                  className="theme-name"
                  onClick={() => setActiveTheme(activeProject.id, theme.id)}
                >
                  {theme.name}
                </button>
                <div className="theme-actions">
                  <button
                    className="btn-icon"
                    onClick={() => handleRenameStart(theme.id, theme.name)}
                    title="Rename Theme"
                  >
                    ✏️
                  </button>
                  <button
                    className="btn-icon"
                    onClick={() => duplicateTheme(activeProject.id, theme.id)}
                    title="Duplicate Theme"
                  >
                    📋
                  </button>
                  {activeProject.themes.length > 1 && (
                    <button
                      className="btn-icon"
                      onClick={() => handleDelete(theme.id)}
                      title={showDeleteConfirm === theme.id ? 'Confirm Delete' : 'Delete Theme'}
                    >
                      {showDeleteConfirm === theme.id ? '✓' : '🗑️'}
                    </button>
                  )}
                </div>
              </>
            )}
          </div>
        ))}
      </div>
      
      {activeProject.activeThemeId && (
        <div className="theme-info">
          <div className="info-item">
            <span className="info-label">Variant:</span>
            <span className="info-value">
              {activeProject.themes.find(t => t.id === activeProject.activeThemeId)?.variantType || 'custom'}
            </span>
          </div>
        </div>
      )}
    </div>
  );
}

