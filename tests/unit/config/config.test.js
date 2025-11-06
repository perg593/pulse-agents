/**
 * Unit tests for configuration modules
 * @fileoverview Tests for config/ports.js, config/constants.js, config/paths.js
 */

const { PORTS, PORT_OVERRIDES, getPorts, getPort } = require('../../../config/ports.js');
const { 
  BEHAVIOR_CONSTANTS, 
  UI_CONSTANTS, 
  BEHAVIOR_LISTENER_DEFAULTS, 
  BEHAVIOR_LABELS, 
  DEFAULT_BEHAVIOR_MESSAGE, 
  PRESENTATION_SETTINGS, 
  getAllConstants 
} = require('../../../config/constants.js');
const { 
  BASE_PATHS, 
  FILE_PATTERNS, 
  resolveFromRoot, 
  resolveFromDir, 
  getClientThemePath, 
  getPreviewAssetPath, 
  getLegacyAssetPath, 
  isValidPath, 
  getAllPaths 
} = require('../../../config/paths.js');

// Simple test framework
class TestFramework {
  constructor() {
    this.tests = [];
    this.passed = 0;
    this.failed = 0;
  }

  test(name, fn) {
    this.tests.push({ name, fn });
  }

  assert(condition, message) {
    if (!condition) {
      throw new Error(`Assertion failed: ${message}`);
    }
  }

  assertEqual(actual, expected, message) {
    if (actual !== expected) {
      throw new Error(`Assertion failed: ${message}. Expected: ${expected}, Actual: ${actual}`);
    }
  }

  assertThrows(fn, expectedError, message) {
    try {
      fn();
      throw new Error(`Assertion failed: ${message}. Expected function to throw, but it didn't`);
    } catch (error) {
      if (expectedError && !(error instanceof expectedError)) {
        throw new Error(`Assertion failed: ${message}. Expected ${expectedError.name}, got ${error.constructor.name}`);
      }
    }
  }

  run() {
    console.log('🧪 Running configuration tests...\n');
    
    for (const test of this.tests) {
      try {
        test.fn();
        console.log(`✅ ${test.name}`);
        this.passed++;
      } catch (error) {
        console.log(`❌ ${test.name}: ${error.message}`);
        this.failed++;
      }
    }
    
    console.log(`\n📊 Test Results: ${this.passed} passed, ${this.failed} failed`);
    return this.failed === 0;
  }
}

const test = new TestFramework();

// Test ports.js
test.test('PORTS should have correct default values', () => {
  test.assertEqual(PORTS.SERVER_PORT, 8000);
  test.assertEqual(PORTS.STRIPE_DEMO_PORT, 4242);
  test.assertEqual(PORTS.BACKGROUND_PROXY_PORT, 3100);
  test.assertEqual(PORTS.WEBPACK_DEV_PORT, 3035);
  test.assertEqual(PORTS.TEST_SERVER_PORT, 9898);
});

test.test('getPorts should return default ports for development', () => {
  const ports = getPorts('development');
  test.assertEqual(ports.SERVER_PORT, 8000);
  test.assertEqual(ports.STRIPE_DEMO_PORT, 4242);
  test.assertEqual(ports.BACKGROUND_PROXY_PORT, 3100);
});

test.test('getPorts should return test ports for test environment', () => {
  const ports = getPorts('test');
  test.assertEqual(ports.SERVER_PORT, 8001);
  test.assertEqual(ports.STRIPE_DEMO_PORT, 4243);
  test.assertEqual(ports.BACKGROUND_PROXY_PORT, 3101);
});

test.test('getPort should return specific port', () => {
  const port = getPort('SERVER_PORT', 'development');
  test.assertEqual(port, 8000);
});

test.test('getPort should return test port for test environment', () => {
  const port = getPort('SERVER_PORT', 'test');
  test.assertEqual(port, 8001);
});

test.test('getPort should fallback to default for unknown environment', () => {
  const port = getPort('SERVER_PORT', 'unknown');
  test.assertEqual(port, 8000);
});

// Test constants.js
test.test('BEHAVIOR_CONSTANTS should have correct values', () => {
  test.assertEqual(BEHAVIOR_CONSTANTS.IDLE_MS, 10000);
  test.assertEqual(BEHAVIOR_CONSTANTS.OVERLAY_AUTO_HIDE_MS, 3000);
  test.assertEqual(BEHAVIOR_CONSTANTS.SCROLL_TRIGGER, 0.6);
  test.assertEqual(BEHAVIOR_CONSTANTS.SCROLL_RESET, 0.2);
  test.assertEqual(BEHAVIOR_CONSTANTS.RAGE_WINDOW, 800);
  test.assertEqual(BEHAVIOR_CONSTANTS.RAGE_THRESHOLD, 3);
  test.assertEqual(BEHAVIOR_CONSTANTS.RAGE_DISTANCE, 60);
});

test.test('UI_CONSTANTS should have correct values', () => {
  test.assertEqual(UI_CONSTANTS.RAIL_TOGGLE_SEQUENCE, 'aaa');
  test.assertEqual(UI_CONSTANTS.DEMO_LIBRARY_SEQUENCE, 'sss');
  test.assertEqual(UI_CONSTANTS.SEQUENCE_MAX_LENGTH, 3);
  test.assertEqual(UI_CONSTANTS.RAIL_SHORTCUT_RESET_MS, 1500);
  test.assertEqual(UI_CONSTANTS.PLAYER_FRAME_MARGIN, 24);
});

test.test('BEHAVIOR_LISTENER_DEFAULTS should have correct values', () => {
  test.assert(!BEHAVIOR_LISTENER_DEFAULTS['exit-intent']);
  test.assert(BEHAVIOR_LISTENER_DEFAULTS['scroll-depth']);
  test.assert(!BEHAVIOR_LISTENER_DEFAULTS['time-delay']);
  test.assert(!BEHAVIOR_LISTENER_DEFAULTS['rage-click']);
});

test.test('BEHAVIOR_LABELS should have correct values', () => {
  test.assertEqual(BEHAVIOR_LABELS['exit-intent'], 'Exit intent');
  test.assertEqual(BEHAVIOR_LABELS['scroll-depth'], 'Scroll depth');
  test.assertEqual(BEHAVIOR_LABELS['time-delay'], 'Idle 10s');
  test.assertEqual(BEHAVIOR_LABELS['rage-click'], 'Rage click');
  test.assertEqual(BEHAVIOR_LABELS['pageview'], 'Pageview increment');
});

test.test('DEFAULT_BEHAVIOR_MESSAGE should have correct value', () => {
  test.assertEqual(DEFAULT_BEHAVIOR_MESSAGE, 'Perform a behavior in the stage or click a button to simulate it.');
});

test.test('PRESENTATION_SETTINGS should have correct values', () => {
  test.assertEqual(PRESENTATION_SETTINGS.MANUAL_LOCK_MS, 4000);
  test.assertEqual(PRESENTATION_SETTINGS.AUTO_COOLDOWN_MS, 10000);
});

test.test('getAllConstants should return all constants', () => {
  const allConstants = getAllConstants();
  test.assert(typeof allConstants.behavior === 'object');
  test.assert(typeof allConstants.ui === 'object');
  test.assert(typeof allConstants.behaviorListeners === 'object');
  test.assert(typeof allConstants.behaviorLabels === 'object');
  test.assert(typeof allConstants.defaultBehaviorMessage === 'string');
  test.assert(typeof allConstants.presentation === 'object');
});

// Test paths.js
test.test('BASE_PATHS should have correct values', () => {
  test.assertEqual(BASE_PATHS.LIPSUM_BASE, '/lipsum_local/www.lipsum.com/');
  test.assertEqual(BASE_PATHS.LIPSUM_INDEX, '/lipsum_local/www.lipsum.com/index.html');
  test.assertEqual(BASE_PATHS.THEME_OUTPUT_DIR, 'theme-generator/v1/output');
  test.assertEqual(BASE_PATHS.PREVIEW_DIR, 'preview');
  test.assertEqual(BASE_PATHS.PREVIEW_BASIC_DIR, 'preview/basic');
  test.assertEqual(BASE_PATHS.PREVIEW_V3_DIR, 'preview/v3');
  test.assertEqual(BASE_PATHS.PREVIEW_DIST_DIR, 'preview/dist');
  test.assertEqual(BASE_PATHS.PREVIEW_WIDGETS_DIR, 'preview/widgets');
  test.assertEqual(BASE_PATHS.PREVIEW_STYLES_DIR, 'preview/styles');
  test.assertEqual(BASE_PATHS.PREVIEW_THEMES_DIR, 'preview/themes');
  test.assertEqual(BASE_PATHS.PREVIEW_BACKGROUNDS_DIR, 'preview/backgrounds');
  test.assertEqual(BASE_PATHS.LEGACY_DIR, 'legacy');
  test.assertEqual(BASE_PATHS.SCRIPTS_DIR, 'scripts');
  test.assertEqual(BASE_PATHS.CONFIG_DIR, 'config');
  test.assertEqual(BASE_PATHS.LIB_DIR, 'lib');
  test.assertEqual(BASE_PATHS.TEST_DIR, 'tests');
});

test.test('FILE_PATTERNS should have correct values', () => {
  test.assertEqual(FILE_PATTERNS.THEME_CSS, '*.css');
  test.assertEqual(FILE_PATTERNS.THEME_JSON, '*.json');
  test.assertEqual(FILE_PATTERNS.JAVASCRIPT, '*.js');
  test.assertEqual(FILE_PATTERNS.HTML, '*.html');
  test.assertEqual(FILE_PATTERNS.MARKDOWN, '*.md');
  test.assertEqual(FILE_PATTERNS.PACKAGE_JSON, 'package.json');
  test.assertEqual(FILE_PATTERNS.PACKAGE_LOCK, 'package-lock.json');
});

test.test('resolveFromRoot should resolve path from project root', () => {
  const result = resolveFromRoot('test/file.js');
  test.assert(result.includes('test/file.js'));
  test.assert(result.includes(process.cwd()));
});

test.test('resolveFromDir should resolve path from specific directory', () => {
  const result = resolveFromDir('/base/dir', 'sub/file.js');
  test.assertEqual(result, '/base/dir/sub/file.js');
});

test.test('getClientThemePath should return correct path', () => {
  const result = getClientThemePath('test-client');
  test.assert(result.includes('theme-generator/v1/output/client-themes/test-client'));
});

test.test('getPreviewAssetPath should return correct path', () => {
  const result = getPreviewAssetPath('test-asset.js');
  test.assert(result.includes('preview/test-asset.js'));
});

test.test('getLegacyAssetPath should return correct path', () => {
  const result = getLegacyAssetPath('test-legacy.js');
  test.assert(result.includes('legacy/test-legacy.js'));
});

test.test('isValidPath should return true for existing file', () => {
  const result = isValidPath(__filename);
  test.assert(result, 'Should return true for existing test file');
});

test.test('isValidPath should return false for non-existing file', () => {
  const result = isValidPath('/non/existing/file.txt');
  test.assert(!result, 'Should return false for non-existing file');
});

test.test('getAllPaths should return all paths', () => {
  const allPaths = getAllPaths();
  test.assert(typeof allPaths.base === 'object');
  test.assert(typeof allPaths.patterns === 'object');
});

// Run tests
if (require.main === module) {
  const success = test.run();
  process.exit(success ? 0 : 1);
}

module.exports = { test };
