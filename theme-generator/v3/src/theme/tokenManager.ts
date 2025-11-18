/**
 * Phase 4.4: Token Manager & Unified Theme Update System
 * 
 * Centralized API for reading and writing theme tokens.
 * All theme changes should go through this module to ensure consistency,
 * enable provenance logging, and keep all views in sync.
 */

import { useThemeStore } from '../stores/themeStore';
import type { ThemeTokensLite } from '../types/theme';

export type TokenPath = string; // e.g. "palette.brandPrimary" or "components.ctaButton.bg"

export type TokenSource = 'themeEditor' | 'layerInspector' | 'analyzer' | 'advancedConfig' | 'undo' | 'redo' | 'reset-token' | 'reset-group' | 'reset-theme' | 'other';

export interface UpdateTokenOptions {
  source?: TokenSource;
}

export interface TokenChange {
  timestamp: number;
  tokenPath: TokenPath;
  oldValue: unknown;
  newValue: unknown;
  source?: TokenSource;
}

export type TokenChangeLog = TokenChange[];

// Phase 4.6: In-memory change log and undo/redo stacks
let changeLog: TokenChangeLog = [];
let undoStack: TokenChangeLog = [];
let redoStack: TokenChangeLog = [];

/**
 * Get value from theme by token path
 * @param tokenPath - Dot-separated path (e.g. "palette.brandPrimary")
 * @returns The value at the path, or undefined if not found
 */
export function getToken<T = unknown>(tokenPath: TokenPath): T | undefined {
  const state = useThemeStore.getState();
  const activeTheme = state.getActiveTheme();
  
  if (!activeTheme) {
    return undefined;
  }
  
  const parts = tokenPath.split('.');
  let value: any = activeTheme;
  
  for (const part of parts) {
    if (value && typeof value === 'object' && part in value) {
      value = value[part];
    } else {
      return undefined;
    }
  }
  
  return value as T;
}

/**
 * Build nested update object from token path and value
 */
function buildUpdateObject(tokenPath: TokenPath, value: unknown): Partial<ThemeTokensLite> {
  const parts = tokenPath.split('.');
  const updates: any = {};
  let current = updates;
  
  // Build nested update object
  for (let i = 0; i < parts.length - 1; i++) {
    current[parts[i]] = {};
    current = current[parts[i]];
  }
  
  // Set final value
  current[parts[parts.length - 1]] = value;
  
  return updates;
}

/**
 * Update a theme token value
 * @param tokenPath - Dot-separated path (e.g. "palette.brandPrimary")
 * @param value - New value for the token
 * @param options - Optional metadata about the update source
 */
export function updateToken(tokenPath: TokenPath, value: unknown, options?: UpdateTokenOptions): void {
  const state = useThemeStore.getState();
  const activeTheme = state.getActiveTheme();
  const activeProject = state.getActiveProject();
  
  if (!activeTheme || !activeProject) {
    console.warn('[TokenManager] Cannot update token: no active theme or project');
    return;
  }
  
  // Get current value for change log
  const oldValue = getToken(tokenPath);
  
  // Build update object
  const updates = buildUpdateObject(tokenPath, value);
  
  // Update via store
  state.updateThemeTokens(activeProject.id, activeTheme.id, updates);
  
  // Phase 4.6: Log change if value actually changed
  if (oldValue !== value) {
    const change: TokenChange = {
      timestamp: Date.now(),
      tokenPath,
      oldValue,
      newValue: value,
      source: options?.source
    };
    
    // Phase 4.6: Add to change log
    changeLog.push(change);
    
    // Keep log size reasonable (last 1000 changes)
    if (changeLog.length > 1000) {
      changeLog = changeLog.slice(-1000);
    }
    
    // Phase 4.6: Manage undo/redo stacks
    // Only add to undo stack if source is NOT undo/redo/reset operations
    const source = options?.source;
    if (source !== 'undo' && source !== 'redo' && source !== 'reset-token' && source !== 'reset-group' && source !== 'reset-theme') {
      undoStack.push(change);
      
      // Clear redo stack when new change is made
      redoStack = [];
      
      // Keep undo stack size reasonable (last 100 changes)
      if (undoStack.length > 100) {
        undoStack = undoStack.slice(-100);
      }
    }
  }
}

/**
 * Get the change log
 * @returns Array of token changes (read-only)
 */
export function getChangeLog(): readonly TokenChange[] {
  return changeLog;
}

/**
 * Clear the change log (useful for testing/debugging)
 */
export function clearChangeLog(): void {
  changeLog = [];
}

/**
 * Phase 4.6: Undo the last token change
 * @returns The change that was undone, or null if nothing to undo
 */
export function undoTokenChange(): TokenChange | null {
  if (undoStack.length === 0) {
    return null;
  }
  
  const change = undoStack.pop()!;
  
  // Apply the old value (undo)
  updateToken(change.tokenPath, change.oldValue, { source: 'undo' });
  
  // Push to redo stack
  redoStack.push(change);
  
  return change;
}

/**
 * Phase 4.6: Redo the last undone token change
 * @returns The change that was redone, or null if nothing to redo
 */
export function redoTokenChange(): TokenChange | null {
  if (redoStack.length === 0) {
    return null;
  }
  
  const change = redoStack.pop()!;
  
  // Apply the new value (redo)
  updateToken(change.tokenPath, change.newValue, { source: 'redo' });
  
  // Push back to undo stack
  undoStack.push(change);
  
  return change;
}

/**
 * Phase 4.6: Get undo stack length
 */
export function getUndoStackLength(): number {
  return undoStack.length;
}

/**
 * Phase 4.6: Get redo stack length
 */
export function getRedoStackLength(): number {
  return redoStack.length;
}

/**
 * Phase 4.6: Clear undo/redo stacks (useful when switching themes)
 */
export function clearUndoRedoStacks(): void {
  undoStack = [];
  redoStack = [];
}

/**
 * Phase 4.6: Reset a single token to its baseline value
 * @param tokenPath - Token path to reset
 * @returns True if reset was successful, false if baseline not found
 */
export function resetTokenToBaseline(tokenPath: TokenPath): boolean {
  const state = useThemeStore.getState();
  const activeTheme = state.getActiveTheme();
  const activeProject = state.getActiveProject();
  
  if (!activeTheme || !activeProject) {
    return false;
  }
  
  const baselineTheme = state.getBaselineTheme(activeProject.id, activeTheme.id);
  if (!baselineTheme) {
    return false;
  }
  
  // Get baseline value
  const parts = tokenPath.split('.');
  let baselineValue: any = baselineTheme;
  
  for (const part of parts) {
    if (baselineValue && typeof baselineValue === 'object' && part in baselineValue) {
      baselineValue = baselineValue[part];
    } else {
      return false;
    }
  }
  
  // Update token with baseline value
  updateToken(tokenPath, baselineValue, { source: 'reset-token' });
  return true;
}

/**
 * Phase 4.6: Reset a group of tokens to baseline values
 * @param tokenPaths - Array of token paths to reset
 * @returns Number of tokens successfully reset
 */
export function resetTokenGroup(tokenPaths: TokenPath[]): number {
  let resetCount = 0;
  tokenPaths.forEach(path => {
    if (resetTokenToBaseline(path)) {
      resetCount++;
    }
  });
  return resetCount;
}

/**
 * Phase 4.6: Reset entire theme to baseline
 * @returns Number of tokens successfully reset
 */
export function resetThemeToBaseline(): number {
  const state = useThemeStore.getState();
  const activeTheme = state.getActiveTheme();
  const activeProject = state.getActiveProject();
  
  if (!activeTheme || !activeProject) {
    return 0;
  }
  
  const baselineTheme = state.getBaselineTheme(activeProject.id, activeTheme.id);
  if (!baselineTheme) {
    return 0;
  }
  
  // Get all token paths from TOKEN_META
  const allTokenPaths = TOKEN_META.map(meta => meta.path);
  
  let resetCount = 0;
  allTokenPaths.forEach(tokenPath => {
    // Get baseline value
    const parts = tokenPath.split('.');
    let baselineValue: any = baselineTheme;
    
    for (const part of parts) {
      if (baselineValue && typeof baselineValue === 'object' && part in baselineValue) {
        baselineValue = baselineValue[part];
      } else {
        return; // Skip this token if path invalid
      }
    }
    
    // Update token with baseline value
    updateToken(tokenPath, baselineValue, { source: 'reset-theme' });
    resetCount++;
  });
  
  return resetCount;
}

// Token Metadata Registry
export interface TokenMeta {
  path: TokenPath;
  group: 'palette' | 'typography' | 'component' | 'layout';
  label: string;          // e.g. "Brand Primary"
  description?: string;   // optional help text
}

export const TOKEN_META: TokenMeta[] = [
  // Palette tokens
  { path: 'palette.background', group: 'palette', label: 'Background', description: 'Main background color' },
  { path: 'palette.surface', group: 'palette', label: 'Surface', description: 'Surface/elevated background color' },
  { path: 'palette.surfaceAlt', group: 'palette', label: 'Surface Alt', description: 'Alternate surface color' },
  { path: 'palette.textPrimary', group: 'palette', label: 'Text Primary', description: 'Primary text color' },
  { path: 'palette.textSecondary', group: 'palette', label: 'Text Secondary', description: 'Secondary text color' },
  { path: 'palette.brandPrimary', group: 'palette', label: 'Brand Primary', description: 'Primary brand color' },
  { path: 'palette.brandSecondary', group: 'palette', label: 'Brand Secondary', description: 'Secondary brand color' },
  { path: 'palette.accent', group: 'palette', label: 'Accent', description: 'Accent color' },
  { path: 'palette.success', group: 'palette', label: 'Success', description: 'Success state color' },
  { path: 'palette.danger', group: 'palette', label: 'Danger', description: 'Error/danger state color' },
  
  // Typography tokens (legacy)
  { path: 'typography.fontFamilyBase', group: 'typography', label: 'Base Font Family', description: 'Default font family' },
  { path: 'typography.fontFamilyHeading', group: 'typography', label: 'Heading Font Family', description: 'Font family for headings' },
  { path: 'typography.baseFontSize', group: 'typography', label: 'Base Font Size', description: 'Base font size in pixels' },
  { path: 'typography.headingSize', group: 'typography', label: 'Heading Size', description: 'Heading font size in pixels' },
  { path: 'typography.bodySize', group: 'typography', label: 'Body Size', description: 'Body text font size in pixels' },
  { path: 'typography.buttonSize', group: 'typography', label: 'Button Size', description: 'Button text font size in pixels' },
  // Phase 4.7: Enhanced Typography tokens
  { path: 'typography.heading.fontFamily', group: 'typography', label: 'Heading Font Family', description: 'Font family for headings' },
  { path: 'typography.heading.fontSize', group: 'typography', label: 'Heading Font Size', description: 'Font size for headings (px)' },
  { path: 'typography.heading.fontWeight', group: 'typography', label: 'Heading Font Weight', description: 'Font weight for headings' },
  { path: 'typography.heading.lineHeight', group: 'typography', label: 'Heading Line Height', description: 'Line height for headings' },
  { path: 'typography.body.fontFamily', group: 'typography', label: 'Body Font Family', description: 'Font family for body text' },
  { path: 'typography.body.fontSize', group: 'typography', label: 'Body Font Size', description: 'Font size for body text (px)' },
  { path: 'typography.body.fontWeight', group: 'typography', label: 'Body Font Weight', description: 'Font weight for body text' },
  { path: 'typography.body.lineHeight', group: 'typography', label: 'Body Line Height', description: 'Line height for body text' },
  { path: 'typography.button.fontFamily', group: 'typography', label: 'Button Font Family', description: 'Font family for buttons' },
  { path: 'typography.button.fontSize', group: 'typography', label: 'Button Font Size', description: 'Font size for buttons (px)' },
  { path: 'typography.button.fontWeight', group: 'typography', label: 'Button Font Weight', description: 'Font weight for buttons' },
  { path: 'typography.button.letterSpacing', group: 'typography', label: 'Button Letter Spacing', description: 'Letter spacing for buttons (px)' },
  { path: 'typography.button.lineHeight', group: 'typography', label: 'Button Line Height', description: 'Line height for buttons' },
  
  // Layout tokens (legacy)
  { path: 'layout.borderRadius', group: 'layout', label: 'Border Radius', description: 'Default border radius (px)' },
  { path: 'layout.spacingMd', group: 'layout', label: 'Spacing Medium', description: 'Medium spacing value (px)' },
  // Phase 4.7: Enhanced Layout tokens
  { path: 'layout.borderRadiusTokens.widget', group: 'layout', label: 'Widget Border Radius', description: 'Border radius for widget container (px)' },
  { path: 'layout.borderRadiusTokens.button', group: 'layout', label: 'Button Border Radius', description: 'Border radius for buttons (px)' },
  { path: 'layout.borderRadiusTokens.option', group: 'layout', label: 'Option Border Radius', description: 'Border radius for option items (px)' },
  { path: 'layout.borderRadiusTokens.input', group: 'layout', label: 'Input Border Radius', description: 'Border radius for input fields (px)' },
  { path: 'layout.spacing.optionGap', group: 'layout', label: 'Option Gap', description: 'Vertical spacing between options (px)' },
  { path: 'layout.spacing.widgetPadding', group: 'layout', label: 'Widget Padding', description: 'Padding inside widget container (px)' },
  { path: 'layout.spacing.sectionSpacing', group: 'layout', label: 'Section Spacing', description: 'Spacing between sections (px)' },
  { path: 'layout.maxWidth.widget', group: 'layout', label: 'Widget Max Width', description: 'Maximum width of widget container (px)' },
  
  // Component tokens - Widget
  { path: 'components.widget.headerBg', group: 'component', label: 'Widget Header Background', description: 'Background color for widget header' },
  { path: 'components.widget.headerText', group: 'component', label: 'Widget Header Text', description: 'Text color for widget header' },
  { path: 'components.widget.bodyBg', group: 'component', label: 'Widget Body Background', description: 'Background color for widget body' },
  { path: 'components.widget.bodyText', group: 'component', label: 'Widget Body Text', description: 'Text color for widget body' },
  { path: 'components.widget.borderColor', group: 'component', label: 'Widget Border Color', description: 'Border color for widget' },
  
  // Component tokens - Single Choice
  { path: 'components.singleChoice.bgDefault', group: 'component', label: 'Single Choice Default Background', description: 'Background color for unselected single choice option' },
  { path: 'components.singleChoice.textDefault', group: 'component', label: 'Single Choice Default Text', description: 'Text color for unselected single choice option' },
  { path: 'components.singleChoice.borderDefault', group: 'component', label: 'Single Choice Default Border', description: 'Border color for unselected single choice option' },
  { path: 'components.singleChoice.bgActive', group: 'component', label: 'Single Choice Active Background', description: 'Background color for selected single choice option' },
  { path: 'components.singleChoice.textActive', group: 'component', label: 'Single Choice Active Text', description: 'Text color for selected single choice option' },
  { path: 'components.singleChoice.borderActive', group: 'component', label: 'Single Choice Active Border', description: 'Border color for selected single choice option' },
  
  // Component tokens - CTA Button
  { path: 'components.ctaButton.bg', group: 'component', label: 'CTA Button Background', description: 'Background color for CTA button' },
  { path: 'components.ctaButton.text', group: 'component', label: 'CTA Button Text', description: 'Text color for CTA button' },
  { path: 'components.ctaButton.border', group: 'component', label: 'CTA Button Border', description: 'Border color for CTA button' },
  { path: 'components.ctaButton.bgHover', group: 'component', label: 'CTA Button Hover Background', description: 'Background color for CTA button on hover' },
  
  // Component tokens - Text Input
  { path: 'components.textInput.bg', group: 'component', label: 'Text Input Background', description: 'Background color for text input' },
  { path: 'components.textInput.text', group: 'component', label: 'Text Input Text', description: 'Text color for text input' },
  { path: 'components.textInput.border', group: 'component', label: 'Text Input Border', description: 'Border color for text input' },
  { path: 'components.textInput.placeholder', group: 'component', label: 'Text Input Placeholder', description: 'Placeholder text color for text input' },
];

/**
 * Get metadata for a token path
 */
export function getTokenMeta(tokenPath: TokenPath): TokenMeta | undefined {
  return TOKEN_META.find(meta => meta.path === tokenPath);
}

/**
 * Get all tokens in a group
 */
export function getTokensByGroup(group: TokenMeta['group']): TokenMeta[] {
  return TOKEN_META.filter(meta => meta.group === group);
}

