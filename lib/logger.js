/**
 * Standardized logging utilities for the pulse widgets codebase
 * @fileoverview Logging system with consistent formatting and levels
 */

const { ErrorHandler } = require('./errors.js');

/**
 * Log levels in order of severity
 */
const LOG_LEVELS = {
  DEBUG: 0,
  INFO: 1,
  WARN: 2,
  ERROR: 3
};

/**
 * Default log level
 */
const DEFAULT_LOG_LEVEL = LOG_LEVELS.INFO;

/**
 * Logger class for consistent logging across the application
 */
class Logger {
  constructor(name = 'PulseWidgets', level = DEFAULT_LOG_LEVEL) {
    this.name = name;
    this.level = level;
    this.context = {};
  }

  /**
   * Set logging context
   * @param {Object} context - Context to include in all logs
   */
  setContext(context) {
    this.context = { ...this.context, ...context };
  }

  /**
   * Clear logging context
   */
  clearContext() {
    this.context = {};
  }

  /**
   * Check if a log level should be output
   * @param {number} level - Log level to check
   * @returns {boolean} True if should log
   */
  shouldLog(level) {
    return level >= this.level;
  }

  /**
   * Format log message
   * @param {string} level - Log level name
   * @param {string} message - Log message
   * @param {Object} metadata - Additional metadata
   * @returns {Object} Formatted log entry
   */
  formatLog(level, message, metadata = {}) {
    return {
      timestamp: new Date().toISOString(),
      level,
      logger: this.name,
      message,
      metadata: { ...this.context, ...metadata }
    };
  }

  /**
   * Output log entry
   * @param {Object} logEntry - Formatted log entry
   */
  output(logEntry) {
    const { timestamp, level, logger, message, metadata } = logEntry;
    const contextStr = Object.keys(metadata).length > 0 ? ` ${JSON.stringify(metadata)}` : '';
    console.log(`[${timestamp}] ${level} [${logger}] ${message}${contextStr}`);
  }

  /**
   * Debug level logging
   * @param {string} message - Log message
   * @param {Object} metadata - Additional metadata
   */
  debug(message, metadata = {}) {
    if (this.shouldLog(LOG_LEVELS.DEBUG)) {
      const logEntry = this.formatLog('DEBUG', message, metadata);
      this.output(logEntry);
    }
  }

  /**
   * Info level logging
   * @param {string} message - Log message
   * @param {Object} metadata - Additional metadata
   */
  info(message, metadata = {}) {
    if (this.shouldLog(LOG_LEVELS.INFO)) {
      const logEntry = this.formatLog('INFO', message, metadata);
      this.output(logEntry);
    }
  }

  /**
   * Warning level logging
   * @param {string} message - Log message
   * @param {Object} metadata - Additional metadata
   */
  warn(message, metadata = {}) {
    if (this.shouldLog(LOG_LEVELS.WARN)) {
      const logEntry = this.formatLog('WARN', message, metadata);
      this.output(logEntry);
    }
  }

  /**
   * Error level logging
   * @param {string} message - Log message
   * @param {Error|Object} error - Error object or metadata
   * @param {Object} metadata - Additional metadata
   */
  error(message, error = null, metadata = {}) {
    if (this.shouldLog(LOG_LEVELS.ERROR)) {
      let logMetadata = { ...metadata };
      
      if (error instanceof Error) {
        logMetadata = {
          ...logMetadata,
          ...ErrorHandler.formatError(error, metadata)
        };
      } else if (error && typeof error === 'object') {
        logMetadata = { ...logMetadata, ...error };
      }
      
      const logEntry = this.formatLog('ERROR', message, logMetadata);
      this.output(logEntry);
    }
  }

  /**
   * Log performance metrics
   * @param {string} operation - Operation name
   * @param {number} duration - Duration in milliseconds
   * @param {Object} metadata - Additional metadata
   */
  performance(operation, duration, metadata = {}) {
    this.info(`Performance: ${operation} completed in ${duration}ms`, {
      operation,
      duration,
      ...metadata
    });
  }

  /**
   * Log user action
   * @param {string} action - Action performed
   * @param {Object} metadata - Additional metadata
   */
  userAction(action, metadata = {}) {
    this.info(`User action: ${action}`, {
      action,
      ...metadata
    });
  }
}

/**
 * Create a logger instance
 * @param {string} name - Logger name
 * @param {number} level - Log level
 * @returns {Logger} Logger instance
 */
function createLogger(name, level = DEFAULT_LOG_LEVEL) {
  return new Logger(name, level);
}

/**
 * Get log level from environment variable
 * @returns {number} Log level
 */
function getLogLevelFromEnv() {
  const envLevel = process.env.LOG_LEVEL?.toUpperCase();
  switch (envLevel) {
    case 'DEBUG': return LOG_LEVELS.DEBUG;
    case 'INFO': return LOG_LEVELS.INFO;
    case 'WARN': return LOG_LEVELS.WARN;
    case 'ERROR': return LOG_LEVELS.ERROR;
    default: return DEFAULT_LOG_LEVEL;
  }
}

/**
 * Default logger instance
 */
const defaultLogger = new Logger('PulseWidgets', getLogLevelFromEnv());

/**
 * Convenience functions using default logger
 */
const log = {
  debug: (message, metadata) => defaultLogger.debug(message, metadata),
  info: (message, metadata) => defaultLogger.info(message, metadata),
  warn: (message, metadata) => defaultLogger.warn(message, metadata),
  error: (message, error, metadata) => defaultLogger.error(message, error, metadata),
  performance: (operation, duration, metadata) => defaultLogger.performance(operation, duration, metadata),
  userAction: (action, metadata) => defaultLogger.userAction(action, metadata)
};

module.exports = {
  Logger,
  LOG_LEVELS,
  createLogger,
  getLogLevelFromEnv,
  defaultLogger,
  log
};
