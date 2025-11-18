/**
 * Phase 4.5: UI Motion Tokens
 * Motion constants for consistent animations and transitions
 */

export const UI_MOTION = {
  fast: '150ms ease',
  medium: '300ms ease-in-out',
  slow: '400ms ease-out',
} as const;

export type UIMotionSpeed = keyof typeof UI_MOTION;

