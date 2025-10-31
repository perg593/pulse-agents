/**
 * Custom error classes for the pulse widgets codebase
 * @fileoverview Error handling utilities with custom error types
 */

/**
 * Base error class for all pulse widgets errors
 * @extends Error
 */
class PulseWidgetsError extends Error {
  constructor(message, code = null, metadata = {}) {
    super(message);
    this.name = this.constructor.name;
    this.code = code;
    this.metadata = metadata;
    this.timestamp = new Date().toISOString();
    
    // Maintains proper stack trace for where our error was thrown
    if (Error.captureStackTrace) {
      Error.captureStackTrace(this, this.constructor);
    }
  }
}

/**
 * Theme generation specific errors
 * @extends PulseWidgetsError
 */
class ThemeGenerationError extends PulseWidgetsError {
  constructor(message, themeName = null, errors = []) {
    super(message, 'THEME_GENERATION_ERROR', { themeName, errors });
    this.themeName = themeName;
    this.errors = errors;
  }
}

/**
 * Validation specific errors
 * @extends PulseWidgetsError
 */
class ValidationError extends PulseWidgetsError {
  constructor(message, field = null, value = null) {
    super(message, 'VALIDATION_ERROR', { field, value });
    this.field = field;
    this.value = value;
  }
}

/**
 * Configuration specific errors
 * @extends PulseWidgetsError
 */
class ConfigError extends PulseWidgetsError {
  constructor(message, configKey = null) {
    super(message, 'CONFIG_ERROR', { configKey });
    this.configKey = configKey;
  }
}

/**
 * File operation specific errors
 * @extends PulseWidgetsError
 */
class FileOperationError extends PulseWidgetsError {
  constructor(message, filePath = null, operation = null) {
    super(message, 'FILE_OPERATION_ERROR', { filePath, operation });
    this.filePath = filePath;
    this.operation = operation;
  }
}

/**
 * Network/HTTP specific errors
 * @extends PulseWidgetsError
 */
class NetworkError extends PulseWidgetsError {
  constructor(message, url = null, statusCode = null) {
    super(message, 'NETWORK_ERROR', { url, statusCode });
    this.url = url;
    this.statusCode = statusCode;
  }
}

/**
 * Process management specific errors
 * @extends PulseWidgetsError
 */
class ProcessError extends PulseWidgetsError {
  constructor(message, processName = null, pid = null) {
    super(message, 'PROCESS_ERROR', { processName, pid });
    this.processName = processName;
    this.pid = pid;
  }
}

/**
 * Error factory for creating typed errors
 */
class ErrorFactory {
  /**
   * Create a theme generation error
   * @param {string} message - Error message
   * @param {string} themeName - Name of the theme that failed
   * @param {Array} errors - Array of specific errors
   * @returns {ThemeGenerationError}
   */
  static themeGeneration(message, themeName = null, errors = []) {
    return new ThemeGenerationError(message, themeName, errors);
  }

  /**
   * Create a validation error
   * @param {string} message - Error message
   * @param {string} field - Field that failed validation
   * @param {any} value - Value that failed validation
   * @returns {ValidationError}
   */
  static validation(message, field = null, value = null) {
    return new ValidationError(message, field, value);
  }

  /**
   * Create a configuration error
   * @param {string} message - Error message
   * @param {string} configKey - Configuration key that caused the error
   * @returns {ConfigError}
   */
  static config(message, configKey = null) {
    return new ConfigError(message, configKey);
  }

  /**
   * Create a file operation error
   * @param {string} message - Error message
   * @param {string} filePath - Path to the file
   * @param {string} operation - Operation that failed
   * @returns {FileOperationError}
   */
  static fileOperation(message, filePath = null, operation = null) {
    return new FileOperationError(message, filePath, operation);
  }

  /**
   * Create a network error
   * @param {string} message - Error message
   * @param {string} url - URL that failed
   * @param {number} statusCode - HTTP status code
   * @returns {NetworkError}
   */
  static network(message, url = null, statusCode = null) {
    return new NetworkError(message, url, statusCode);
  }

  /**
   * Create a process error
   * @param {string} message - Error message
   * @param {string} processName - Name of the process
   * @param {number} pid - Process ID
   * @returns {ProcessError}
   */
  static process(message, processName = null, pid = null) {
    return new ProcessError(message, processName, pid);
  }
}

/**
 * Error handler utility
 */
class ErrorHandler {
  /**
   * Handle and format an error for logging
   * @param {Error} error - Error to handle
   * @param {Object} context - Additional context
   * @returns {Object} Formatted error information
   */
  static formatError(error, context = {}) {
    const isCustomError = error instanceof PulseWidgetsError;
    
    return {
      name: error.name,
      message: error.message,
      code: isCustomError ? error.code : null,
      stack: error.stack,
      timestamp: isCustomError ? error.timestamp : new Date().toISOString(),
      metadata: isCustomError ? error.metadata : {},
      context
    };
  }

  /**
   * Check if an error is recoverable
   * @param {Error} error - Error to check
   * @returns {boolean} True if error is recoverable
   */
  static isRecoverable(error) {
    if (error instanceof ValidationError) return false;
    if (error instanceof ConfigError) return false;
    if (error instanceof NetworkError) return true;
    if (error instanceof ProcessError) return true;
    return false;
  }

  /**
   * Get user-friendly error message
   * @param {Error} error - Error to format
   * @returns {string} User-friendly message
   */
  static getUserMessage(error) {
    if (error instanceof ThemeGenerationError) {
      return `Theme generation failed: ${error.message}`;
    }
    if (error instanceof ValidationError) {
      return `Invalid input: ${error.message}`;
    }
    if (error instanceof ConfigError) {
      return `Configuration error: ${error.message}`;
    }
    if (error instanceof FileOperationError) {
      return `File operation failed: ${error.message}`;
    }
    if (error instanceof NetworkError) {
      return `Network error: ${error.message}`;
    }
    if (error instanceof ProcessError) {
      return `Process error: ${error.message}`;
    }
    return error.message || 'An unexpected error occurred';
  }
}

module.exports = {
  PulseWidgetsError,
  ThemeGenerationError,
  ValidationError,
  ConfigError,
  FileOperationError,
  NetworkError,
  ProcessError,
  ErrorFactory,
  ErrorHandler
};
