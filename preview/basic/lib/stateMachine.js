/**
 * @fileoverview Generic State Machine
 * 
 * Generic state machine implementation with state definitions, transition guards,
 * actions on state entry/exit, and state history for debugging.
 */

const { log } = require('../../../lib/logger');

/**
 * State transition definition
 * @typedef {Object} Transition
 * @property {string} from - Source state
 * @property {string} to - Target state
 * @property {Function} [guard] - Guard function that must return true for transition
 * @property {Function} [action] - Action function to execute on transition
 */

/**
 * State definition
 * @typedef {Object} StateDef
 * @property {string} name - State name
 * @property {Function} [onEnter] - Function called when entering state
 * @property {Function} [onExit] - Function called when exiting state
 */

/**
 * State Machine
 * 
 * Generic state machine with:
 * - State definitions with allowed transitions
 * - Guard conditions for transitions
 * - Actions on state entry/exit
 * - State history and debugging
 */
class StateMachine {
  /**
   * Create a new StateMachine
   * @param {Object} options - Configuration options
   * @param {string} options.initialState - Initial state name
   * @param {StateDef[]} options.states - State definitions
   * @param {Transition[]} options.transitions - Transition definitions
   * @param {boolean} options.enableHistory - Whether to maintain state history (default: true)
   * @param {number} options.maxHistorySize - Maximum state history size (default: 100)
   */
  constructor(options = {}) {
    const {
      initialState,
      states = [],
      transitions = [],
      enableHistory = true,
      maxHistorySize = 100
    } = options;

    if (!initialState) {
      throw new Error('Initial state is required');
    }

    this.initialState = initialState;
    this.currentState = initialState;
    this.enableHistory = enableHistory;
    this.maxHistorySize = maxHistorySize;

    /** @type {Map<string, StateDef>} */
    this.states = new Map();

    /** @type {Map<string, Transition[]>} */
    this.transitions = new Map();

    /** @type {Array<{state: string, timestamp: number, context: Object}>} */
    this.history = [];

    // Initialize states
    states.forEach(stateDef => {
      this.states.set(stateDef.name, stateDef);
    });

    // Initialize transitions
    transitions.forEach(transition => {
      const from = transition.from;
      if (!this.transitions.has(from)) {
        this.transitions.set(from, []);
      }
      this.transitions.get(from).push(transition);
    });

    // Record initial state
    if (this.enableHistory) {
      this.history.push({
        state: this.currentState,
        timestamp: Date.now(),
        context: {}
      });
    }

    log.debug('StateMachine created', {
      initialState,
      stateCount: this.states.size,
      transitionCount: transitions.length
    });
  }

  /**
   * Get current state
   * @returns {string} Current state name
   */
  getState() {
    return this.currentState;
  }

  /**
   * Check if a transition is allowed
   * @param {string} toState - Target state
   * @param {Object} [context] - Transition context
   * @returns {boolean} True if transition is allowed
   */
  canTransition(toState, context = {}) {
    const transitions = this.transitions.get(this.currentState);
    if (!transitions) {
      return false;
    }

    const transition = transitions.find(t => t.to === toState);
    if (!transition) {
      return false;
    }

    // Check guard if present
    if (transition.guard && typeof transition.guard === 'function') {
      try {
        return transition.guard(context) === true;
      } catch (error) {
        log.error('Error in transition guard', error, {
          from: this.currentState,
          to: toState
        });
        return false;
      }
    }

    return true;
  }

  /**
   * Transition to a new state
   * @param {string} toState - Target state
   * @param {Object} [context] - Transition context
   * @returns {boolean} True if transition succeeded
   */
  transition(toState, context = {}) {
    if (!this.canTransition(toState, context)) {
      log.warn('Transition not allowed', {
        from: this.currentState,
        to: toState,
        context
      });
      return false;
    }

    const fromState = this.currentState;
    const transitions = this.transitions.get(fromState);
    const transition = transitions.find(t => t.to === toState);

    // Execute exit action for current state
    const currentStateDef = this.states.get(fromState);
    if (currentStateDef && currentStateDef.onExit) {
      try {
        currentStateDef.onExit(context);
      } catch (error) {
        log.error('Error in state exit action', error, { state: fromState });
      }
    }

    // Execute transition action if present
    if (transition && transition.action) {
      try {
        transition.action(context);
      } catch (error) {
        log.error('Error in transition action', error, {
          from: fromState,
          to: toState
        });
      }
    }

    // Change state
    this.currentState = toState;

    // Execute enter action for new state
    const newStateDef = this.states.get(toState);
    if (newStateDef && newStateDef.onEnter) {
      try {
        newStateDef.onEnter(context);
      } catch (error) {
        log.error('Error in state enter action', error, { state: toState });
      }
    }

    // Record in history
    if (this.enableHistory) {
      this.history.push({
        state: toState,
        timestamp: Date.now(),
        context: { ...context, from: fromState }
      });

      if (this.history.length > this.maxHistorySize) {
        this.history.shift();
      }
    }

    log.debug('State transitioned', {
      from: fromState,
      to: toState,
      context
    });

    return true;
  }

  /**
   * Reset to initial state
   * @param {Object} [context] - Reset context
   */
  reset(context = {}) {
    const fromState = this.currentState;

    // Execute exit action
    const currentStateDef = this.states.get(fromState);
    if (currentStateDef && currentStateDef.onExit) {
      try {
        currentStateDef.onExit(context);
      } catch (error) {
        log.error('Error in state exit action during reset', error, { state: fromState });
      }
    }

    // Reset to initial state
    this.currentState = this.initialState;

    // Execute enter action
    const initialStateDef = this.states.get(this.initialState);
    if (initialStateDef && initialStateDef.onEnter) {
      try {
        initialStateDef.onEnter(context);
      } catch (error) {
        log.error('Error in state enter action during reset', error, { state: this.initialState });
      }
    }

    // Record in history
    if (this.enableHistory) {
      this.history.push({
        state: this.initialState,
        timestamp: Date.now(),
        context: { ...context, reset: true, from: fromState }
      });
    }

    log.debug('StateMachine reset', { from: fromState, to: this.initialState });
  }

  /**
   * Get state history
   * @param {number} [limit] - Limit number of results
   * @returns {Array} State history
   */
  getHistory(limit = null) {
    let history = this.history;

    if (limit) {
      history = history.slice(-limit);
    }

    return history;
  }

  /**
   * Clear state history
   */
  clearHistory() {
    const count = this.history.length;
    this.history = [];
    log.debug('State history cleared', { clearedCount: count });
  }

  /**
   * Get available transitions from current state
   * @param {Object} [context] - Transition context
   * @returns {string[]} Available target states
   */
  getAvailableTransitions(context = {}) {
    const transitions = this.transitions.get(this.currentState);
    if (!transitions) {
      return [];
    }

    return transitions
      .filter(transition => {
        if (transition.guard && typeof transition.guard === 'function') {
          try {
            return transition.guard(context) === true;
          } catch (error) {
            log.error('Error in transition guard', error, {
              from: this.currentState,
              to: transition.to
            });
            return false;
          }
        }
        return true;
      })
      .map(transition => transition.to);
  }
}

module.exports = {
  StateMachine
};

