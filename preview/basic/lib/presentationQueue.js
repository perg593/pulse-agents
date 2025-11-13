/**
 * @fileoverview Presentation Queue Manager
 * 
 * Centralized queue manager for survey presentations with deduplication,
 * priority handling, and locking to prevent race conditions.
 */

const { log } = require('../../../lib/logger');

/**
 * Priority levels for presentation requests
 * @enum {string}
 */
const PRIORITY = {
  MANUAL: 'manual',
  AUTO: 'auto'
};

/**
 * Presentation queue entry
 * @typedef {Object} QueueEntry
 * @property {string} surveyId - Survey ID to present
 * @property {PRIORITY} priority - Priority level
 * @property {Object} options - Presentation options
 * @property {string} source - Source of the request
 * @property {number} timestamp - When the request was queued
 * @property {Function} resolve - Promise resolve function
 * @property {Function} reject - Promise reject function
 */

/**
 * Presentation Queue Manager
 * 
 * Manages survey presentation requests with:
 * - Queue ordering by priority (manual > auto)
 * - Deduplication by surveyId within a time window
 * - Lock mechanism to prevent concurrent presentations
 * - Event emission for presentation lifecycle
 */
class PresentationQueue {
  /**
   * Create a new PresentationQueue
   * @param {Object} options - Configuration options
   * @param {number} options.deduplicationWindowMs - Time window for deduplication (default: 2000ms)
   * @param {number} options.maxQueueSize - Maximum queue size (default: 50)
   */
  constructor(options = {}) {
    this.deduplicationWindowMs = options.deduplicationWindowMs || 2000;
    this.maxQueueSize = options.maxQueueSize || 50;
    
    /** @type {QueueEntry[]} */
    this.queue = [];
    
    /** @type {Map<string, number>} */
    this.presentedSurveys = new Map(); // surveyId -> timestamp
    
    /** @type {boolean} */
    this.locked = false;
    
    /** @type {string|null} */
    this.currentSurveyId = null;
    
    /** @type {EventTarget} */
    this.eventTarget = new EventTarget();
  }

  /**
   * Add a presentation request to the queue
   * @param {string} surveyId - Survey ID to present
   * @param {Object} options - Presentation options
   * @param {PRIORITY} [options.priority=PRIORITY.AUTO] - Priority level
   * @param {string} [options.source='unknown'] - Source of the request
   * @param {boolean} [options.force=false] - Force presentation even if duplicate
   * @param {boolean} [options.allowDuplicate=false] - Allow duplicate presentations
   * @returns {Promise<void>} Promise that resolves when presentation is processed
   */
  async enqueue(surveyId, options = {}) {
    if (!surveyId || typeof surveyId !== 'string') {
      throw new Error('surveyId is required and must be a string');
    }

    const {
      priority = PRIORITY.AUTO,
      source = 'unknown',
      force = false,
      allowDuplicate = false
    } = options;

    // Check for duplicates if not forced and duplicates not allowed
    if (!force && !allowDuplicate) {
      const isDuplicate = this.isDuplicate(surveyId);
      if (isDuplicate) {
        log.debug('Presentation request rejected: duplicate', {
          surveyId,
          source,
          priority,
          lastPresented: this.presentedSurveys.get(surveyId)
        });
        this.emit('rejected', { surveyId, reason: 'duplicate', source });
        return Promise.resolve();
      }
    }

    // Check queue size
    if (this.queue.length >= this.maxQueueSize) {
      log.warn('Presentation queue is full, rejecting request', {
        surveyId,
        source,
        queueSize: this.queue.length
      });
      this.emit('rejected', { surveyId, reason: 'queue_full', source });
      return Promise.reject(new Error('Presentation queue is full'));
    }

    return new Promise((resolve, reject) => {
      const entry = {
        surveyId,
        priority,
        options: { ...options, force, allowDuplicate },
        source,
        timestamp: Date.now(),
        resolve,
        reject
      };

      // Optimized priority insertion - manual items go to front, auto to back
      // This avoids expensive findIndex operations for common case
      if (priority === PRIORITY.MANUAL) {
        // Manual priority - insert at front for immediate processing
        this.queue.unshift(entry);
      } else {
        // Auto priority - add to end
        this.queue.push(entry);
      }

      log.debug('Presentation request queued', {
        surveyId,
        source,
        priority,
        queuePosition: this.queue.length,
        queueSize: this.queue.length
      });

      this.emit('queued', { surveyId, source, priority, queuePosition: this.queue.length });

      // Process queue if not locked (optimized - check lock before async operation)
      if (!this.locked && this.queue.length === 1) {
        // Only start processing if this is the first item (avoids unnecessary calls)
        this.process();
      } else if (!this.locked) {
        // Queue already has items, processing will continue automatically
        this.process();
      }
    });
  }

  /**
   * Check if a survey ID is a duplicate within the deduplication window
   * @param {string} surveyId - Survey ID to check
   * @returns {boolean} True if duplicate
   */
  isDuplicate(surveyId) {
    const lastPresented = this.presentedSurveys.get(surveyId);
    if (!lastPresented) {
      return false;
    }

    const timeSinceLastPresent = Date.now() - lastPresented;
    return timeSinceLastPresent < this.deduplicationWindowMs;
  }

  /**
   * Process the next item in the queue
   * Optimized to reduce lock contention and improve throughput
   * @private
   */
  async process() {
    if (this.locked || this.queue.length === 0) {
      return;
    }

    // Get next entry (first in queue) - optimized priority sorting
    // Manual priority items are already at front due to enqueue logic
    const entry = this.queue.shift();
    if (!entry) {
      return;
    }

    // Lock the queue
    this.locked = true;
    this.currentSurveyId = entry.surveyId;

    log.debug('Processing presentation request', {
      surveyId: entry.surveyId,
      source: entry.source,
      priority: entry.priority,
      queueRemaining: this.queue.length
    });

    this.emit('processing', {
      surveyId: entry.surveyId,
      source: entry.source,
      priority: entry.priority
    });

    try {
      // Mark as presented
      this.presentedSurveys.set(entry.surveyId, Date.now());

      // Clean up old entries from presentedSurveys map (optimized - only when needed)
      if (this.presentedSurveys.size > 10) {
        this.cleanupPresentedSurveys();
      }

      // Resolve the promise (caller should handle actual presentation)
      entry.resolve({
        surveyId: entry.surveyId,
        options: entry.options,
        source: entry.source
      });

      this.emit('processed', {
        surveyId: entry.surveyId,
        source: entry.source,
        priority: entry.priority
      });
    } catch (error) {
      log.error('Error processing presentation request', error, {
        surveyId: entry.surveyId,
        source: entry.source
      });
      entry.reject(error);
      this.emit('error', {
        surveyId: entry.surveyId,
        source: entry.source,
        error: error.message
      });
    } finally {
      // Unlock immediately to reduce lock contention
      this.locked = false;
      this.currentSurveyId = null;

      // Process next item if available (optimized - use microtask for better performance)
      if (this.queue.length > 0) {
        // Use Promise.resolve().then() for microtask scheduling (faster than setTimeout)
        Promise.resolve().then(() => this.process());
      }
    }
  }

  /**
   * Clean up old entries from presentedSurveys map
   * @private
   */
  cleanupPresentedSurveys() {
    const now = Date.now();
    const cutoff = now - this.deduplicationWindowMs * 2; // Keep entries for 2x window

    for (const [surveyId, timestamp] of this.presentedSurveys.entries()) {
      if (timestamp < cutoff) {
        this.presentedSurveys.delete(surveyId);
      }
    }
  }

  /**
   * Cancel a queued presentation request
   * @param {string} surveyId - Survey ID to cancel
   * @returns {boolean} True if cancelled, false if not found
   */
  cancel(surveyId) {
    const index = this.queue.findIndex(entry => entry.surveyId === surveyId);
    if (index >= 0) {
      const entry = this.queue.splice(index, 1)[0];
      entry.reject(new Error('Presentation request cancelled'));
      log.debug('Presentation request cancelled', { surveyId, source: entry.source });
      this.emit('cancelled', { surveyId, source: entry.source });
      return true;
    }
    return false;
  }

  /**
   * Clear all queued requests
   */
  clear() {
    const count = this.queue.length;
    this.queue.forEach(entry => {
      entry.reject(new Error('Presentation queue cleared'));
    });
    this.queue = [];
    log.debug('Presentation queue cleared', { cancelledCount: count });
    this.emit('cleared', { cancelledCount: count });
  }

  /**
   * Get current queue state
   * @returns {Object} Queue state
   */
  getState() {
    return {
      queueSize: this.queue.length,
      locked: this.locked,
      currentSurveyId: this.currentSurveyId,
      queuedSurveys: this.queue.map(e => ({
        surveyId: e.surveyId,
        priority: e.priority,
        source: e.source,
        timestamp: e.timestamp
      }))
    };
  }

  /**
   * Emit an event
   * @private
   * @param {string} eventName - Event name
   * @param {Object} data - Event data
   */
  emit(eventName, data) {
    this.eventTarget.dispatchEvent(new CustomEvent(eventName, { detail: data }));
  }

  /**
   * Add event listener
   * @param {string} eventName - Event name
   * @param {Function} handler - Event handler
   */
  on(eventName, handler) {
    this.eventTarget.addEventListener(eventName, handler);
  }

  /**
   * Remove event listener
   * @param {string} eventName - Event name
   * @param {Function} handler - Event handler
   */
  off(eventName, handler) {
    this.eventTarget.removeEventListener(eventName, handler);
  }
}

module.exports = {
  PresentationQueue,
  PRIORITY
};

