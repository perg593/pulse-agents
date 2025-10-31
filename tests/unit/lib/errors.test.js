/**
 * Unit tests for error handling utilities
 * @fileoverview Tests for lib/errors.js
 */

const { 
  PulseWidgetsError, 
  ThemeGenerationError, 
  ValidationError, 
  ConfigError, 
  FileOperationError, 
  NetworkError, 
  ProcessError, 
  ErrorFactory, 
  ErrorHandler 
} = require('../../../lib/errors.js');

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
    console.log('🧪 Running error handling tests...\n');
    
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

// Test PulseWidgetsError
test.test('PulseWidgetsError should create error with message', () => {
  const error = new PulseWidgetsError('Test error');
  test.assertEqual(error.message, 'Test error');
  test.assertEqual(error.name, 'PulseWidgetsError');
  test.assertEqual(error.code, null);
});

test.test('PulseWidgetsError should create error with code and metadata', () => {
  const error = new PulseWidgetsError('Test error', 'TEST_CODE', { key: 'value' });
  test.assertEqual(error.message, 'Test error');
  test.assertEqual(error.code, 'TEST_CODE');
  test.assertEqual(error.metadata.key, 'value');
  test.assert(typeof error.timestamp === 'string');
});

// Test ThemeGenerationError
test.test('ThemeGenerationError should create theme error', () => {
  const error = new ThemeGenerationError('Theme failed', 'test-theme', ['error1', 'error2']);
  test.assertEqual(error.message, 'Theme failed');
  test.assertEqual(error.themeName, 'test-theme');
  test.assertEqual(error.errors.length, 2);
  test.assertEqual(error.code, 'THEME_GENERATION_ERROR');
});

// Test ValidationError
test.test('ValidationError should create validation error', () => {
  const error = new ValidationError('Invalid input', 'field', 'value');
  test.assertEqual(error.message, 'Invalid input');
  test.assertEqual(error.field, 'field');
  test.assertEqual(error.value, 'value');
  test.assertEqual(error.code, 'VALIDATION_ERROR');
});

// Test ConfigError
test.test('ConfigError should create config error', () => {
  const error = new ConfigError('Config failed', 'configKey');
  test.assertEqual(error.message, 'Config failed');
  test.assertEqual(error.configKey, 'configKey');
  test.assertEqual(error.code, 'CONFIG_ERROR');
});

// Test FileOperationError
test.test('FileOperationError should create file error', () => {
  const error = new FileOperationError('File failed', '/path/file', 'read');
  test.assertEqual(error.message, 'File failed');
  test.assertEqual(error.filePath, '/path/file');
  test.assertEqual(error.operation, 'read');
  test.assertEqual(error.code, 'FILE_OPERATION_ERROR');
});

// Test NetworkError
test.test('NetworkError should create network error', () => {
  const error = new NetworkError('Network failed', 'https://example.com', 404);
  test.assertEqual(error.message, 'Network failed');
  test.assertEqual(error.url, 'https://example.com');
  test.assertEqual(error.statusCode, 404);
  test.assertEqual(error.code, 'NETWORK_ERROR');
});

// Test ProcessError
test.test('ProcessError should create process error', () => {
  const error = new ProcessError('Process failed', 'test-process', 12345);
  test.assertEqual(error.message, 'Process failed');
  test.assertEqual(error.processName, 'test-process');
  test.assertEqual(error.pid, 12345);
  test.assertEqual(error.code, 'PROCESS_ERROR');
});

// Test ErrorFactory
test.test('ErrorFactory should create theme generation error', () => {
  const error = ErrorFactory.themeGeneration('Theme failed', 'test-theme', ['error1']);
  test.assert(error instanceof ThemeGenerationError);
  test.assertEqual(error.message, 'Theme failed');
  test.assertEqual(error.themeName, 'test-theme');
});

test.test('ErrorFactory should create validation error', () => {
  const error = ErrorFactory.validation('Invalid input', 'field', 'value');
  test.assert(error instanceof ValidationError);
  test.assertEqual(error.message, 'Invalid input');
  test.assertEqual(error.field, 'field');
});

test.test('ErrorFactory should create config error', () => {
  const error = ErrorFactory.config('Config failed', 'configKey');
  test.assert(error instanceof ConfigError);
  test.assertEqual(error.message, 'Config failed');
  test.assertEqual(error.configKey, 'configKey');
});

test.test('ErrorFactory should create file operation error', () => {
  const error = ErrorFactory.fileOperation('File failed', '/path/file', 'read');
  test.assert(error instanceof FileOperationError);
  test.assertEqual(error.message, 'File failed');
  test.assertEqual(error.filePath, '/path/file');
});

test.test('ErrorFactory should create network error', () => {
  const error = ErrorFactory.network('Network failed', 'https://example.com', 404);
  test.assert(error instanceof NetworkError);
  test.assertEqual(error.message, 'Network failed');
  test.assertEqual(error.url, 'https://example.com');
});

test.test('ErrorFactory should create process error', () => {
  const error = ErrorFactory.process('Process failed', 'test-process', 12345);
  test.assert(error instanceof ProcessError);
  test.assertEqual(error.message, 'Process failed');
  test.assertEqual(error.processName, 'test-process');
});

// Test ErrorHandler
test.test('ErrorHandler should format custom error', () => {
  const error = new ThemeGenerationError('Theme failed', 'test-theme');
  const formatted = ErrorHandler.formatError(error, { context: 'test' });
  
  test.assertEqual(formatted.name, 'ThemeGenerationError');
  test.assertEqual(formatted.message, 'Theme failed');
  test.assertEqual(formatted.code, 'THEME_GENERATION_ERROR');
  test.assert(typeof formatted.timestamp === 'string');
  test.assertEqual(formatted.context.context, 'test');
});

test.test('ErrorHandler should format regular error', () => {
  const error = new Error('Regular error');
  const formatted = ErrorHandler.formatError(error, { context: 'test' });
  
  test.assertEqual(formatted.name, 'Error');
  test.assertEqual(formatted.message, 'Regular error');
  test.assertEqual(formatted.code, null);
  test.assert(typeof formatted.timestamp === 'string');
});

test.test('ErrorHandler should check if error is recoverable', () => {
  const validationError = new ValidationError('Invalid input');
  const networkError = new NetworkError('Network failed');
  const configError = new ConfigError('Config failed');
  
  test.assert(!ErrorHandler.isRecoverable(validationError));
  test.assert(ErrorHandler.isRecoverable(networkError));
  test.assert(!ErrorHandler.isRecoverable(configError));
});

test.test('ErrorHandler should get user-friendly message', () => {
  const themeError = new ThemeGenerationError('Theme failed');
  const validationError = new ValidationError('Invalid input');
  const regularError = new Error('Regular error');
  
  test.assertEqual(ErrorHandler.getUserMessage(themeError), 'Theme generation failed: Theme failed');
  test.assertEqual(ErrorHandler.getUserMessage(validationError), 'Invalid input: Invalid input');
  test.assertEqual(ErrorHandler.getUserMessage(regularError), 'Regular error');
});

// Run tests
if (require.main === module) {
  const success = test.run();
  process.exit(success ? 0 : 1);
}

module.exports = { test };
