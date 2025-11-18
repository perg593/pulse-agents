import { useState } from 'react';
import { useThemeStore } from '../stores/themeStore';
import { analyzeSiteApi } from '../api/analyzeSite';

export function TopBar() {
  const projects = useThemeStore((state) => state.projects);
  const activeProjectId = useThemeStore((state) => state.activeProjectId);
  const setActiveProject = useThemeStore((state) => state.setActiveProject);
  const createProject = useThemeStore((state) => state.createProject);
  const updateProjectSourceUrl = useThemeStore((state) => state.updateProjectSourceUrl);
  const addGeneratedThemes = useThemeStore((state) => state.addGeneratedThemes);
  
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [analyzeError, setAnalyzeError] = useState<string | null>(null);
  
  const activeProject = projects.find(p => p.id === activeProjectId);
  
  const handleSourceUrlChange = (url: string) => {
    if (activeProject) {
      updateProjectSourceUrl(activeProject.id, url);
    }
  };
  
  const handleSourceUrlFocus = () => {
    if (activeProject && (!activeProject.sourceUrl || activeProject.sourceUrl.trim() === '')) {
      updateProjectSourceUrl(activeProject.id, 'https://www.');
    }
  };
  
  const handleAnalyze = async () => {
    if (!activeProject || !activeProject.sourceUrl) {
      setAnalyzeError('Please enter a source URL first');
      return;
    }
    
    setIsAnalyzing(true);
    setAnalyzeError(null);
    
    try {
      const response = await analyzeSiteApi({
        url: activeProject.sourceUrl,
        maxPages: 1
      });
      
      // Add generated themes to the project with snapshot data
      addGeneratedThemes(activeProject.id, response.themes, response.snapshot);
    } catch (error) {
      console.error('Failed to analyze site:', error);
      let errorMessage = error instanceof Error ? error.message : 'Failed to analyze site';
      
      const hint = (error as any)?.hint;
      if (hint) {
        errorMessage = `${errorMessage}\n\n💡 ${hint}`;
      }
      
      setAnalyzeError(errorMessage);
    } finally {
      setIsAnalyzing(false);
    }
  };
  
  const handleProjectChange = (projectId: string) => {
    setActiveProject(projectId);
  };
  
  return (
    <div className="top-bar">
      <div className="top-bar-left">
        <select
          className="project-select"
          value={activeProjectId || ''}
          onChange={(e) => handleProjectChange(e.target.value)}
        >
          {projects.map((project) => (
            <option key={project.id} value={project.id}>
              {project.name}
            </option>
          ))}
        </select>
        <button
          className="btn-create-small"
          onClick={() => createProject()}
          title="Create New Project"
        >
          + New Project
        </button>
      </div>
      
      <div className="top-bar-center">
        {activeProject && (
          <>
            <input
              type="url"
              className="top-url-input"
              placeholder="https://example.com"
              value={activeProject.sourceUrl || ''}
              onChange={(e) => handleSourceUrlChange(e.target.value)}
              onFocus={handleSourceUrlFocus}
            />
            <button
              className="btn-analyze-top"
              onClick={handleAnalyze}
              disabled={isAnalyzing || !activeProject.sourceUrl}
              title="Analyze site and generate 4 themes"
            >
              {isAnalyzing ? 'Analyzing...' : 'Analyze'}
            </button>
            {analyzeError && (
              <div className="top-error-message">{analyzeError}</div>
            )}
          </>
        )}
      </div>
      
      <div className="top-bar-right">
        {activeProject && (
          <span className="project-theme-count">
            {activeProject.themes.length} theme{activeProject.themes.length !== 1 ? 's' : ''}
          </span>
        )}
      </div>
    </div>
  );
}

