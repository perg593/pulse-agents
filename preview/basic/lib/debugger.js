/**
 * @fileoverview Debugging Utilities
 * 
 * Provides debugging utilities for presentation issues including state inspection,
 * event history viewing, and presentation timeline viewing.
 */

const { log } = require('../../lib/logger');
const { getEventBus } = require('./eventBus');
const { getPerformanceMonitor } = require('./performanceMonitor');

/**
 * Debugger
 * 
 * Provides debugging utilities for the preview system.
 */
class Debugger {
  /**
   * Create a new Debugger
   */
  constructor() {
    this.eventBus = getEventBus();
    this.performanceMonitor = getPerformanceMonitor();
  }

  /**
   * Get current system state
   * @returns {Object} System state
   */
  getState() {
    return {
      timestamp: Date.now(),
      eventHistory: this.eventBus.getHistory(50),
      performanceStats: this.performanceMonitor.getStats(),
      errorRates: this.performanceMonitor.getErrorRates()
    };
  }

  /**
   * Get event history
   * @param {string} [type] - Filter by event type
   * @param {number} [limit] - Limit number of results
   * @returns {Array} Event history
   */
  getEventHistory(type = null, limit = 50) {
    return this.eventBus.getHistory(type, limit);
  }

  /**
   * Get presentation timeline
   * @param {string} surveyId - Survey ID
   * @returns {Array} Timeline events
   */
  getPresentationTimeline(surveyId) {
    const events = this.eventBus.getHistory(null, null);
    return events
      .filter(e => e.data.surveyId === surveyId)
      .map(e => ({
        type: e.type,
        timestamp: e.timestamp,
        source: e.source,
        data: e.data
      }));
  }

  /**
   * Get performance metrics
   * @param {string} [operation] - Filter by operation
   * @param {number} [timeWindowMs] - Time window in milliseconds
   * @returns {Object} Performance metrics
   */
  getPerformanceMetrics(operation = null, timeWindowMs = 60000) {
    return this.performanceMonitor.getStats(operation, timeWindowMs);
  }

  /**
   * Export debug information
   * @returns {Object} Debug information
   */
  exportDebugInfo() {
    return {
      timestamp: Date.now(),
      state: this.getState(),
      eventHistory: this.getEventHistory(null, 100),
      performanceMetrics: this.getPerformanceMetrics(),
      errorRates: this.performanceMonitor.getErrorRates()
    };
  }

  /**
   * Log debug information to console
   */
  logDebugInfo() {
    const info = this.exportDebugInfo();
    console.group('🔍 Preview System Debug Info');
    console.log('State:', info.state);
    console.log('Recent Events:', info.eventHistory.slice(-10));
    console.log('Performance:', info.performanceMetrics);
    console.log('Error Rates:', info.errorRates);
    console.groupEnd();
  }
}

// Create singleton instance
let instance = null;

/**
 * Get the singleton Debugger instance
 * @returns {Debugger} Debugger instance
 */
function getDebugger() {
  if (!instance) {
    instance = new Debugger();
  }
  return instance;
}

// Expose to window for console access
if (typeof window !== 'undefined') {
  window.__PI_DEBUGGER__ = getDebugger();
}

module.exports = {
  Debugger,
  getDebugger
};

