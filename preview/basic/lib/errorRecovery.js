/**
 * @fileoverview Error Recovery Strategies
 * 
 * Provides error recovery strategies for different error types
 * in the presentation flow.
 */

const { log } = require('../../../lib/logger');
const { RetryHandler, isRetryableError } = require('./retryHandler');

/**
 * Error recovery strategies
 */
class ErrorRecovery {
  /**
   * Create a new ErrorRecovery instance
   * @param {Object} config - Recovery configuration
   */
  constructor(config = {}) {
    this.retryHandler = new RetryHandler(config.retry || {});
    this.config = config;
  }

  /**
   * Recover from network error
   * @param {Function} fn - Function to retry
   * @param {Object} context - Error context
   * @returns {Promise<any>} Result of retry
   */
  async recoverFromNetworkError(fn, context = {}) {
    return this.retryHandler.execute(fn, {
      isRetryable: (error) => {
        return error.name === 'NetworkError' || 
               error.message.includes('network') ||
               error.message.includes('fetch');
      },
      onRetry: (attempt, delay, error) => {
        log.info('Retrying network operation', {
          attempt,
          delay,
          error: error.message,
          ...context
        });
      }
    });
  }

  /**
   * Recover from tag loading error
   * @param {Function} fn - Function to retry
   * @param {Object} context - Error context
   * @returns {Promise<any>} Result of retry
   */
  async recoverFromTagLoadingError(fn, context = {}) {
    return this.retryHandler.execute(fn, {
      isRetryable: (error) => {
        return error.message.includes('tag') || 
               error.message.includes('script') ||
               error.message.includes('PulseInsights');
      },
      onRetry: (attempt, delay, error) => {
        log.info('Retrying tag loading', {
          attempt,
          delay,
          error: error.message,
          ...context
        });
      }
    });
  }

  /**
   * Recover from player initialization error
   * @param {Function} fn - Function to retry
   * @param {Object} context - Error context
   * @returns {Promise<any>} Result of retry
   */
  async recoverFromPlayerInitError(fn, context = {}) {
    return this.retryHandler.execute(fn, {
      isRetryable: (error) => {
        return error.message.includes('player') || 
               error.message.includes('iframe') ||
               error.message.includes('bridge');
      },
      onRetry: (attempt, delay, error) => {
        log.info('Retrying player initialization', {
          attempt,
          delay,
          error: error.message,
          ...context
        });
      }
    });
  }

  /**
   * Recover from survey presentation error
   * @param {Function} fn - Function to retry
   * @param {Object} context - Error context
   * @returns {Promise<any>} Result of retry
   */
  async recoverFromPresentationError(fn, context = {}) {
    return this.retryHandler.execute(fn, {
      isRetryable: (error) => {
        // Presentation errors are retryable if they're transient
        return isRetryableError(error) && 
               !error.message.includes('not found') &&
               !error.message.includes('invalid');
      },
      onRetry: (attempt, delay, error) => {
        log.info('Retrying survey presentation', {
          attempt,
          delay,
          error: error.message,
          surveyId: context.surveyId,
          ...context
        });
      }
    });
  }

  /**
   * Generic error recovery
   * @param {Function} fn - Function to retry
   * @param {Object} options - Recovery options
   * @returns {Promise<any>} Result of retry
   */
  async recover(fn, options = {}) {
    const { isRetryable = isRetryableError, onRetry = () => {} } = options;
    
    return this.retryHandler.execute(fn, {
      isRetryable,
      onRetry
    });
  }
}

module.exports = {
  ErrorRecovery,
  isRetryableError
};

