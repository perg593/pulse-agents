/**
 * Centralized path configuration for common file and directory paths
 * @fileoverview Path patterns used across the pulse widgets codebase
 */

const path = require('path');

/**
 * Base paths for different components
 * @type {Object}
 */
const BASE_PATHS = {
  /** Lipsum local content base path */
  LIPSUM_BASE: '/lipsum_local/www.lipsum.com/',
  
  /** Lipsum index file path */
  LIPSUM_INDEX: '/lipsum_local/www.lipsum.com/index.html',
  
  /** Theme generator v1 output directory */
  THEME_OUTPUT_DIR: 'theme-generator/v1/output',
  
  /** Theme generator v2 output directory */
  THEME_V2_OUTPUT_DIR: 'theme-generator/v2/output',
  
  /** Theme generator base directory */
  THEME_GENERATOR_DIR: 'theme-generator',
  
  /** Theme generator v1 directory */
  THEME_GENERATOR_V1_DIR: 'theme-generator/v1',
  
  /** Theme generator v2 directory */
  THEME_GENERATOR_V2_DIR: 'theme-generator/v2',
  
  /** Preview directory */
  PREVIEW_DIR: 'preview',
  
  /** Preview basic directory */
  PREVIEW_BASIC_DIR: 'preview/basic',
  
  /** Preview v3 directory */
  PREVIEW_V3_DIR: 'preview/v3-prototype',
  
  /** Preview dist directory */
  PREVIEW_DIST_DIR: 'preview/dist',
  
  /** Preview widgets directory */
  PREVIEW_WIDGETS_DIR: 'preview/widgets',
  
  /** Preview styles directory */
  PREVIEW_STYLES_DIR: 'preview/styles',
  
  /** Preview themes directory */
  PREVIEW_THEMES_DIR: 'preview/themes',
  
  /** Preview backgrounds directory */
  PREVIEW_BACKGROUNDS_DIR: 'preview/backgrounds',
  
  /** Legacy directory */
  LEGACY_DIR: 'legacy',
  
  /** Test directory */
  TEST_DIR: 'tests',
  
  /** Tests unit directory */
  TESTS_UNIT_DIR: 'tests/unit',
  
  /** Tests integration directory */
  TESTS_INTEGRATION_DIR: 'tests/integration',
  
  /** Tests fixtures directory */
  TESTS_FIXTURES_DIR: 'tests/fixtures',
  
  /** Tests support directory */
  TESTS_SUPPORT_DIR: 'tests/support',
  
  /** Scripts directory */
  SCRIPTS_DIR: 'scripts',
  
  /** Scripts launch directory */
  SCRIPTS_LAUNCH_DIR: 'scripts/launch',
  
  /** Scripts build directory */
  SCRIPTS_BUILD_DIR: 'scripts/build',
  
  /** Config directory */
  CONFIG_DIR: 'config',
  
  /** Lib directory */
  LIB_DIR: 'lib'
};

/**
 * File patterns for different types of content
 * @type {Object}
 */
const FILE_PATTERNS = {
  /** Theme CSS files */
  THEME_CSS: '*.css',
  
  /** Theme JSON files */
  THEME_JSON: '*.json',
  
  /** JavaScript files */
  JAVASCRIPT: '*.js',
  
  /** HTML files */
  HTML: '*.html',
  
  /** Markdown files */
  MARKDOWN: '*.md',
  
  /** Package files */
  PACKAGE_JSON: 'package.json',
  
  /** Lock files */
  PACKAGE_LOCK: 'package-lock.json'
};

/**
 * Resolve a path relative to project root
 * @param {string} relativePath - Path relative to project root
 * @returns {string} Absolute path
 */
function resolveFromRoot(relativePath) {
  return path.resolve(process.cwd(), relativePath);
}

/**
 * Resolve a path relative to a specific directory
 * @param {string} baseDir - Base directory
 * @param {string} relativePath - Path relative to base directory
 * @returns {string} Absolute path
 */
function resolveFromDir(baseDir, relativePath) {
  return path.resolve(baseDir, relativePath);
}

/**
 * Get theme output path for a specific client
 * @param {string} clientName - Name of the client
 * @returns {string} Path to client theme directory
 */
function getClientThemePath(clientName) {
  return path.join(BASE_PATHS.THEME_OUTPUT_DIR, 'client-themes', clientName);
}

/**
 * Get preview asset path
 * @param {string} assetName - Name of the asset
 * @returns {string} Path to preview asset
 */
function getPreviewAssetPath(assetName) {
  return path.join(BASE_PATHS.PREVIEW_DIR, assetName);
}

/**
 * Get legacy asset path
 * @param {string} assetName - Name of the asset
 * @returns {string} Path to legacy asset
 */
function getLegacyAssetPath(assetName) {
  return path.join(BASE_PATHS.LEGACY_DIR, assetName);
}

/**
 * Validate if a path exists and is accessible
 * @param {string} filePath - Path to validate
 * @returns {boolean} True if path exists and is accessible
 */
function isValidPath(filePath) {
  try {
    const fs = require('fs');
    return fs.existsSync(filePath) && fs.accessSync(filePath, fs.constants.R_OK) === undefined;
  } catch (error) {
    return false;
  }
}

/**
 * Get all paths as a single object
 * @returns {Object} All paths combined
 */
function getAllPaths() {
  return {
    base: BASE_PATHS,
    patterns: FILE_PATTERNS
  };
}

module.exports = {
  BASE_PATHS,
  FILE_PATTERNS,
  resolveFromRoot,
  resolveFromDir,
  getClientThemePath,
  getPreviewAssetPath,
  getLegacyAssetPath,
  isValidPath,
  getAllPaths
};
