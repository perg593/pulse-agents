/**
 * @fileoverview Performance Monitor
 * 
 * Tracks performance metrics for presentation operations including latency,
 * success/failure rates, and error rates by type.
 */

const { log } = require('../../lib/logger');
const { getEventBus } = require('./eventBus');

/**
 * Performance metric entry
 * @typedef {Object} MetricEntry
 * @property {string} operation - Operation name
 * @property {number} duration - Duration in milliseconds
 * @property {boolean} success - Whether operation succeeded
 * @property {string|null} error - Error message if failed
 * @property {number} timestamp - Timestamp
 */

/**
 * Performance Monitor
 * 
 * Tracks and reports performance metrics for presentation operations.
 */
class PerformanceMonitor {
  /**
   * Create a new PerformanceMonitor
   * @param {Object} options - Configuration options
   * @param {number} options.maxMetrics - Maximum metrics to keep (default: 1000)
   * @param {boolean} options.enableLogging - Enable console logging (default: true)
   */
  constructor(options = {}) {
    this.maxMetrics = options.maxMetrics || 1000;
    this.enableLogging = options.enableLogging !== false;

    /** @type {MetricEntry[]} */
    this.metrics = [];

    /** @type {Map<string, number>} */
    this.counters = new Map();

    // Setup event listeners
    this.setupEventListeners();
  }

  /**
   * Setup event listeners for performance tracking
   * @private
   */
  setupEventListeners() {
    const eventBus = getEventBus();

    // Track presentation lifecycle
    eventBus.on('presentation:preparing', (data) => {
      this.startOperation('presentation', data.surveyId);
    });

    eventBus.on('presentation:presented', (data) => {
      this.endOperation('presentation', data.surveyId, true);
    });

    eventBus.on('presentation:failed', (data) => {
      this.endOperation('presentation', data.surveyId, false, data.error);
    });
  }

  /**
   * Start tracking an operation
   * @param {string} operation - Operation name
   * @param {string} [id] - Operation ID
   * @returns {string} Operation key
   */
  startOperation(operation, id = null) {
    const key = id ? `${operation}:${id}` : `${operation}:${Date.now()}`;
    const startTime = Date.now();

    if (!this.counters.has(key)) {
      this.counters.set(key, startTime);
    }

    if (this.enableLogging) {
      log.debug('Performance: operation started', { operation, id, key });
    }

    return key;
  }

  /**
   * End tracking an operation
   * @param {string} operation - Operation name
   * @param {string} [id] - Operation ID
   * @param {boolean} success - Whether operation succeeded
   * @param {string} [error] - Error message if failed
   */
  endOperation(operation, id = null, success = true, error = null) {
    const key = id ? `${operation}:${id}` : `${operation}:${Date.now()}`;
    const startTime = this.counters.get(key);

    if (!startTime) {
      log.warn('Performance: operation end without start', { operation, id, key });
      return;
    }

    const duration = Date.now() - startTime;
    this.counters.delete(key);

    const metric = {
      operation,
      duration,
      success,
      error: error || null,
      timestamp: Date.now()
    };

    this.metrics.push(metric);

    // Trim metrics if over limit
    if (this.metrics.length > this.maxMetrics) {
      this.metrics.shift();
    }

    // Emit metric event
    const eventBus = getEventBus();
    eventBus.emit('performance:metric', metric);

    if (this.enableLogging) {
      const level = success ? 'info' : 'warn';
      log[level]('Performance: operation completed', {
        operation,
        id,
        duration,
        success,
        error
      });
    }
  }

  /**
   * Get performance statistics
   * @param {string} [operation] - Filter by operation name
   * @param {number} [timeWindowMs] - Time window in milliseconds
   * @returns {Object} Performance statistics
   */
  getStats(operation = null, timeWindowMs = null) {
    let metrics = this.metrics;

    // Filter by operation
    if (operation) {
      metrics = metrics.filter(m => m.operation === operation);
    }

    // Filter by time window
    if (timeWindowMs) {
      const cutoff = Date.now() - timeWindowMs;
      metrics = metrics.filter(m => m.timestamp >= cutoff);
    }

    if (metrics.length === 0) {
      return {
        count: 0,
        successCount: 0,
        failureCount: 0,
        successRate: 0,
        averageDuration: 0,
        minDuration: 0,
        maxDuration: 0,
        p50Duration: 0,
        p95Duration: 0,
        p99Duration: 0
      };
    }

    const successCount = metrics.filter(m => m.success).length;
    const failureCount = metrics.length - successCount;
    const durations = metrics.map(m => m.duration).sort((a, b) => a - b);

    return {
      count: metrics.length,
      successCount,
      failureCount,
      successRate: successCount / metrics.length,
      averageDuration: durations.reduce((a, b) => a + b, 0) / durations.length,
      minDuration: durations[0],
      maxDuration: durations[durations.length - 1],
      p50Duration: durations[Math.floor(durations.length * 0.5)],
      p95Duration: durations[Math.floor(durations.length * 0.95)],
      p99Duration: durations[Math.floor(durations.length * 0.99)]
    };
  }

  /**
   * Get error rates by type
   * @param {number} [timeWindowMs] - Time window in milliseconds
   * @returns {Object} Error rates by error type
   */
  getErrorRates(timeWindowMs = null) {
    let metrics = this.metrics;

    if (timeWindowMs) {
      const cutoff = Date.now() - timeWindowMs;
      metrics = metrics.filter(m => m.timestamp >= cutoff);
    }

    const errorCounts = new Map();
    let totalErrors = 0;

    metrics.forEach(metric => {
      if (!metric.success && metric.error) {
        const errorType = metric.error.split(':')[0] || 'unknown';
        errorCounts.set(errorType, (errorCounts.get(errorType) || 0) + 1);
        totalErrors++;
      }
    });

    const rates = {};
    errorCounts.forEach((count, type) => {
      rates[type] = {
        count,
        rate: count / totalErrors
      };
    });

    return rates;
  }

  /**
   * Clear all metrics
   */
  clear() {
    const count = this.metrics.length;
    this.metrics = [];
    this.counters.clear();
    log.debug('Performance metrics cleared', { clearedCount: count });
  }

  /**
   * Get recent metrics
   * @param {number} [limit] - Limit number of results
   * @returns {MetricEntry[]} Recent metrics
   */
  getRecentMetrics(limit = 10) {
    return this.metrics.slice(-limit);
  }
}

// Create singleton instance
let instance = null;

/**
 * Get the singleton PerformanceMonitor instance
 * @returns {PerformanceMonitor} PerformanceMonitor instance
 */
function getPerformanceMonitor() {
  if (!instance) {
    instance = new PerformanceMonitor();
  }
  return instance;
}

module.exports = {
  PerformanceMonitor,
  getPerformanceMonitor
};

