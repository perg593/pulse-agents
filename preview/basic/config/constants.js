/**
 * @fileoverview Preview Application Constants
 * 
 * Centralized constants for the preview application to eliminate magic strings
 * and hardcoded values throughout the codebase.
 */

/**
 * Presentation-related constants
 */
const PRESENTATION = {
  /** Default timeout for presentation operations in milliseconds */
  TIMEOUT_MS: 10000,
  
  /** Cooldown period between duplicate presentations in milliseconds */
  COOLDOWN_MS: 10000,
  
  /** Maximum number of presentation retries */
  MAX_RETRIES: 3,
  
  /** Delay between retry attempts in milliseconds */
  RETRY_DELAY_MS: 1000,
  
  /** Maximum queue size for presentation requests */
  MAX_QUEUE_SIZE: 50,
  
  /** Deduplication window in milliseconds */
  DEDUPLICATION_WINDOW_MS: 2000
};

/**
 * Player-related constants
 */
const PLAYER = {
  /** Timeout for waiting for player bridge to be ready in milliseconds */
  BRIDGE_READY_TIMEOUT_MS: 10000,
  
  /** Frame margin for overlay layout in pixels */
  FRAME_MARGIN: 24,
  
  /** Maximum geometry retry attempts */
  MAX_GEOMETRY_RETRIES: 3,
  
  /** Geometry retry delays in milliseconds */
  GEOMETRY_RETRY_DELAYS: [500, 1000, 2000]
};

/**
 * Tag-related constants
 */
const TAG = {
  /** Timeout for waiting for tag to be ready in milliseconds */
  READY_TIMEOUT_MS: 6000,
  
  /** Health check interval in milliseconds */
  HEALTH_CHECK_INTERVAL_MS: 5000,
  
  /** Maximum tag retry attempts */
  MAX_RETRIES: 3
};

/**
 * Behavior-related constants
 */
const BEHAVIOR = {
  /** Scroll depth threshold percentage */
  SCROLL_DEPTH_THRESHOLD: 60,
  
  /** Rage click threshold (number of clicks) */
  RAGE_CLICK_THRESHOLD: 6,
  
  /** Time delay default in milliseconds */
  TIME_DELAY_DEFAULT_MS: 1500,
  
  /** Idle timeout default in milliseconds */
  IDLE_TIMEOUT_DEFAULT_MS: 10000
};

/**
 * UI-related constants
 */
const UI = {
  /** Delay for UI settling in milliseconds */
  SETTLE_DELAY_MS: 100,
  
  /** Animation duration in milliseconds */
  ANIMATION_DURATION_MS: 300,
  
  /** Log visibility toggle delay in milliseconds */
  LOG_TOGGLE_DELAY_MS: 200
};

/**
 * URL parameter names
 */
const URL_PARAMS = {
  /** Present parameter (survey ID) */
  PRESENT: 'present',
  
  /** Demo code filter parameter */
  DEMO_CODE: 'demo',
  
  /** Demo for filter parameter */
  DEMO_FOR: 'demo_for',
  
  /** Demo dismissed parameter */
  DEMO_DISMISSED: 'demo_dismissed'
};

/**
 * Session storage keys
 */
const STORAGE_KEYS = {
  /** Presentation history storage key */
  PRESENTATION_HISTORY: 'pi_presentation_history',
  
  /** Preview state storage key */
  PREVIEW_STATE: 'pi_preview_state'
};

/**
 * Event names
 */
const EVENTS = {
  /** Pulse Insights ready event */
  PULSEINSIGHTS_READY: 'pulseinsights:ready',
  
  /** Pulse Insights error event */
  PULSEINSIGHTS_ERROR: 'pulseinsights:error',
  
  /** Player ready event */
  PLAYER_READY: 'player-ready',
  
  /** Presentation queued event */
  PRESENTATION_QUEUED: 'presentation:queued',
  
  /** Presentation processed event */
  PRESENTATION_PROCESSED: 'presentation:processed',
  
  /** Presentation rejected event */
  PRESENTATION_REJECTED: 'presentation:rejected',
  
  /** Presentation error event */
  PRESENTATION_ERROR: 'presentation:error'
};

module.exports = {
  PRESENTATION,
  PLAYER,
  TAG,
  BEHAVIOR,
  UI,
  URL_PARAMS,
  STORAGE_KEYS,
  EVENTS
};

