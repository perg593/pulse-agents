/**
 * @fileoverview Presentation Deduplicator
 * 
 * Centralized duplicate detection service for survey presentations with
 * time-windowed deduplication, source-aware handling, and force flag support.
 */

const { log } = require('../../lib/logger');

/**
 * Presentation source types
 * @enum {string}
 */
const SOURCE = {
  MANUAL: 'manual',
  AUTO: 'auto',
  URL_PARAM: 'url_param',
  BEHAVIOR: 'behavior',
  UNKNOWN: 'unknown'
};

/**
 * Deduplication result
 * @typedef {Object} DeduplicationResult
 * @property {boolean} isDuplicate - Whether the request is a duplicate
 * @property {string|null} reason - Reason for duplicate detection (if duplicate)
 * @property {number|null} lastPresentedAt - Timestamp of last presentation (if duplicate)
 */

/**
 * Presentation Deduplicator
 * 
 * Provides centralized duplicate detection with:
 * - Time-windowed duplicate detection (configurable cooldown)
 * - Source-aware deduplication (different sources can override)
 * - Force flag support
 * - State persistence across page reloads (via sessionStorage)
 */
class PresentationDeduplicator {
  /**
   * Create a new PresentationDeduplicator
   * @param {Object} options - Configuration options
   * @param {number} options.cooldownMs - Cooldown period in milliseconds (default: 10000ms)
   * @param {boolean} options.persistState - Whether to persist state in sessionStorage (default: true)
   * @param {string} options.storageKey - SessionStorage key (default: 'pi_presentation_history')
   */
  constructor(options = {}) {
    this.cooldownMs = options.cooldownMs || 10000;
    this.persistState = options.persistState !== false;
    this.storageKey = options.storageKey || 'pi_presentation_history';

    /** @type {Map<string, {timestamp: number, source: string}>} */
    this.presentationHistory = new Map();

    // Load persisted state
    if (this.persistState && typeof window !== 'undefined' && window.sessionStorage) {
      this.loadState();
    }
  }

  /**
   * Check if a presentation request is a duplicate
   * @param {string} surveyId - Survey ID to check
   * @param {Object} options - Deduplication options
   * @param {SOURCE} [options.source=SOURCE.UNKNOWN] - Source of the request
   * @param {boolean} [options.force=false] - Force presentation even if duplicate
   * @param {boolean} [options.allowDuplicate=false] - Allow duplicate presentations
   * @returns {DeduplicationResult} Deduplication result
   */
  checkDuplicate(surveyId, options = {}) {
    if (!surveyId || typeof surveyId !== 'string') {
      throw new Error('surveyId is required and must be a string');
    }

    const {
      source = SOURCE.UNKNOWN,
      force = false,
      allowDuplicate = false
    } = options;

    // Force flag bypasses deduplication
    if (force) {
      log.debug('Deduplication bypassed: force flag', { surveyId, source });
      return {
        isDuplicate: false,
        reason: null,
        lastPresentedAt: null
      };
    }

    // Allow duplicate flag bypasses deduplication
    if (allowDuplicate) {
      log.debug('Deduplication bypassed: allowDuplicate flag', { surveyId, source });
      return {
        isDuplicate: false,
        reason: null,
        lastPresentedAt: null
      };
    }

    // Check history
    const historyEntry = this.presentationHistory.get(surveyId);
    if (!historyEntry) {
      // Not in history, not a duplicate
      return {
        isDuplicate: false,
        reason: null,
        lastPresentedAt: null
      };
    }

    const timeSinceLastPresent = Date.now() - historyEntry.timestamp;

    // Check if within cooldown window
    if (timeSinceLastPresent < this.cooldownMs) {
      // Source-aware deduplication: manual can override auto, but not vice versa
      const canOverride = this.canSourceOverride(source, historyEntry.source);

      if (!canOverride) {
        log.debug('Duplicate detected', {
          surveyId,
          source,
          lastSource: historyEntry.source,
          timeSinceLastPresent,
          cooldownMs: this.cooldownMs
        });

        return {
          isDuplicate: true,
          reason: `presented ${Math.round(timeSinceLastPresent / 1000)}s ago`,
          lastPresentedAt: historyEntry.timestamp
        };
      } else {
        log.debug('Duplicate detected but source can override', {
          surveyId,
          source,
          lastSource: historyEntry.source,
          timeSinceLastPresent
        });
        // Source can override, not a duplicate
        return {
          isDuplicate: false,
          reason: null,
          lastPresentedAt: historyEntry.timestamp
        };
      }
    }

    // Outside cooldown window, not a duplicate
    return {
      isDuplicate: false,
      reason: null,
      lastPresentedAt: historyEntry.timestamp
    };
  }

  /**
   * Check if a source can override another source
   * @private
   * @param {SOURCE} newSource - New source
   * @param {SOURCE} existingSource - Existing source
   * @returns {boolean} True if new source can override
   */
  canSourceOverride(newSource, existingSource) {
    // Manual can always override
    if (newSource === SOURCE.MANUAL) {
      return true;
    }

    // URL param can override auto and behavior
    if (newSource === SOURCE.URL_PARAM) {
      return existingSource === SOURCE.AUTO || existingSource === SOURCE.BEHAVIOR;
    }

    // Behavior can override auto
    if (newSource === SOURCE.BEHAVIOR) {
      return existingSource === SOURCE.AUTO;
    }

    // Auto cannot override anything
    return false;
  }

  /**
   * Record a presentation
   * @param {string} surveyId - Survey ID that was presented
   * @param {SOURCE} [source=SOURCE.UNKNOWN] - Source of the presentation
   */
  recordPresentation(surveyId, source = SOURCE.UNKNOWN) {
    if (!surveyId || typeof surveyId !== 'string') {
      return;
    }

    this.presentationHistory.set(surveyId, {
      timestamp: Date.now(),
      source
    });

    // Cleanup old entries immediately to reduce memory footprint
    this.cleanupAfterRecord();

    // Persist state
    if (this.persistState) {
      this.saveState();
    }

    log.debug('Presentation recorded', { surveyId, source });
  }

  /**
   * Clear presentation history for a specific survey
   * @param {string} surveyId - Survey ID to clear
   */
  clearSurvey(surveyId) {
    if (this.presentationHistory.delete(surveyId)) {
      if (this.persistState) {
        this.saveState();
      }
      log.debug('Presentation history cleared for survey', { surveyId });
    }
  }

  /**
   * Clear all presentation history
   */
  clearAll() {
    const count = this.presentationHistory.size;
    this.presentationHistory.clear();
    if (this.persistState) {
      this.saveState();
    }
    log.debug('All presentation history cleared', { clearedCount: count });
  }

  /**
   * Get presentation history for a survey
   * @param {string} surveyId - Survey ID
   * @returns {Object|null} History entry or null
   */
  getHistory(surveyId) {
    return this.presentationHistory.get(surveyId) || null;
  }

  /**
   * Get all presentation history
   * @returns {Object} All history entries
   */
  getAllHistory() {
    const result = {};
    for (const [surveyId, entry] of this.presentationHistory.entries()) {
      result[surveyId] = { ...entry };
    }
    return result;
  }

  /**
   * Clean up old entries (older than 2x cooldown)
   * More aggressive cleanup - called on every operation
   * @private
   */
  cleanup() {
    const cutoff = Date.now() - (this.cooldownMs * 2);
    let cleaned = 0;

    for (const [surveyId, entry] of this.presentationHistory.entries()) {
      if (entry.timestamp < cutoff) {
        this.presentationHistory.delete(surveyId);
        cleaned++;
      }
    }

    if (cleaned > 0) {
      if (this.persistState) {
        this.saveState();
      }
      log.debug('Cleaned up old presentation history entries', { cleaned });
    }
  }

  /**
   * Clean up old entries immediately after recording presentation
   * More aggressive cleanup to reduce memory footprint
   * @private
   */
  cleanupAfterRecord() {
    // Cleanup immediately after recording to keep memory footprint small
    this.cleanup();
  }

  /**
   * Save state to sessionStorage
   * @private
   */
  saveState() {
    if (typeof window === 'undefined' || !window.sessionStorage) {
      return;
    }

    try {
      const data = Array.from(this.presentationHistory.entries()).map(([surveyId, entry]) => ({
        surveyId,
        timestamp: entry.timestamp,
        source: entry.source
      }));

      window.sessionStorage.setItem(this.storageKey, JSON.stringify(data));
    } catch (error) {
      log.warn('Failed to save presentation history to sessionStorage', error);
    }
  }

  /**
   * Load state from sessionStorage
   * @private
   */
  loadState() {
    if (typeof window === 'undefined' || !window.sessionStorage) {
      return;
    }

    try {
      const data = window.sessionStorage.getItem(this.storageKey);
      if (!data) {
        return;
      }

      const entries = JSON.parse(data);
      const now = Date.now();
      const cutoff = now - (this.cooldownMs * 2);

      for (const entry of entries) {
        // Only load entries that are still within the cleanup window
        if (entry.timestamp >= cutoff) {
          this.presentationHistory.set(entry.surveyId, {
            timestamp: entry.timestamp,
            source: entry.source || SOURCE.UNKNOWN
          });
        }
      }

      log.debug('Loaded presentation history from sessionStorage', {
        loadedCount: this.presentationHistory.size
      });
    } catch (error) {
      log.warn('Failed to load presentation history from sessionStorage', error);
    }
  }
}

module.exports = {
  PresentationDeduplicator,
  SOURCE
};

