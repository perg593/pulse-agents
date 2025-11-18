/**
 * Phase 4.5: UI Typography Tokens
 * Typography roles for consistent text styling across the Theme Designer
 */

export const UI_TYPOGRAPHY = {
  title: {
    fontWeight: 600,
    fontSize: 18,
    fontFamily: 'Inter, system-ui, sans-serif',
  },
  section: {
    fontWeight: 500,
    fontSize: 15,
    fontFamily: 'Inter, system-ui, sans-serif',
  },
  label: {
    fontWeight: 500,
    fontSize: 13,
    fontFamily: 'Inter, system-ui, sans-serif',
  },
  body: {
    fontWeight: 400,
    fontSize: 14,
    fontFamily: 'Inter, system-ui, sans-serif',
  },
  small: {
    fontWeight: 400,
    fontSize: 12,
    fontFamily: 'Inter, system-ui, sans-serif',
  },
} as const;

export type UITypographyRole = keyof typeof UI_TYPOGRAPHY;

