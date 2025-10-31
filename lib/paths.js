/**
 * Path utility functions for consistent path handling
 * @fileoverview Utilities for path operations across the pulse widgets codebase
 */

const path = require('path');
const fs = require('fs');
const { ErrorFactory } = require('./errors.js');

/**
 * Path utility class for consistent path operations
 */
class PathUtils {
  /**
   * Resolve a path relative to project root
   * @param {string} relativePath - Path relative to project root
   * @returns {string} Absolute path
   */
  static resolveFromRoot(relativePath) {
    try {
      return path.resolve(process.cwd(), relativePath);
    } catch (error) {
      throw ErrorFactory.fileOperation(`Failed to resolve path from root: ${error.message}`, relativePath, 'resolve');
    }
  }

  /**
   * Resolve a path relative to a specific directory
   * @param {string} baseDir - Base directory
   * @param {string} relativePath - Path relative to base directory
   * @returns {string} Absolute path
   */
  static resolveFromDir(baseDir, relativePath) {
    try {
      return path.resolve(baseDir, relativePath);
    } catch (error) {
      throw ErrorFactory.fileOperation(`Failed to resolve path from directory: ${error.message}`, relativePath, 'resolve');
    }
  }

  /**
   * Normalize a path (resolve . and .. components)
   * @param {string} filePath - Path to normalize
   * @returns {string} Normalized path
   */
  static normalize(filePath) {
    try {
      return path.normalize(filePath);
    } catch (error) {
      throw ErrorFactory.fileOperation(`Failed to normalize path: ${error.message}`, filePath, 'normalize');
    }
  }

  /**
   * Get the directory name of a path
   * @param {string} filePath - Path to get directory from
   * @returns {string} Directory name
   */
  static dirname(filePath) {
    try {
      return path.dirname(filePath);
    } catch (error) {
      throw ErrorFactory.fileOperation(`Failed to get directory name: ${error.message}`, filePath, 'dirname');
    }
  }

  /**
   * Get the file name of a path
   * @param {string} filePath - Path to get file name from
   * @returns {string} File name
   */
  static basename(filePath, ext = '') {
    try {
      return path.basename(filePath, ext);
    } catch (error) {
      throw ErrorFactory.fileOperation(`Failed to get file name: ${error.message}`, filePath, 'basename');
    }
  }

  /**
   * Get the file extension of a path
   * @param {string} filePath - Path to get extension from
   * @returns {string} File extension (including the dot)
   */
  static extname(filePath) {
    try {
      return path.extname(filePath);
    } catch (error) {
      throw ErrorFactory.fileOperation(`Failed to get file extension: ${error.message}`, filePath, 'extname');
    }
  }

  /**
   * Join multiple path segments
   * @param {...string} segments - Path segments to join
   * @returns {string} Joined path
   */
  static join(...segments) {
    try {
      return path.join(...segments);
    } catch (error) {
      throw ErrorFactory.fileOperation(`Failed to join paths: ${error.message}`, segments.join(', '), 'join');
    }
  }

  /**
   * Check if a path is absolute
   * @param {string} filePath - Path to check
   * @returns {boolean} True if path is absolute
   */
  static isAbsolute(filePath) {
    try {
      return path.isAbsolute(filePath);
    } catch (error) {
      throw ErrorFactory.fileOperation(`Failed to check if path is absolute: ${error.message}`, filePath, 'isAbsolute');
    }
  }

  /**
   * Get the relative path from one path to another
   * @param {string} from - Source path
   * @param {string} to - Target path
   * @returns {string} Relative path
   */
  static relative(from, to) {
    try {
      return path.relative(from, to);
    } catch (error) {
      throw ErrorFactory.fileOperation(`Failed to get relative path: ${error.message}`, `${from} -> ${to}`, 'relative');
    }
  }

  /**
   * Ensure a directory exists, creating it if necessary
   * @param {string} dirPath - Directory path to ensure
   * @returns {boolean} True if directory exists or was created
   */
  static ensureDir(dirPath) {
    try {
      if (fs.existsSync(dirPath)) {
        return fs.statSync(dirPath).isDirectory();
      }
      
      fs.mkdirSync(dirPath, { recursive: true });
      return true;
    } catch (error) {
      throw ErrorFactory.fileOperation(`Failed to ensure directory exists: ${error.message}`, dirPath, 'ensureDir');
    }
  }

  /**
   * Get the common path prefix of multiple paths
   * @param {Array<string>} paths - Array of paths
   * @returns {string} Common path prefix
   */
  static commonPrefix(paths) {
    if (!paths || paths.length === 0) {
      return '';
    }
    
    if (paths.length === 1) {
      return PathUtils.dirname(paths[0]);
    }
    
    try {
      let common = paths[0];
      for (let i = 1; i < paths.length; i++) {
        common = path.dirname(common);
        if (!paths[i].startsWith(common)) {
          break;
        }
      }
      return common;
    } catch (error) {
      throw ErrorFactory.fileOperation(`Failed to find common path prefix: ${error.message}`, paths.join(', '), 'commonPrefix');
    }
  }

  /**
   * Convert a path to use forward slashes (for cross-platform compatibility)
   * @param {string} filePath - Path to convert
   * @returns {string} Path with forward slashes
   */
  static toForwardSlashes(filePath) {
    return filePath.replace(/\\/g, '/');
  }

  /**
   * Convert a path to use backslashes (Windows style)
   * @param {string} filePath - Path to convert
   * @returns {string} Path with backslashes
   */
  static toBackslashes(filePath) {
    return filePath.replace(/\//g, '\\');
  }

  /**
   * Get a safe filename by removing invalid characters
   * @param {string} filename - Filename to sanitize
   * @returns {string} Safe filename
   */
  static sanitizeFilename(filename) {
    return filename
      .replace(/[<>:"/\\|?*]/g, '_')
      .replace(/\s+/g, '_')
      .replace(/_{2,}/g, '_')
      .replace(/^_|_$/g, '');
  }

  /**
   * Check if a path is within a given directory (security check)
   * @param {string} baseDir - Base directory
   * @param {string} targetPath - Path to check
   * @returns {boolean} True if target path is within base directory
   */
  static isWithinDirectory(baseDir, targetPath) {
    try {
      const resolvedBase = path.resolve(baseDir);
      const resolvedTarget = path.resolve(targetPath);
      return resolvedTarget.startsWith(resolvedBase);
    } catch (error) {
      throw ErrorFactory.fileOperation(`Failed to check if path is within directory: ${error.message}`, targetPath, 'isWithinDirectory');
    }
  }

  /**
   * Get the size of a file or directory
   * @param {string} filePath - Path to check
   * @returns {number} Size in bytes
   */
  static getSize(filePath) {
    try {
      const stats = fs.statSync(filePath);
      if (stats.isFile()) {
        return stats.size;
      } else if (stats.isDirectory()) {
        let totalSize = 0;
        const files = fs.readdirSync(filePath);
        for (const file of files) {
          const fullPath = path.join(filePath, file);
          totalSize += PathUtils.getSize(fullPath);
        }
        return totalSize;
      }
      return 0;
    } catch (error) {
      throw ErrorFactory.fileOperation(`Failed to get size: ${error.message}`, filePath, 'getSize');
    }
  }

  /**
   * Format file size in human-readable format
   * @param {number} bytes - Size in bytes
   * @returns {string} Human-readable size
   */
  static formatSize(bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    let size = bytes;
    let unitIndex = 0;
    
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    
    return `${size.toFixed(1)} ${units[unitIndex]}`;
  }
}

module.exports = {
  PathUtils
};
