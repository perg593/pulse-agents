import { create } from 'zustand';
import type { ThemeTokensLite, ThemeProject, ThemeAppState, Viewport } from '../types/theme';
import type { TemplateSelection, TemplateSelectionKey, AdvancedConfigOptions, CanvasDeviceType } from '../types/layers';
import { clearUndoRedoStacks } from '../theme/tokenManager';

const STORAGE_KEY = 'pi-theme-generator-v3:projects';
const TEMPLATE_SELECTION_STORAGE_KEY = 'pi-theme-generator-v3:template-selections';
const ADVANCED_CONFIG_STORAGE_KEY = 'pi-theme-generator-v3:advanced-config';

function generateId(): string {
  return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}

function createDefaultTheme(): ThemeTokensLite {
  return {
    id: generateId(),
    name: 'Default Theme',
    variantType: 'custom',
    
    palette: {
      background: '#ffffff',
      surface: '#f9fafb',
      surfaceAlt: '#f3f4f6',
      textPrimary: '#111827',
      textSecondary: '#4b5563',
      brandPrimary: '#2563eb',
      brandSecondary: '#9333ea',
      accent: '#f97316',
      danger: '#dc2626',
      success: '#16a34a'
    },
    
    typography: {
      fontFamilyBase: 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
      fontFamilyHeading: undefined,
      baseFontSize: 14,
      headingSize: 18,
      bodySize: 14,
      buttonSize: 14,
      // Phase 4.7: Enhanced typography roles
      heading: {
        fontFamily: 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
        fontSize: 18,
        fontWeight: 600,
        lineHeight: 1.3
      },
      body: {
        fontFamily: 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
        fontSize: 14,
        fontWeight: 400,
        lineHeight: 1.5
      },
      button: {
        fontFamily: 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
        fontSize: 14,
        fontWeight: 600,
        letterSpacing: 0.5,
        lineHeight: 1.4
      }
    },
    
    components: {
      widget: {
        headerBg: '#ffffff',
        headerText: '#111827',
        bodyBg: '#ffffff',
        bodyText: '#111827',
        borderColor: '#e5e7eb'
      },
      singleChoice: {
        bgDefault: '#ffffff',
        bgActive: '#2563eb',
        textDefault: '#111827',
        textActive: '#ffffff',
        borderDefault: '#2563eb',
        borderActive: '#2563eb'
      },
      ctaButton: {
        bg: '#2563eb',
        text: '#ffffff',
        bgHover: '#9333ea',
        textHover: '#ffffff'
      }
    },
    
    layout: {
      borderRadius: 8,
      spacingMd: 12,
      // Phase 4.7: Enhanced layout tokens
      borderRadiusTokens: {
        widget: 8,
        button: 8,
        option: 8,
        input: 4
      },
      spacing: {
        optionGap: 12,
        widgetPadding: 24,
        sectionSpacing: 20
      },
      maxWidth: {
        widget: 420
      }
    }
  };
}

function createDefaultProject(): ThemeProject {
  const defaultTheme = createDefaultTheme();
  const now = new Date().toISOString();
  
  // Phase 4.6: Set baseline theme for default project
  const baselineTheme = JSON.parse(JSON.stringify(defaultTheme)) as ThemeTokensLite;
  
  return {
    id: generateId(),
    name: 'Untitled Project',
    sourceUrl: undefined,
    createdAt: now,
    updatedAt: now,
    themes: [defaultTheme],
    activeThemeId: defaultTheme.id,
    baselineThemes: {
      [defaultTheme.id]: baselineTheme
    }
  };
}

function loadFromStorage(): ThemeAppState | null {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (!stored) return null;
    
    const parsed = JSON.parse(stored) as ThemeAppState;
    
    // Validate structure
    if (!parsed.projects || !Array.isArray(parsed.projects)) {
      return null;
    }
    
    // Ensure at least one project exists
    if (parsed.projects.length === 0) {
      return null;
    }
    
    // Ensure activeProjectId points to a valid project
    if (parsed.activeProjectId) {
      const projectExists = parsed.projects.some(p => p.id === parsed.activeProjectId);
      if (!projectExists) {
        parsed.activeProjectId = parsed.projects[0].id;
      }
    } else {
      parsed.activeProjectId = parsed.projects[0].id;
    }
    
    // Ensure each project has at least one theme and valid activeThemeId
    parsed.projects.forEach(project => {
      if (project.themes.length === 0) {
        project.themes = [createDefaultTheme()];
      }
      const themeExists = project.themes.some(t => t.id === project.activeThemeId);
      if (!themeExists) {
        project.activeThemeId = project.themes[0].id;
      }
    });
    
    return parsed;
  } catch (error) {
    console.error('Failed to load from localStorage:', error);
    return null;
  }
}

function saveToStorage(state: ThemeAppState): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  } catch (error) {
    console.error('Failed to save to localStorage:', error);
  }
}

function loadTemplateSelectionsFromStorage(): TemplateSelection[] {
  try {
    const stored = localStorage.getItem(TEMPLATE_SELECTION_STORAGE_KEY);
    if (!stored) {
      // Phase 4.2: Return default selections
      return getDefaultTemplateSelections();
    }
    const parsed = JSON.parse(stored) as TemplateSelection[];
    // Validate structure
    if (Array.isArray(parsed)) {
      return parsed;
    }
    return getDefaultTemplateSelections();
  } catch (error) {
    console.error('Failed to load template selections from localStorage:', error);
    return getDefaultTemplateSelections();
  }
}

function getDefaultTemplateSelections(): TemplateSelection[] {
  return [
    {
      key: { widgetType: 'docked', questionType: 'single-choice', deviceType: 'desktop' },
      templateId: 'docked-single-desktop-v1'
    },
    {
      key: { widgetType: 'docked', questionType: 'single-choice', deviceType: 'iphone' },
      templateId: 'docked-single-iphone-v1'
    },
    {
      key: { widgetType: 'docked', questionType: 'single-choice', deviceType: 'android' },
      templateId: 'docked-single-android-v1'
    }
  ];
}

function saveTemplateSelectionsToStorage(selections: TemplateSelection[]): void {
  try {
    localStorage.setItem(TEMPLATE_SELECTION_STORAGE_KEY, JSON.stringify(selections));
  } catch (error) {
    console.error('Failed to save template selections to localStorage:', error);
  }
}

function loadAdvancedConfigFromStorage(): AdvancedConfigOptions {
  try {
    const stored = localStorage.getItem(ADVANCED_CONFIG_STORAGE_KEY);
    if (!stored) {
      return getDefaultAdvancedConfig();
    }
    const parsed = JSON.parse(stored) as AdvancedConfigOptions;
    // Merge with defaults to ensure all fields exist
    return {
      rendering: { ...getDefaultAdvancedConfig().rendering, ...parsed.rendering },
      editor: { ...getDefaultAdvancedConfig().editor, ...parsed.editor }
    };
  } catch (error) {
    console.error('Failed to load advanced config from localStorage:', error);
    return getDefaultAdvancedConfig();
  }
}

function getDefaultAdvancedConfig(): AdvancedConfigOptions {
  return {
    rendering: {
      enableAnimations: true,
      cacheTemplates: true,
      maxCacheSizeMB: 50
    },
    editor: {
      autoSaveChanges: true,
      debugMode: false
    }
  };
}

function saveAdvancedConfigToStorage(config: AdvancedConfigOptions): void {
  try {
    localStorage.setItem(ADVANCED_CONFIG_STORAGE_KEY, JSON.stringify(config));
  } catch (error) {
    console.error('Failed to save advanced config to localStorage:', error);
  }
}

interface ThemeStore extends ThemeAppState {
  viewport: Viewport;
  
  // Phase 4.2: Template selections (new structure)
  templateSelections: TemplateSelection[];
  
  // Phase 4.2: Advanced configuration options
  advancedConfig: AdvancedConfigOptions;
  
  // Initialization
  initializeFromStorage: () => void;
  
  // Project actions
  createProject: (name?: string) => void;
  renameProject: (projectId: string, newName: string) => void;
  setActiveProject: (projectId: string) => void;
  deleteProject: (projectId: string) => void;
  
  // Theme actions
  createTheme: (projectId: string, cloneFromId?: string) => void;
  renameTheme: (projectId: string, themeId: string, newName: string) => void;
  duplicateTheme: (projectId: string, themeId: string) => void;
  deleteTheme: (projectId: string, themeId: string) => void;
  setActiveTheme: (projectId: string, themeId: string) => void;
  updateThemeTokens: (projectId: string, themeId: string, updates: Partial<ThemeTokensLite>) => void;
  
  // Viewport
  setViewport: (viewport: Viewport) => void;
  
  // Project URL management
  updateProjectSourceUrl: (projectId: string, sourceUrl: string) => void;
  addGeneratedThemes: (projectId: string, themes: ThemeTokensLite[], snapshot?: import('../types/siteSnapshot').SiteSnapshot) => void;
  
  // Phase 4.2: Template selection
  getTemplateSelection: (key: TemplateSelectionKey) => TemplateSelection | null;
  setTemplateSelection: (selection: TemplateSelection) => void;
  getTemplateIdForDevice: (widgetType: import('../types/layers').WidgetType, questionType: import('../types/layers').QuestionType, deviceType: CanvasDeviceType) => string;
  
  // Phase 4.2: Advanced configuration
  updateAdvancedConfig: (updates: Partial<AdvancedConfigOptions>) => void;
  
  // Phase 4.6: Baseline theme management
  getBaselineTheme: (projectId: string, themeId: string) => ThemeTokensLite | null;
  setBaselineTheme: (projectId: string, themeId: string, theme: ThemeTokensLite) => void;
  
  // Helpers
  getActiveProject: () => ThemeProject | null;
  getActiveTheme: () => ThemeTokensLite | null;
}

export const useThemeStore = create<ThemeStore>((set, get) => ({
  projects: [],
  activeProjectId: null,
  viewport: 'desktop',
  templateSelections: [],
  advancedConfig: getDefaultAdvancedConfig(),
  
  initializeFromStorage: () => {
    const loaded = loadFromStorage();
    if (loaded) {
      set(loaded);
      
      // Phase 4.6: Ensure baseline themes exist for existing themes (migration)
      const state = get();
      const updatedProjects = state.projects.map(project => {
        const baselineThemes: Record<string, ThemeTokensLite> = { ...(project.baselineThemes || {}) };
        project.themes.forEach(theme => {
          if (!baselineThemes[theme.id]) {
            // Set current theme as baseline if no baseline exists
            baselineThemes[theme.id] = JSON.parse(JSON.stringify(theme)) as ThemeTokensLite;
          }
        });
        
        if (Object.keys(baselineThemes).length > 0) {
          return { ...project, baselineThemes };
        }
        return project;
      });
      
      if (updatedProjects.some((p, i) => p.baselineThemes !== state.projects[i]?.baselineThemes)) {
        const updatedState: ThemeAppState = {
          ...state,
          projects: updatedProjects
        };
        set(updatedState);
        saveToStorage(updatedState);
      }
    } else {
      const defaultProject = createDefaultProject();
      const initialState: ThemeAppState = {
        projects: [defaultProject],
        activeProjectId: defaultProject.id
      };
      set(initialState);
      saveToStorage(initialState);
    }
    
    // Phase 4.2: Load template selections and advanced config
    const templateSelections = loadTemplateSelectionsFromStorage();
    const advancedConfig = loadAdvancedConfigFromStorage();
    set({ templateSelections, advancedConfig });
  },
  
  createProject: (name) => {
    const state = get();
    const activeProject = state.getActiveProject();
    const newProject = createDefaultProject();
    
    // Clone active theme if available, otherwise use default
    if (activeProject) {
      const activeTheme = state.getActiveTheme();
      if (activeTheme) {
        const clonedTheme = { ...activeTheme, id: generateId(), name: `${activeTheme.name} (Copy)` };
        newProject.themes = [clonedTheme];
        newProject.activeThemeId = clonedTheme.id;
      }
    }
    
    newProject.name = name || `Project ${state.projects.length + 1}`;
    
    const updatedState: ThemeAppState = {
      projects: [...state.projects, newProject],
      activeProjectId: newProject.id
    };
    
    set(updatedState);
    saveToStorage(updatedState);
  },
  
  renameProject: (projectId, newName) => {
    const state = get();
    const updatedProjects = state.projects.map(project =>
      project.id === projectId
        ? { ...project, name: newName, updatedAt: new Date().toISOString() }
        : project
    );
    
    const updatedState: ThemeAppState = {
      ...state,
      projects: updatedProjects
    };
    
    set(updatedState);
    saveToStorage(updatedState);
  },
  
  setActiveProject: (projectId) => {
    const state = get();
    const updatedState: ThemeAppState = {
      ...state,
      activeProjectId: projectId
    };
    
    set(updatedState);
    saveToStorage(updatedState);
  },
  
  deleteProject: (projectId) => {
    const state = get();
    if (state.projects.length <= 1) {
      // Don't allow deleting the last project
      return;
    }
    
    const updatedProjects = state.projects.filter(p => p.id !== projectId);
    const newActiveProjectId = state.activeProjectId === projectId
      ? updatedProjects[0].id
      : state.activeProjectId;
    
    const updatedState: ThemeAppState = {
      projects: updatedProjects,
      activeProjectId: newActiveProjectId
    };
    
    set(updatedState);
    saveToStorage(updatedState);
  },
  
  createTheme: (projectId, cloneFromId) => {
    const state = get();
    const project = state.projects.find(p => p.id === projectId);
    if (!project) return;
    
    let newTheme: ThemeTokensLite;
    if (cloneFromId) {
      const sourceTheme = project.themes.find(t => t.id === cloneFromId);
      if (sourceTheme) {
        newTheme = { ...sourceTheme, id: generateId(), name: `${sourceTheme.name} (Copy)` };
      } else {
        newTheme = createDefaultTheme();
      }
    } else {
      newTheme = createDefaultTheme();
    }
    
    // Phase 4.6: Set baseline theme when creating
    const baselineTheme = JSON.parse(JSON.stringify(newTheme)) as ThemeTokensLite;
    
    const updatedProject: ThemeProject = {
      ...project,
      themes: [...project.themes, newTheme],
      activeThemeId: newTheme.id,
      baselineThemes: {
        ...(project.baselineThemes || {}),
        [newTheme.id]: baselineTheme
      },
      updatedAt: new Date().toISOString()
    };
    
    const updatedProjects = state.projects.map(p =>
      p.id === projectId ? updatedProject : p
    );
    
    const updatedState: ThemeAppState = {
      ...state,
      projects: updatedProjects
    };
    
    set(updatedState);
    saveToStorage(updatedState);
  },
  
  renameTheme: (projectId, themeId, newName) => {
    const state = get();
    const project = state.projects.find(p => p.id === projectId);
    if (!project) return;
    
    const updatedThemes = project.themes.map(theme =>
      theme.id === themeId
        ? { ...theme, name: newName }
        : theme
    );
    
    const updatedProject: ThemeProject = {
      ...project,
      themes: updatedThemes,
      updatedAt: new Date().toISOString()
    };
    
    const updatedProjects = state.projects.map(p =>
      p.id === projectId ? updatedProject : p
    );
    
    const updatedState: ThemeAppState = {
      ...state,
      projects: updatedProjects
    };
    
    set(updatedState);
    saveToStorage(updatedState);
  },
  
  duplicateTheme: (projectId, themeId) => {
    get().createTheme(projectId, themeId);
  },
  
  deleteTheme: (projectId, themeId) => {
    const state = get();
    const project = state.projects.find(p => p.id === projectId);
    if (!project || project.themes.length <= 1) {
      // Don't allow deleting the last theme
      return;
    }
    
    const updatedThemes = project.themes.filter(t => t.id !== themeId);
    const newActiveThemeId = project.activeThemeId === themeId
      ? updatedThemes[0].id
      : project.activeThemeId;
    
    const updatedProject: ThemeProject = {
      ...project,
      themes: updatedThemes,
      activeThemeId: newActiveThemeId,
      updatedAt: new Date().toISOString()
    };
    
    const updatedProjects = state.projects.map(p =>
      p.id === projectId ? updatedProject : p
    );
    
    const updatedState: ThemeAppState = {
      ...state,
      projects: updatedProjects
    };
    
    set(updatedState);
    saveToStorage(updatedState);
  },
  
  setActiveTheme: (projectId, themeId) => {
    const state = get();
    const project = state.projects.find(p => p.id === projectId);
    if (!project) return;
    
    const updatedProject: ThemeProject = {
      ...project,
      activeThemeId: themeId,
      updatedAt: new Date().toISOString()
    };
    
    const updatedProjects = state.projects.map(p =>
      p.id === projectId ? updatedProject : p
    );
    
    const updatedState: ThemeAppState = {
      ...state,
      projects: updatedProjects
    };
    
    set(updatedState);
    saveToStorage(updatedState);
    
    // Phase 4.6: Clear undo/redo stacks when switching themes
    clearUndoRedoStacks();
  },
  
  updateThemeTokens: (projectId, themeId, updates) => {
    const state = get();
    const project = state.projects.find(p => p.id === projectId);
    if (!project) return;
    
    // Helper to check if value is a plain object
    const isObject = (item: any): boolean => {
      return item && typeof item === 'object' && !Array.isArray(item);
    };
    
    // Deep merge helper function for nested theme updates
    const deepMerge = (target: any, source: any): any => {
      const output = { ...target };
      if (isObject(target) && isObject(source)) {
        Object.keys(source).forEach(key => {
          if (isObject(source[key])) {
            if (!(key in target)) {
              Object.assign(output, { [key]: source[key] });
            } else {
              output[key] = deepMerge(target[key], source[key]);
            }
          } else {
            Object.assign(output, { [key]: source[key] });
          }
        });
      }
      return output;
    };
    
    const updatedThemes = project.themes.map(theme =>
      theme.id === themeId
        ? deepMerge(theme, updates)
        : theme
    );
    
    const updatedProject: ThemeProject = {
      ...project,
      themes: updatedThemes,
      updatedAt: new Date().toISOString()
    };
    
    const updatedProjects = state.projects.map(p =>
      p.id === projectId ? updatedProject : p
    );
    
    const updatedState: ThemeAppState = {
      ...state,
      projects: updatedProjects
    };
    
    set(updatedState);
    saveToStorage(updatedState);
  },
  
  setViewport: (viewport) => set({ viewport }),
  
  updateProjectSourceUrl: (projectId, sourceUrl) => {
    const state = get();
    const updatedProjects = state.projects.map(project =>
      project.id === projectId
        ? { ...project, sourceUrl, updatedAt: new Date().toISOString() }
        : project
    );
    
    const updatedState: ThemeAppState = {
      ...state,
      projects: updatedProjects
    };
    
    set(updatedState);
    saveToStorage(updatedState);
  },
  
  addGeneratedThemes: (projectId, themes, snapshot) => {
    const state = get();
    const project = state.projects.find(p => p.id === projectId);
    if (!project) return;
    
    // Extract colors from snapshot for palette presets
    const extractedColors: string[] = [];
    if (snapshot) {
      if (snapshot.detectedColors.background) extractedColors.push(snapshot.detectedColors.background);
      if (snapshot.detectedColors.brandPrimary) extractedColors.push(snapshot.detectedColors.brandPrimary);
      if (snapshot.detectedColors.brandSecondary) extractedColors.push(snapshot.detectedColors.brandSecondary);
      if (snapshot.detectedColors.textPrimary) extractedColors.push(snapshot.detectedColors.textPrimary);
      if (snapshot.detectedColors.accent) extractedColors.push(snapshot.detectedColors.accent);
    }
    
    // Phase 4.6: Set baseline themes for generated themes
    const baselineThemes: Record<string, ThemeTokensLite> = { ...(project.baselineThemes || {}) };
    themes.forEach(theme => {
      baselineThemes[theme.id] = JSON.parse(JSON.stringify(theme)) as ThemeTokensLite;
    });
    
    const updatedProject: ThemeProject = {
      ...project,
      themes: [...project.themes, ...themes],
      activeThemeId: themes[0]?.id || project.activeThemeId, // Set first generated theme as active
      screenshotUrl: snapshot?.screenshotUrl || project.screenshotUrl,
      extractedColors: extractedColors.length > 0 ? extractedColors : project.extractedColors,
      baselineThemes,
      updatedAt: new Date().toISOString()
    };
    
    const updatedProjects = state.projects.map(p =>
      p.id === projectId ? updatedProject : p
    );
    
    const updatedState: ThemeAppState = {
      ...state,
      projects: updatedProjects
    };
    
    set(updatedState);
    saveToStorage(updatedState);
    
    // Phase 4.6: Clear undo/redo stacks when new themes are generated
    clearUndoRedoStacks();
  },
  
  getActiveProject: () => {
    const state = get();
    if (!state.activeProjectId) return null;
    return state.projects.find(p => p.id === state.activeProjectId) || null;
  },
  
  getActiveTheme: () => {
    const state = get();
    const project = state.getActiveProject();
    if (!project) return null;
    return project.themes.find(t => t.id === project.activeThemeId) || null;
  },
  
  // Phase 4.6: Baseline theme management
  getBaselineTheme: (projectId, themeId) => {
    const state = get();
    const project = state.projects.find(p => p.id === projectId);
    if (!project || !project.baselineThemes) return null;
    return project.baselineThemes[themeId] || null;
  },
  
  setBaselineTheme: (projectId, themeId, theme) => {
    const state = get();
    const project = state.projects.find(p => p.id === projectId);
    if (!project) return;
    
    // Deep copy the theme for baseline
    const baselineTheme = JSON.parse(JSON.stringify(theme)) as ThemeTokensLite;
    
    const updatedProject: ThemeProject = {
      ...project,
      baselineThemes: {
        ...(project.baselineThemes || {}),
        [themeId]: baselineTheme
      },
      updatedAt: new Date().toISOString()
    };
    
    const updatedProjects = state.projects.map(p =>
      p.id === projectId ? updatedProject : p
    );
    
    const updatedState: ThemeAppState = {
      ...state,
      projects: updatedProjects
    };
    
    set(updatedState);
    saveToStorage(updatedState);
  },
  
  getTemplateSelection: (key) => {
    const state = get();
    return state.templateSelections.find(
      s =>
        s.key.widgetType === key.widgetType &&
        s.key.questionType === key.questionType &&
        s.key.deviceType === key.deviceType
    ) || null;
  },
  
  setTemplateSelection: (selection) => {
    const state = get();
    const existingIndex = state.templateSelections.findIndex(
      s =>
        s.key.widgetType === selection.key.widgetType &&
        s.key.questionType === selection.key.questionType &&
        s.key.deviceType === selection.key.deviceType
    );
    
    let updatedSelections: TemplateSelection[];
    if (existingIndex >= 0) {
      updatedSelections = [...state.templateSelections];
      updatedSelections[existingIndex] = selection;
    } else {
      updatedSelections = [...state.templateSelections, selection];
    }
    
    set({ templateSelections: updatedSelections });
    saveTemplateSelectionsToStorage(updatedSelections);
  },
  
  getTemplateIdForDevice: (widgetType, questionType, deviceType) => {
    const state = get();
    const selection = state.getTemplateSelection({ widgetType, questionType, deviceType });
    if (selection) {
      return selection.templateId;
    }
    // Phase 4.2: Return default template IDs
    if (deviceType === 'desktop') {
      return 'docked-single-desktop-v1';
    } else if (deviceType === 'iphone') {
      return 'docked-single-iphone-v1';
    } else {
      return 'docked-single-android-v1';
    }
  },
  
  updateAdvancedConfig: (updates) => {
    const state = get();
    const updatedConfig: AdvancedConfigOptions = {
      rendering: { ...state.advancedConfig.rendering, ...updates.rendering },
      editor: { ...state.advancedConfig.editor, ...updates.editor }
    };
    set({ advancedConfig: updatedConfig });
    saveAdvancedConfigToStorage(updatedConfig);
  }
}));
