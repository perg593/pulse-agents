import { useState } from 'react';
import { useThemeStore } from '../stores/themeStore';

export function ProjectSelector() {
  const projects = useThemeStore((state) => state.projects);
  const activeProjectId = useThemeStore((state) => state.activeProjectId);
  const setActiveProject = useThemeStore((state) => state.setActiveProject);
  const createProject = useThemeStore((state) => state.createProject);
  const renameProject = useThemeStore((state) => state.renameProject);
  const deleteProject = useThemeStore((state) => state.deleteProject);
  
  const [isRenaming, setIsRenaming] = useState<string | null>(null);
  const [renameValue, setRenameValue] = useState('');
  const [showDeleteConfirm, setShowDeleteConfirm] = useState<string | null>(null);
  
  const activeProject = projects.find(p => p.id === activeProjectId);
  
  const handleRenameStart = (projectId: string, currentName: string) => {
    setIsRenaming(projectId);
    setRenameValue(currentName);
  };
  
  const handleRenameSubmit = (projectId: string) => {
    if (renameValue.trim()) {
      renameProject(projectId, renameValue.trim());
    }
    setIsRenaming(null);
    setRenameValue('');
  };
  
  const handleRenameCancel = () => {
    setIsRenaming(null);
    setRenameValue('');
  };
  
  const handleDelete = (projectId: string) => {
    if (showDeleteConfirm === projectId) {
      deleteProject(projectId);
      setShowDeleteConfirm(null);
    } else {
      setShowDeleteConfirm(projectId);
    }
  };
  
  
  return (
    <div className="project-selector">
      <div className="selector-header">
        <h2>Projects</h2>
        <button
          className="btn-create"
          onClick={() => createProject()}
          title="Create New Project"
        >
          + New
        </button>
      </div>
      
      <div className="project-list">
        {projects.map((project) => (
          <div
            key={project.id}
            className={`project-item ${project.id === activeProjectId ? 'active' : ''}`}
          >
            {isRenaming === project.id ? (
              <div className="project-rename">
                <input
                  type="text"
                  value={renameValue}
                  onChange={(e) => setRenameValue(e.target.value)}
                  onBlur={() => handleRenameSubmit(project.id)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') {
                      handleRenameSubmit(project.id);
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
                  className="project-name"
                  onClick={() => setActiveProject(project.id)}
                >
                  {project.name}
                </button>
                <div className="project-actions">
                  <button
                    className="btn-icon"
                    onClick={() => handleRenameStart(project.id, project.name)}
                    title="Rename Project"
                  >
                    ✏️
                  </button>
                  {projects.length > 1 && (
                    <button
                      className="btn-icon"
                      onClick={() => handleDelete(project.id)}
                      title={showDeleteConfirm === project.id ? 'Confirm Delete' : 'Delete Project'}
                    >
                      {showDeleteConfirm === project.id ? '✓' : '🗑️'}
                    </button>
                  )}
                </div>
              </>
            )}
          </div>
        ))}
      </div>
      
      {activeProject && (
        <div className="project-info">
          <div className="info-item">
            <span className="info-label">Themes:</span>
            <span className="info-value">{activeProject.themes.length}</span>
          </div>
        </div>
      )}
    </div>
  );
}
