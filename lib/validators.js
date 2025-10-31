/**
 * Validation utilities for the pulse widgets codebase
 * @fileoverview Input validation functions for files, URLs, ports, and data
 */

const fs = require('fs');
const path = require('path');
const { URL } = require('url');
const { ErrorFactory } = require('./errors.js');

/**
 * File validation utilities
 */
class FileValidator {
  /**
   * Validate if a file exists and is readable
   * @param {string} filePath - Path to the file
   * @returns {boolean} True if file exists and is readable
   */
  static exists(filePath) {
    try {
      return fs.existsSync(filePath) && fs.accessSync(filePath, fs.constants.R_OK) === undefined;
    } catch (error) {
      return false;
    }
  }

  /**
   * Validate if a file is writable
   * @param {string} filePath - Path to the file
   * @returns {boolean} True if file is writable
   */
  static isWritable(filePath) {
    try {
      const dir = path.dirname(filePath);
      return fs.accessSync(dir, fs.constants.W_OK) === undefined;
    } catch (error) {
      return false;
    }
  }

  /**
   * Validate if a file has a specific extension
   * @param {string} filePath - Path to the file
   * @param {string|Array<string>} extensions - Extension(s) to check
   * @returns {boolean} True if file has the specified extension
   */
  static hasExtension(filePath, extensions) {
    const ext = path.extname(filePath).toLowerCase();
    const validExtensions = Array.isArray(extensions) ? extensions : [extensions];
    return validExtensions.some(validExt => ext === validExt.toLowerCase());
  }

  /**
   * Validate if a file is valid JSON
   * @param {string} filePath - Path to the JSON file
   * @returns {Object} { valid: boolean, data: any, error: string }
   */
  static isValidJSON(filePath) {
    try {
      if (!this.exists(filePath)) {
        return { valid: false, data: null, error: 'File does not exist' };
      }
      
      const content = fs.readFileSync(filePath, 'utf8');
      const data = JSON.parse(content);
      return { valid: true, data, error: null };
    } catch (error) {
      return { valid: false, data: null, error: error.message };
    }
  }

  /**
   * Validate if a file is valid CSS
   * @param {string} filePath - Path to the CSS file
   * @returns {Object} { valid: boolean, content: string, error: string }
   */
  static isValidCSS(filePath) {
    try {
      if (!this.exists(filePath)) {
        return { valid: false, content: null, error: 'File does not exist' };
      }
      
      const content = fs.readFileSync(filePath, 'utf8');
      
      // Basic CSS validation - check for common CSS patterns
      const hasValidCSS = /[{}\s]/.test(content) && content.includes('{') && content.includes('}');
      
      if (!hasValidCSS) {
        return { valid: false, content, error: 'File does not appear to contain valid CSS' };
      }
      
      return { valid: true, content, error: null };
    } catch (error) {
      return { valid: false, content: null, error: error.message };
    }
  }

  /**
   * Validate file size is within limits
   * @param {string} filePath - Path to the file
   * @param {number} maxSizeBytes - Maximum file size in bytes
   * @returns {Object} { valid: boolean, size: number, error: string }
   */
  static isValidSize(filePath, maxSizeBytes = 10 * 1024 * 1024) { // 10MB default
    try {
      if (!this.exists(filePath)) {
        return { valid: false, size: 0, error: 'File does not exist' };
      }
      
      const stats = fs.statSync(filePath);
      const size = stats.size;
      
      if (size > maxSizeBytes) {
        return { 
          valid: false, 
          size, 
          error: `File size ${size} bytes exceeds maximum ${maxSizeBytes} bytes` 
        };
      }
      
      return { valid: true, size, error: null };
    } catch (error) {
      return { valid: false, size: 0, error: error.message };
    }
  }
}

/**
 * URL validation utilities
 */
class URLValidator {
  /**
   * Validate if a string is a valid URL
   * @param {string} urlString - URL string to validate
   * @returns {Object} { valid: boolean, url: URL|null, error: string }
   */
  static isValid(urlString) {
    try {
      if (!urlString || typeof urlString !== 'string') {
        return { valid: false, url: null, error: 'URL must be a non-empty string' };
      }
      
      const url = new URL(urlString);
      
      // Check for supported protocols
      const supportedProtocols = ['http:', 'https:'];
      if (!supportedProtocols.includes(url.protocol)) {
        return { 
          valid: false, 
          url: null, 
          error: `Protocol ${url.protocol} is not supported. Use http: or https:` 
        };
      }
      
      return { valid: true, url, error: null };
    } catch (error) {
      return { valid: false, url: null, error: error.message };
    }
  }

  /**
   * Validate if a URL is accessible (basic check)
   * @param {string} urlString - URL string to validate
   * @param {number} timeoutMs - Timeout in milliseconds
   * @returns {Promise<Object>} { valid: boolean, statusCode: number|null, error: string }
   */
  static async isAccessible(urlString, timeoutMs = 5000) {
    try {
      const urlValidation = this.isValid(urlString);
      if (!urlValidation.valid) {
        return { valid: false, statusCode: null, error: urlValidation.error };
      }
      
      // This would require a fetch implementation in Node.js
      // For now, we'll just validate the URL format
      return { valid: true, statusCode: null, error: null };
    } catch (error) {
      return { valid: false, statusCode: null, error: error.message };
    }
  }

  /**
   * Normalize URL by adding protocol if missing
   * @param {string} urlString - URL string to normalize
   * @returns {string} Normalized URL
   */
  static normalize(urlString) {
    if (!urlString) return '';
    
    const trimmed = urlString.trim();
    if (/^https?:\/\//i.test(trimmed)) {
      return trimmed;
    }
    
    return `https://${trimmed}`;
  }
}

/**
 * Port validation utilities
 */
class PortValidator {
  /**
   * Validate if a port number is valid
   * @param {number|string} port - Port number to validate
   * @returns {Object} { valid: boolean, port: number|null, error: string }
   */
  static isValid(port) {
    try {
      const portNum = typeof port === 'string' ? parseInt(port, 10) : port;
      
      if (isNaN(portNum)) {
        return { valid: false, port: null, error: 'Port must be a number' };
      }
      
      if (portNum < 1 || portNum > 65535) {
        return { valid: false, port: null, error: 'Port must be between 1 and 65535' };
      }
      
      return { valid: true, port: portNum, error: null };
    } catch (error) {
      return { valid: false, port: null, error: error.message };
    }
  }

  /**
   * Check if a port is available (basic check)
   * @param {number} port - Port number to check
   * @returns {boolean} True if port appears to be available
   */
  static isAvailable(port) {
    // This is a simplified check - in a real implementation,
    // you'd want to actually try to bind to the port
    const validation = this.isValid(port);
    return validation.valid;
  }
}

/**
 * Theme JSON schema validation
 */
class ThemeValidator {
  /**
   * Basic theme JSON schema
   */
  static getSchema() {
    return {
      type: 'object',
      required: ['name'],
      properties: {
        name: { type: 'string', minLength: 1 },
        description: { type: 'string' },
        typography: { type: 'object' },
        colors: { type: 'object' },
        radii: { type: 'object' },
        shadows: { type: 'object' },
        layout: { type: 'object' },
        buttons: { type: 'object' },
        inputs: { type: 'object' },
        answers: { type: 'object' },
        widgets: { type: 'object' },
        modes: { type: 'object' },
        extends: { type: 'string' }
      }
    };
  }

  /**
   * Validate theme JSON against schema
   * @param {Object} themeData - Theme data to validate
   * @returns {Object} { valid: boolean, errors: Array<string>, warnings: Array<string> }
   */
  static validate(themeData) {
    const errors = [];
    const warnings = [];
    
    if (!themeData || typeof themeData !== 'object') {
      errors.push('Theme data must be an object');
      return { valid: false, errors, warnings };
    }
    
    // Check required fields
    if (!themeData.name || typeof themeData.name !== 'string') {
      errors.push('Theme must have a valid name');
    }
    
    // Check optional fields
    if (themeData.description && typeof themeData.description !== 'string') {
      warnings.push('Description should be a string');
    }
    
    // Check for recommended color properties
    // Generate warnings if colors object is missing OR if required colors are missing
    const requiredColors = ['text', 'bg', 'primary'];
    if (!themeData.colors) {
      warnings.push('Missing recommended colors object');
      requiredColors.forEach(color => {
        warnings.push(`Missing recommended color: ${color}`);
      });
    } else {
      requiredColors.forEach(color => {
        if (!themeData.colors[color]) {
          warnings.push(`Missing recommended color: ${color}`);
        }
      });
    }
    
    // Check for recommended typography properties
    if (!themeData.typography) {
      warnings.push('Missing recommended typography object');
      warnings.push('Missing recommended fontFamily in typography');
    } else if (!themeData.typography.fontFamily) {
      warnings.push('Missing recommended fontFamily in typography');
    }
    
    return {
      valid: errors.length === 0,
      errors,
      warnings
    };
  }
}

/**
 * Input parameter validation utilities
 */
class ParameterValidator {
  /**
   * Validate command line arguments
   * @param {Array<string>} args - Command line arguments
   * @param {Object} schema - Validation schema
   * @returns {Object} { valid: boolean, params: Object, errors: Array<string> }
   */
  static validateArgs(args, schema) {
    const errors = [];
    const params = {};
    
    try {
      Object.keys(schema).forEach((key, index) => {
        const paramSchema = schema[key];
        const value = args[index];
        
        if (paramSchema.required && (!value || value.trim() === '')) {
          errors.push(`Required parameter ${key} is missing`);
          return;
        }
        
        if (value) {
          // Type validation
          if (paramSchema.type === 'number') {
            const numValue = parseFloat(value);
            if (isNaN(numValue)) {
              errors.push(`Parameter ${key} must be a number`);
              return;
            }
            params[key] = numValue;
          } else if (paramSchema.type === 'boolean') {
            params[key] = value.toLowerCase() === 'true';
          } else {
            params[key] = value;
          }
          
          // Additional validation
          if (paramSchema.minLength && params[key].length < paramSchema.minLength) {
            errors.push(`Parameter ${key} must be at least ${paramSchema.minLength} characters`);
          }
          
          if (paramSchema.maxLength && params[key].length > paramSchema.maxLength) {
            errors.push(`Parameter ${key} must be no more than ${paramSchema.maxLength} characters`);
          }
        } else if (paramSchema.default !== undefined) {
          params[key] = paramSchema.default;
        }
      });
      
      return {
        valid: errors.length === 0,
        params,
        errors
      };
    } catch (error) {
      return {
        valid: false,
        params: {},
        errors: [`Parameter validation error: ${error.message}`]
      };
    }
  }
}

/**
 * Comprehensive validation function
 * @param {Object} input - Input to validate
 * @param {Object} rules - Validation rules
 * @returns {Object} { valid: boolean, errors: Array<string>, warnings: Array<string> }
 */
function validateInput(input, rules) {
  const errors = [];
  const warnings = [];
  
  try {
    // File validation
    if (rules.file) {
      const fileValidation = FileValidator.exists(input.file);
      if (!fileValidation) {
        errors.push(`File does not exist or is not readable: ${input.file}`);
      }
      
      if (rules.file.extensions) {
        const extValidation = FileValidator.hasExtension(input.file, rules.file.extensions);
        if (!extValidation) {
          errors.push(`File must have one of these extensions: ${rules.file.extensions.join(', ')}`);
        }
      }
    }
    
    // URL validation
    if (rules.url) {
      const urlValidation = URLValidator.isValid(input.url);
      if (!urlValidation.valid) {
        errors.push(`Invalid URL: ${urlValidation.error}`);
      }
    }
    
    // Port validation
    if (rules.port) {
      const portValidation = PortValidator.isValid(input.port);
      if (!portValidation.valid) {
        errors.push(`Invalid port: ${portValidation.error}`);
      }
    }
    
    // Theme validation
    if (rules.theme) {
      const themeValidation = ThemeValidator.validate(input.theme);
      errors.push(...themeValidation.errors);
      warnings.push(...themeValidation.warnings);
    }
    
    return {
      valid: errors.length === 0,
      errors,
      warnings
    };
  } catch (error) {
    return {
      valid: false,
      errors: [`Validation error: ${error.message}`],
      warnings: []
    };
  }
}

module.exports = {
  FileValidator,
  URLValidator,
  PortValidator,
  ThemeValidator,
  ParameterValidator,
  validateInput
};
