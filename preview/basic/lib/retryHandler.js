/**
 * @fileoverview Retry Handler with Exponential Backoff
 * 
 * Provides retry logic with exponential backoff and jitter
 * for handling transient errors in presentation flow.
 */

const { log } = require('../../../lib/logger');

/**
 * Default retry configuration
 */
const DEFAULT_RETRY_CONFIG = {
  maxAttempts: 3,
  initialDelayMs: 1000,
  maxDelayMs: 10000,
  backoffMultiplier: 2,
  jitter: true
};

/**
 * Retry handler with exponential backoff
 */
class RetryHandler {
  /**
   * Create a new RetryHandler
   * @param {Object} config - Retry configuration
   * @param {number} config.maxAttempts - Maximum retry attempts (default: 3)
   * @param {number} config.initialDelayMs - Initial delay in ms (default: 1000)
   * @param {number} config.maxDelayMs - Maximum delay in ms (default: 10000)
   * @param {number} config.backoffMultiplier - Backoff multiplier (default: 2)
   * @param {boolean} config.jitter - Whether to add jitter (default: true)
   */
  constructor(config = {}) {
    this.config = { ...DEFAULT_RETRY_CONFIG, ...config };
  }

  /**
   * Execute function with retry logic
   * @param {Function} fn - Function to execute (should return Promise)
   * @param {Object} options - Retry options
   * @param {Function} [options.isRetryable] - Function to check if error is retryable
   * @param {Function} [options.onRetry] - Callback on retry attempt
   * @returns {Promise<any>} Result of function execution
   */
  async execute(fn, options = {}) {
    const { isRetryable = () => true, onRetry = () => {} } = options;
    let lastError = null;

    for (let attempt = 1; attempt <= this.config.maxAttempts; attempt++) {
      try {
        return await fn();
      } catch (error) {
        lastError = error;

        // Check if error is retryable
        if (!isRetryable(error)) {
          log.debug('Error is not retryable', { error: error.message, attempt });
          throw error;
        }

        // Check if we've exhausted retries
        if (attempt >= this.config.maxAttempts) {
          log.warn('Max retry attempts reached', {
            attempts: attempt,
            error: error.message
          });
          throw error;
        }

        // Calculate delay with exponential backoff
        const delay = this.calculateDelay(attempt);
        
        log.debug('Retrying after delay', {
          attempt,
          delay,
          error: error.message
        });

        onRetry(attempt, delay, error);

        // Wait before retry
        await this.sleep(delay);
      }
    }

    throw lastError;
  }

  /**
   * Calculate delay for retry attempt
   * @private
   * @param {number} attempt - Current attempt number (1-based)
   * @returns {number} Delay in milliseconds
   */
  calculateDelay(attempt) {
    // Exponential backoff: initialDelay * (multiplier ^ (attempt - 1))
    const exponentialDelay = this.config.initialDelayMs * 
      Math.pow(this.config.backoffMultiplier, attempt - 1);
    
    // Cap at max delay
    let delay = Math.min(exponentialDelay, this.config.maxDelayMs);

    // Add jitter to prevent thundering herd
    if (this.config.jitter) {
      const jitterAmount = delay * 0.1; // 10% jitter
      const jitter = (Math.random() * 2 - 1) * jitterAmount;
      delay = Math.max(0, delay + jitter);
    }

    return Math.round(delay);
  }

  /**
   * Sleep for specified milliseconds
   * @private
   * @param {number} ms - Milliseconds to sleep
   * @returns {Promise<void>}
   */
  sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

/**
 * Check if error is retryable
 * @param {Error} error - Error to check
 * @returns {boolean} True if error is retryable
 */
function isRetryableError(error) {
  // Network errors are retryable
  if (error.name === 'NetworkError' || error.message.includes('network') || 
      error.message.includes('fetch') || error.message.includes('timeout')) {
    return true;
  }

  // Tag loading errors are retryable
  if (error.message.includes('tag') || error.message.includes('script')) {
    return true;
  }

  // Player initialization errors are retryable
  if (error.message.includes('player') || error.message.includes('iframe')) {
    return true;
  }

  // Validation errors are not retryable
  if (error.name === 'ValidationError') {
    return false;
  }

  // Default: assume retryable for transient errors
  return true;
}

module.exports = {
  RetryHandler,
  isRetryableError,
  DEFAULT_RETRY_CONFIG
};

