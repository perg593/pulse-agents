/**
 * Phase 4.5: UI Color Tokens
 * App-wide UI color tokens for consistent styling across the Theme Designer
 */

export const UI_COLORS = {
  bg: '#F8FAFC',          // app background
  panel: '#FFFFFF',       // panel/card background
  border: '#E2E8F0',      // neutral-200
  divider: '#E5E7EB',     // neutral-300
  text: '#1E293B',        // neutral-800
  textMuted: '#64748B',   // neutral-500/600
  primary: '#3B82F6',     // blue-500/600
  primaryHover: '#2563EB',// blue-700
  focusRing: '#3B82F6',
  canvasDarkBg: '#1E293B', // dark bg behind mobile frames
  
  // Additional semantic colors
  success: '#10B981',     // green-500
  warning: '#F59E0B',     // amber-500
  error: '#EF4444',       // red-500
  
  // Interactive states
  hoverBg: '#F1F5F9',     // neutral-100
  selectedBg: '#EFF6FF',  // blue-50
  selectedText: '#1D4ED8', // blue-700
} as const;

export type UIColor = typeof UI_COLORS[keyof typeof UI_COLORS];

