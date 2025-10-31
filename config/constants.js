/**
 * Centralized constants configuration for behavior and UI settings
 * @fileoverview Constants used across the pulse widgets codebase
 */

/**
 * Behavior-related constants
 * @type {Object}
 */
const BEHAVIOR_CONSTANTS = {
  /** Idle timeout in milliseconds */
  IDLE_MS: 10000,
  
  /** Overlay auto-hide timeout in milliseconds */
  OVERLAY_AUTO_HIDE_MS: 3000,
  
  /** Scroll depth trigger threshold (0.0 to 1.0) */
  SCROLL_TRIGGER: 0.6,
  
  /** Scroll depth reset threshold (0.0 to 1.0) */
  SCROLL_RESET: 0.2,
  
  /** Rage click detection window in milliseconds */
  RAGE_WINDOW: 800,
  
  /** Rage click threshold (number of clicks) */
  RAGE_THRESHOLD: 3,
  
  /** Rage click distance threshold in pixels */
  RAGE_DISTANCE: 60
};

/**
 * UI-related constants
 * @type {Object}
 */
const UI_CONSTANTS = {
  /** Rail toggle sequence */
  RAIL_TOGGLE_SEQUENCE: 'aaa',
  
  /** Demo library sequence */
  DEMO_LIBRARY_SEQUENCE: 'sss',
  
  /** Maximum sequence length */
  SEQUENCE_MAX_LENGTH: Math.max('aaa'.length, 'sss'.length),
  
  /** Rail shortcut reset timeout in milliseconds */
  RAIL_SHORTCUT_RESET_MS: 1500,
  
  /** Player frame margin in pixels */
  PLAYER_FRAME_MARGIN: 24
};

/**
 * Default behavior listener states
 * @type {Object}
 */
const BEHAVIOR_LISTENER_DEFAULTS = {
  'exit-intent': false,
  'scroll-depth': true,
  'time-delay': false,
  'rage-click': false
};

/**
 * Behavior labels for UI display
 * @type {Object}
 */
const BEHAVIOR_LABELS = {
  'exit-intent': 'Exit intent',
  'scroll-depth': 'Scroll depth',
  'time-delay': 'Idle 10s',
  'rage-click': 'Rage click',
  'pageview': 'Pageview increment'
};

/**
 * Default behavior message
 * @type {string}
 */
const DEFAULT_BEHAVIOR_MESSAGE = 'Perform a behavior in the stage or click a button to simulate it.';

/**
 * Presentation controller settings
 * @type {Object}
 */
const PRESENTATION_SETTINGS = {
  /** Manual lock duration in milliseconds */
  MANUAL_LOCK_MS: 4000,
  
  /** Auto cooldown duration in milliseconds */
  AUTO_COOLDOWN_MS: 10000
};

/**
 * Get all constants as a single object
 * @returns {Object} All constants combined
 */
function getAllConstants() {
  return {
    behavior: BEHAVIOR_CONSTANTS,
    ui: UI_CONSTANTS,
    behaviorListeners: BEHAVIOR_LISTENER_DEFAULTS,
    behaviorLabels: BEHAVIOR_LABELS,
    defaultBehaviorMessage: DEFAULT_BEHAVIOR_MESSAGE,
    presentation: PRESENTATION_SETTINGS
  };
}

module.exports = {
  BEHAVIOR_CONSTANTS,
  UI_CONSTANTS,
  BEHAVIOR_LISTENER_DEFAULTS,
  BEHAVIOR_LABELS,
  DEFAULT_BEHAVIOR_MESSAGE,
  PRESENTATION_SETTINGS,
  getAllConstants
};
