/**
 * Unit tests for logger utilities
 * @fileoverview Tests for lib/logger.js
 */

const { Logger, LOG_LEVELS, createLogger, getLogLevelFromEnv, log } = require('../../../lib/logger.js');

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
    console.log('🧪 Running logger tests...\n');
    
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

// Test LOG_LEVELS
test.test('LOG_LEVELS should have correct values', () => {
  test.assertEqual(LOG_LEVELS.DEBUG, 0);
  test.assertEqual(LOG_LEVELS.INFO, 1);
  test.assertEqual(LOG_LEVELS.WARN, 2);
  test.assertEqual(LOG_LEVELS.ERROR, 3);
});

// Test Logger constructor
test.test('Logger should create instance with default values', () => {
  const logger = new Logger();
  test.assertEqual(logger.name, 'PulseWidgets');
  test.assertEqual(logger.level, LOG_LEVELS.INFO);
  test.assert(typeof logger.context === 'object');
});

test.test('Logger should create instance with custom values', () => {
  const logger = new Logger('TestLogger', LOG_LEVELS.DEBUG);
  test.assertEqual(logger.name, 'TestLogger');
  test.assertEqual(logger.level, LOG_LEVELS.DEBUG);
});

// Test Logger.shouldLog
test.test('Logger.shouldLog should return true for higher or equal level', () => {
  const logger = new Logger('TestLogger', LOG_LEVELS.INFO);
  test.assert(logger.shouldLog(LOG_LEVELS.INFO), 'Should log INFO level');
  test.assert(logger.shouldLog(LOG_LEVELS.WARN), 'Should log WARN level');
  test.assert(logger.shouldLog(LOG_LEVELS.ERROR), 'Should log ERROR level');
});

test.test('Logger.shouldLog should return false for lower level', () => {
  const logger = new Logger('TestLogger', LOG_LEVELS.INFO);
  test.assert(!logger.shouldLog(LOG_LEVELS.DEBUG), 'Should not log DEBUG level');
});

// Test Logger.setContext
test.test('Logger.setContext should set context', () => {
  const logger = new Logger();
  logger.setContext({ key: 'value' });
  test.assertEqual(logger.context.key, 'value');
});

test.test('Logger.setContext should merge context', () => {
  const logger = new Logger();
  logger.setContext({ key1: 'value1' });
  logger.setContext({ key2: 'value2' });
  test.assertEqual(logger.context.key1, 'value1');
  test.assertEqual(logger.context.key2, 'value2');
});

// Test Logger.clearContext
test.test('Logger.clearContext should clear context', () => {
  const logger = new Logger();
  logger.setContext({ key: 'value' });
  logger.clearContext();
  test.assertEqual(Object.keys(logger.context).length, 0);
});

// Test Logger.formatLog
test.test('Logger.formatLog should format log entry correctly', () => {
  const logger = new Logger('TestLogger');
  const logEntry = logger.formatLog('INFO', 'Test message', { key: 'value' });
  
  test.assertEqual(logEntry.level, 'INFO');
  test.assertEqual(logEntry.logger, 'TestLogger');
  test.assertEqual(logEntry.message, 'Test message');
  test.assertEqual(logEntry.metadata.key, 'value');
  test.assert(typeof logEntry.timestamp === 'string');
});

// Test Logger methods (we'll mock console.log to capture output)
test.test('Logger.debug should not output when level is too high', () => {
  const logger = new Logger('TestLogger', LOG_LEVELS.INFO);
  let output = '';
  const originalLog = console.log;
  console.log = (msg) => { output += msg; };
  
  logger.debug('Debug message');
  test.assertEqual(output, '');
  
  console.log = originalLog;
});

test.test('Logger.info should output when level allows', () => {
  const logger = new Logger('TestLogger', LOG_LEVELS.INFO);
  let output = '';
  const originalLog = console.log;
  console.log = (msg) => { output += msg; };
  
  logger.info('Info message');
  test.assert(output.includes('Info message'));
  
  console.log = originalLog;
});

test.test('Logger.warn should output when level allows', () => {
  const logger = new Logger('TestLogger', LOG_LEVELS.INFO);
  let output = '';
  const originalLog = console.log;
  console.log = (msg) => { output += msg; };
  
  logger.warn('Warning message');
  test.assert(output.includes('Warning message'));
  
  console.log = originalLog;
});

test.test('Logger.error should output when level allows', () => {
  const logger = new Logger('TestLogger', LOG_LEVELS.INFO);
  let output = '';
  const originalLog = console.log;
  console.log = (msg) => { output += msg; };
  
  logger.error('Error message');
  test.assert(output.includes('Error message'));
  
  console.log = originalLog;
});

test.test('Logger.error should handle Error objects', () => {
  const logger = new Logger('TestLogger', LOG_LEVELS.INFO);
  let output = '';
  const originalLog = console.log;
  console.log = (msg) => { output += msg; };
  
  const error = new Error('Test error');
  logger.error('Error occurred', error);
  test.assert(output.includes('Error occurred'));
  test.assert(output.includes('Test error'));
  
  console.log = originalLog;
});

test.test('Logger.performance should log performance metrics', () => {
  const logger = new Logger('TestLogger', LOG_LEVELS.INFO);
  let output = '';
  const originalLog = console.log;
  console.log = (msg) => { output += msg; };
  
  logger.performance('test-operation', 150, { key: 'value' });
  test.assert(output.includes('test-operation'));
  test.assert(output.includes('150ms'));
  
  console.log = originalLog;
});

test.test('Logger.userAction should log user actions', () => {
  const logger = new Logger('TestLogger', LOG_LEVELS.INFO);
  let output = '';
  const originalLog = console.log;
  console.log = (msg) => { output += msg; };
  
  logger.userAction('button-click', { button: 'submit' });
  test.assert(output.includes('button-click'));
  test.assert(output.includes('submit'));
  
  console.log = originalLog;
});

// Test createLogger
test.test('createLogger should create logger instance', () => {
  const logger = createLogger('TestLogger', LOG_LEVELS.DEBUG);
  test.assert(logger instanceof Logger);
  test.assertEqual(logger.name, 'TestLogger');
  test.assertEqual(logger.level, LOG_LEVELS.DEBUG);
});

// Test getLogLevelFromEnv
test.test('getLogLevelFromEnv should return correct level for DEBUG', () => {
  const originalEnv = process.env.LOG_LEVEL;
  process.env.LOG_LEVEL = 'DEBUG';
  
  const level = getLogLevelFromEnv();
  test.assertEqual(level, LOG_LEVELS.DEBUG);
  
  process.env.LOG_LEVEL = originalEnv;
});

test.test('getLogLevelFromEnv should return correct level for INFO', () => {
  const originalEnv = process.env.LOG_LEVEL;
  process.env.LOG_LEVEL = 'INFO';
  
  const level = getLogLevelFromEnv();
  test.assertEqual(level, LOG_LEVELS.INFO);
  
  process.env.LOG_LEVEL = originalEnv;
});

test.test('getLogLevelFromEnv should return correct level for WARN', () => {
  const originalEnv = process.env.LOG_LEVEL;
  process.env.LOG_LEVEL = 'WARN';
  
  const level = getLogLevelFromEnv();
  test.assertEqual(level, LOG_LEVELS.WARN);
  
  process.env.LOG_LEVEL = originalEnv;
});

test.test('getLogLevelFromEnv should return correct level for ERROR', () => {
  const originalEnv = process.env.LOG_LEVEL;
  process.env.LOG_LEVEL = 'ERROR';
  
  const level = getLogLevelFromEnv();
  test.assertEqual(level, LOG_LEVELS.ERROR);
  
  process.env.LOG_LEVEL = originalEnv;
});

test.test('getLogLevelFromEnv should return default level for invalid value', () => {
  const originalEnv = process.env.LOG_LEVEL;
  process.env.LOG_LEVEL = 'INVALID';
  
  const level = getLogLevelFromEnv();
  test.assertEqual(level, LOG_LEVELS.INFO);
  
  process.env.LOG_LEVEL = originalEnv;
});

test.test('getLogLevelFromEnv should return default level when not set', () => {
  const originalEnv = process.env.LOG_LEVEL;
  delete process.env.LOG_LEVEL;
  
  const level = getLogLevelFromEnv();
  test.assertEqual(level, LOG_LEVELS.INFO);
  
  process.env.LOG_LEVEL = originalEnv;
});

// Test default logger
test.test('log should be available and functional', () => {
  test.assert(typeof log.debug === 'function');
  test.assert(typeof log.info === 'function');
  test.assert(typeof log.warn === 'function');
  test.assert(typeof log.error === 'function');
  test.assert(typeof log.performance === 'function');
  test.assert(typeof log.userAction === 'function');
});

// Run tests
if (require.main === module) {
  const success = test.run();
  process.exit(success ? 0 : 1);
}

module.exports = { test };
