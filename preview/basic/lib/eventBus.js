/**
 * @fileoverview Event Bus
 * 
 * Centralized event bus for component communication with type-safe event emission,
 * event filtering, event history, and subscriber management.
 */

const { log } = require('../../lib/logger');

/**
 * Event bus entry
 * @typedef {Object} EventEntry
 * @property {string} type - Event type
 * @property {Object} data - Event data
 * @property {number} timestamp - Event timestamp
 * @property {string} source - Event source
 */

/**
 * Event Bus
 * 
 * Provides centralized event management with:
 * - Type-safe event emission
 * - Event filtering and routing
 * - Event history for debugging
 * - Subscriber management
 */
class EventBus {
  /**
   * Create a new EventBus
   * @param {Object} options - Configuration options
   * @param {number} options.maxHistorySize - Maximum event history size (default: 100)
   * @param {boolean} options.enableHistory - Whether to maintain event history (default: true)
   */
  constructor(options = {}) {
    this.maxHistorySize = options.maxHistorySize || 100;
    this.enableHistory = options.enableHistory !== false;

    /** @type {Map<string, Set<Function>>} */
    this.subscribers = new Map();

    /** @type {EventEntry[]} */
    this.history = [];

    /** @type {EventTarget} */
    this.eventTarget = typeof EventTarget !== 'undefined' ? new EventTarget() : null;

    // Fallback for environments without EventTarget
    if (!this.eventTarget) {
      this.eventTarget = {
        listeners: new Map(),
        addEventListener: (type, handler) => {
          if (!this.eventTarget.listeners.has(type)) {
            this.eventTarget.listeners.set(type, new Set());
          }
          this.eventTarget.listeners.get(type).add(handler);
        },
        removeEventListener: (type, handler) => {
          const listeners = this.eventTarget.listeners.get(type);
          if (listeners) {
            listeners.delete(handler);
          }
        },
        dispatchEvent: (event) => {
          const listeners = this.eventTarget.listeners.get(event.type);
          if (listeners) {
            listeners.forEach(handler => {
              try {
                handler(event);
              } catch (error) {
                log.error('Error in event handler', error, { eventType: event.type });
              }
            });
          }
          return true;
        }
      };
    }
  }

  /**
   * Emit an event
   * @param {string} type - Event type
   * @param {Object} data - Event data
   * @param {string} [source='unknown'] - Event source
   */
  emit(type, data = {}, source = 'unknown') {
    if (!type || typeof type !== 'string') {
      log.warn('Invalid event type', { type });
      return;
    }

    const entry = {
      type,
      data,
      timestamp: Date.now(),
      source
    };

    // Add to history
    if (this.enableHistory) {
      this.history.push(entry);
      if (this.history.length > this.maxHistorySize) {
        this.history.shift();
      }
    }

    // Emit via EventTarget
    const event = typeof CustomEvent !== 'undefined'
      ? new CustomEvent(type, { detail: data })
      : { type, detail: data, preventDefault: () => {}, stopPropagation: () => {} };

    this.eventTarget.dispatchEvent(event);

    // Also call direct subscribers
    const subscribers = this.subscribers.get(type);
    if (subscribers) {
      subscribers.forEach(handler => {
        try {
          handler(data, entry);
        } catch (error) {
          log.error('Error in event subscriber', error, { eventType: type, source });
        }
      });
    }

    log.debug('Event emitted', { type, source, dataKeys: Object.keys(data) });
  }

  /**
   * Subscribe to an event
   * @param {string} type - Event type
   * @param {Function} handler - Event handler function
   * @returns {Function} Unsubscribe function
   */
  on(type, handler) {
    if (!type || typeof type !== 'string') {
      throw new Error('Event type must be a string');
    }
    if (typeof handler !== 'function') {
      throw new Error('Handler must be a function');
    }

    // Add to subscribers map
    if (!this.subscribers.has(type)) {
      this.subscribers.set(type, new Set());
    }
    this.subscribers.get(type).add(handler);

    // Also add to EventTarget
    this.eventTarget.addEventListener(type, (event) => {
      handler(event.detail || {}, {
        type: event.type,
        timestamp: Date.now(),
        source: 'eventtarget'
      });
    });

    log.debug('Event subscriber added', { type });

    // Return unsubscribe function
    return () => this.off(type, handler);
  }

  /**
   * Unsubscribe from an event
   * @param {string} type - Event type
   * @param {Function} handler - Event handler function
   */
  off(type, handler) {
    const subscribers = this.subscribers.get(type);
    if (subscribers) {
      subscribers.delete(handler);
      if (subscribers.size === 0) {
        this.subscribers.delete(type);
      }
    }

    // Also remove from EventTarget
    this.eventTarget.removeEventListener(type, handler);

    log.debug('Event subscriber removed', { type });
  }

  /**
   * Subscribe to an event once (auto-unsubscribe after first call)
   * @param {string} type - Event type
   * @param {Function} handler - Event handler function
   * @returns {Function} Unsubscribe function
   */
  once(type, handler) {
    const wrappedHandler = (data, entry) => {
      handler(data, entry);
      this.off(type, wrappedHandler);
    };
    return this.on(type, wrappedHandler);
  }

  /**
   * Get event history
   * @param {string} [type] - Filter by event type
   * @param {number} [limit] - Limit number of results
   * @returns {EventEntry[]} Event history
   */
  getHistory(type = null, limit = null) {
    let history = this.history;

    if (type) {
      history = history.filter(entry => entry.type === type);
    }

    if (limit) {
      history = history.slice(-limit);
    }

    return history;
  }

  /**
   * Clear event history
   */
  clearHistory() {
    const count = this.history.length;
    this.history = [];
    log.debug('Event history cleared', { clearedCount: count });
  }

  /**
   * Get subscriber count for an event type
   * @param {string} type - Event type
   * @returns {number} Subscriber count
   */
  getSubscriberCount(type) {
    const subscribers = this.subscribers.get(type);
    return subscribers ? subscribers.size : 0;
  }

  /**
   * Get all subscribed event types
   * @returns {string[]} Event types
   */
  getSubscribedTypes() {
    return Array.from(this.subscribers.keys());
  }

  /**
   * Remove all subscribers for an event type
   * @param {string} type - Event type
   */
  removeAllListeners(type) {
    if (type) {
      this.subscribers.delete(type);
    } else {
      this.subscribers.clear();
    }
    log.debug('All listeners removed', { type: type || 'all' });
  }
}

// Create singleton instance
let instance = null;

/**
 * Get the singleton EventBus instance
 * @returns {EventBus} EventBus instance
 */
function getEventBus() {
  if (!instance) {
    instance = new EventBus();
  }
  return instance;
}

module.exports = {
  EventBus,
  getEventBus
};

