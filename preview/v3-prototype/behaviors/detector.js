const IDLE_TIMEOUT_MS = 10000;
const SCROLL_THRESHOLD = 0.6;
const SCROLL_RESET_THRESHOLD = 0.2;
const RAGE_WINDOW_MS = 600;
const RAGE_THRESHOLD = 4;
const RAGE_RADIUS = 36;
const COOLDOWN_MS = 3000;

/**
 * Attach lightweight behaviour detectors to the stage surface so the preview can react
 * when an operator performs the gestures manually (scroll, exit intent, idle, rage click).
 *
 * @param {Object} options
 * @param {HTMLElement} options.stage - Scrollable container that mimics a product page.
 * @param {(id: string, meta?: Record<string, unknown>) => void} [options.onTrigger] - Fired when a behaviour crosses its threshold.
 * @param {(state: string) => void} [options.onActivity] - Called on any user movement (for UI feedback).
 * @returns {() => void} cleanup function to remove listeners.
 */
export function initBehaviorDetectors({ stage, onTrigger, onActivity } = {}) {
  if (!stage) return () => {};

  const state = {
    idleTimer: null,
    scrollArmed: true,
    clickPoints: [],
    cooldown: new Map()
  };

  const teardown = [];

  const add = (target, type, handler, options) => {
    target.addEventListener(type, handler, options);
    teardown.push(() => {
      try {
        target.removeEventListener(type, handler, options);
      } catch (_error) {
        /* ignore */
      }
    });
  };

  const trigger = (id, meta = {}) => {
    if (!id) return;
    const now = Date.now();
    const last = state.cooldown.get(id) || 0;
    if (now - last < COOLDOWN_MS) return;
    state.cooldown.set(id, now);
    if (typeof onTrigger === 'function') {
      onTrigger(id, meta);
    }
  };

  const resetIdleTimer = () => {
    window.clearTimeout(state.idleTimer);
    state.idleTimer = window.setTimeout(() => {
      state.idleTimer = null;
      trigger('idle_10s');
    }, IDLE_TIMEOUT_MS);
  };

  const handleActivity = () => {
    resetIdleTimer();
    if (typeof onActivity === 'function') {
      onActivity('activity');
    }
  };

  const handlePointerLeave = (event) => {
    if (stage.contains(event.relatedTarget)) return;
    if (event.pointerType && event.pointerType !== 'mouse') return;
    const rect = stage.getBoundingClientRect();
    if (event.clientY <= rect.top + 2) {
      trigger('exit_intent');
    }
  };

  const handleScroll = () => {
    handleActivity();
    const maxScroll = stage.scrollHeight - stage.clientHeight;
    if (maxScroll <= 0) return;
    const percent = stage.scrollTop / maxScroll;
    if (state.scrollArmed && percent >= SCROLL_THRESHOLD) {
      trigger('scroll_60', { percent: percent * 100 });
      state.scrollArmed = false;
    } else if (!state.scrollArmed && percent <= SCROLL_RESET_THRESHOLD) {
      state.scrollArmed = true;
    }
  };

  const handleClick = (event) => {
    handleActivity();
    const now = Date.now();
    const { clientX: x, clientY: y } = event;
    state.clickPoints = state.clickPoints.filter((entry) => now - entry.time <= RAGE_WINDOW_MS);
    state.clickPoints.push({ time: now, x, y });
    const cluster = state.clickPoints.filter(
      (entry) => Math.hypot(entry.x - x, entry.y - y) <= RAGE_RADIUS
    );
    if (cluster.length >= RAGE_THRESHOLD) {
      trigger('rage_click');
      state.clickPoints = [];
    }
  };

  const handleKeydown = () => {
    handleActivity();
  };

  add(stage, 'pointermove', handleActivity, { passive: true });
  add(stage, 'pointerdown', handleActivity);
  add(stage, 'pointerenter', handleActivity);
  add(stage, 'pointerleave', handlePointerLeave);
  add(stage, 'scroll', handleScroll, { passive: true });
  add(stage, 'click', handleClick);
  add(stage, 'keydown', handleKeydown);

  resetIdleTimer();

  teardown.push(() => {
    window.clearTimeout(state.idleTimer);
    state.clickPoints = [];
  });

  return () => {
    teardown.forEach((fn) => {
      try {
        fn();
      } catch (_error) {
        /* ignore */
      }
    });
  };
}
