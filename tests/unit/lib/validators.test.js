/**
 * Unit tests for validation utilities
 * @fileoverview Tests for lib/validators.js
 */

const { 
  FileValidator, 
  URLValidator, 
  PortValidator, 
  ThemeValidator, 
  ParameterValidator, 
  validateInput 
} = require('../../../lib/validators.js');
const fs = require('fs');
const path = require('path');

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
    console.log('🧪 Running validation tests...\n');
    
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

// Test FileValidator
test.test('FileValidator.exists should return true for existing file', () => {
  const result = FileValidator.exists(__filename);
  test.assert(result, 'Should return true for existing test file');
});

test.test('FileValidator.exists should return false for non-existing file', () => {
  const result = FileValidator.exists('/non/existing/file.txt');
  test.assert(!result, 'Should return false for non-existing file');
});

test.test('FileValidator.hasExtension should return true for correct extension', () => {
  const result = FileValidator.hasExtension('test.js', '.js');
  test.assert(result, 'Should return true for correct extension');
});

test.test('FileValidator.hasExtension should return true for one of multiple extensions', () => {
  const result = FileValidator.hasExtension('test.js', ['.js', '.ts']);
  test.assert(result, 'Should return true for one of multiple extensions');
});

test.test('FileValidator.hasExtension should return false for wrong extension', () => {
  const result = FileValidator.hasExtension('test.js', '.ts');
  test.assert(!result, 'Should return false for wrong extension');
});

test.test('FileValidator.isValidJSON should return valid result for valid JSON', () => {
  const tempFile = path.join(__dirname, 'temp.json');
  fs.writeFileSync(tempFile, '{"test": "value"}');
  
  try {
    const result = FileValidator.isValidJSON(tempFile);
    test.assert(result.valid, 'Should return valid for valid JSON');
    test.assertEqual(result.data.test, 'value');
    test.assertEqual(result.error, null);
  } finally {
    fs.unlinkSync(tempFile);
  }
});

test.test('FileValidator.isValidJSON should return invalid result for invalid JSON', () => {
  const tempFile = path.join(__dirname, 'temp.json');
  fs.writeFileSync(tempFile, '{"test": "value"');
  
  try {
    const result = FileValidator.isValidJSON(tempFile);
    test.assert(!result.valid, 'Should return invalid for invalid JSON');
    test.assert(result.error !== null && result.error !== undefined, 'Should have error message');
    if (result.error) {
      test.assert(result.error.includes('Unexpected end of JSON input') || result.error.includes('JSON'), 'Error should mention JSON parsing issue');
    }
  } finally {
    fs.unlinkSync(tempFile);
  }
});

test.test('FileValidator.isValidJSON should return invalid result for non-existing file', () => {
  const result = FileValidator.isValidJSON('/non/existing/file.json');
  test.assert(!result.valid, 'Should return invalid for non-existing file');
  test.assertEqual(result.error, 'File does not exist');
});

// Test URLValidator
test.test('URLValidator.isValid should return true for valid HTTP URL', () => {
  const result = URLValidator.isValid('http://example.com');
  test.assert(result.valid, 'Should return valid for HTTP URL');
  test.assert(result.url instanceof URL);
});

test.test('URLValidator.isValid should return true for valid HTTPS URL', () => {
  const result = URLValidator.isValid('https://example.com');
  test.assert(result.valid, 'Should return valid for HTTPS URL');
});

test.test('URLValidator.isValid should return false for invalid URL', () => {
  const result = URLValidator.isValid('not-a-url');
  test.assert(!result.valid, 'Should return invalid for invalid URL');
  test.assert(result.error.includes('Invalid URL'));
});

test.test('URLValidator.isValid should return false for unsupported protocol', () => {
  const result = URLValidator.isValid('ftp://example.com');
  test.assert(!result.valid, 'Should return invalid for unsupported protocol');
  test.assert(result.error.includes('Protocol ftp: is not supported'));
});

test.test('URLValidator.normalize should add https protocol', () => {
  const result = URLValidator.normalize('example.com');
  test.assertEqual(result, 'https://example.com');
});

test.test('URLValidator.normalize should not change URL with protocol', () => {
  const result = URLValidator.normalize('http://example.com');
  test.assertEqual(result, 'http://example.com');
});

test.test('URLValidator.normalize should handle empty string', () => {
  const result = URLValidator.normalize('');
  test.assertEqual(result, '');
});

// Test PortValidator
test.test('PortValidator.isValid should return true for valid port', () => {
  const result = PortValidator.isValid(8080);
  test.assert(result.valid, 'Should return valid for valid port');
  test.assertEqual(result.port, 8080);
});

test.test('PortValidator.isValid should return true for valid port string', () => {
  const result = PortValidator.isValid('8080');
  test.assert(result.valid, 'Should return valid for valid port string');
  test.assertEqual(result.port, 8080);
});

test.test('PortValidator.isValid should return false for port too low', () => {
  const result = PortValidator.isValid(0);
  test.assert(!result.valid, 'Should return invalid for port too low');
  test.assert(result.error.includes('Port must be between 1 and 65535'));
});

test.test('PortValidator.isValid should return false for port too high', () => {
  const result = PortValidator.isValid(65536);
  test.assert(!result.valid, 'Should return invalid for port too high');
  test.assert(result.error.includes('Port must be between 1 and 65535'));
});

test.test('PortValidator.isValid should return false for non-numeric port', () => {
  const result = PortValidator.isValid('not-a-port');
  test.assert(!result.valid, 'Should return invalid for non-numeric port');
  test.assert(result.error.includes('Port must be a number'));
});

// Test ThemeValidator
test.test('ThemeValidator.validate should return valid for valid theme', () => {
  const theme = {
    name: 'Test Theme',
    description: 'A test theme',
    colors: {
      text: '#000000',
      bg: '#ffffff',
      primary: '#007bff'
    },
    typography: {
      fontFamily: 'Arial, sans-serif'
    }
  };
  
  const result = ThemeValidator.validate(theme);
  test.assert(result.valid, 'Should return valid for valid theme');
  test.assertEqual(result.errors.length, 0);
});

test.test('ThemeValidator.validate should return invalid for theme without name', () => {
  const theme = {
    description: 'A test theme'
  };
  
  const result = ThemeValidator.validate(theme);
  test.assert(!result.valid, 'Should return invalid for theme without name');
  test.assert(result.errors.includes('Theme must have a valid name'));
});

test.test('ThemeValidator.validate should return warnings for missing recommended fields', () => {
  const theme = {
    name: 'Test Theme'
  };
  
  const result = ThemeValidator.validate(theme);
  test.assert(result.valid, 'Should return valid for theme with name');
  test.assert(result.warnings.length > 0, 'Should return warnings for missing recommended fields');
});

// Test ParameterValidator
test.test('ParameterValidator.validateArgs should validate required parameters', () => {
  const schema = {
    url: { type: 'string', required: true },
    port: { type: 'number', required: false, default: 8080 }
  };
  
  const result = ParameterValidator.validateArgs(['https://example.com'], schema);
  test.assert(result.valid, 'Should return valid for correct args');
  test.assertEqual(result.params.url, 'https://example.com');
  test.assertEqual(result.params.port, 8080);
});

test.test('ParameterValidator.validateArgs should return invalid for missing required parameter', () => {
  const schema = {
    url: { type: 'string', required: true }
  };
  
  const result = ParameterValidator.validateArgs([], schema);
  test.assert(!result.valid, 'Should return invalid for missing required parameter');
  test.assert(result.errors.includes('Required parameter url is missing'));
});

test.test('ParameterValidator.validateArgs should validate parameter types', () => {
  const schema = {
    port: { type: 'number', required: true }
  };
  
  const result = ParameterValidator.validateArgs(['not-a-number'], schema);
  test.assert(!result.valid, 'Should return invalid for wrong parameter type');
  test.assert(result.errors.includes('Parameter port must be a number'));
});

test.test('ParameterValidator.validateArgs should validate string length', () => {
  const schema = {
    name: { type: 'string', required: true, minLength: 3, maxLength: 10 }
  };
  
  const result = ParameterValidator.validateArgs(['ab'], schema);
  test.assert(!result.valid, 'Should return invalid for string too short');
  test.assert(result.errors.includes('Parameter name must be at least 3 characters'));
});

// Test validateInput
test.test('validateInput should validate file input', () => {
  const input = { file: __filename };
  const rules = { file: { extensions: ['.js'] } };
  
  const result = validateInput(input, rules);
  test.assert(result.valid, 'Should return valid for correct file input');
});

test.test('validateInput should validate URL input', () => {
  const input = { url: 'https://example.com' };
  const rules = { url: true };
  
  const result = validateInput(input, rules);
  test.assert(result.valid, 'Should return valid for correct URL input');
});

test.test('validateInput should validate port input', () => {
  const input = { port: 8080 };
  const rules = { port: true };
  
  const result = validateInput(input, rules);
  test.assert(result.valid, 'Should return valid for correct port input');
});

test.test('validateInput should validate theme input', () => {
  const input = { theme: { name: 'Test Theme' } };
  const rules = { theme: true };
  
  const result = validateInput(input, rules);
  test.assert(result.valid, 'Should return valid for correct theme input');
});

test.test('validateInput should return invalid for multiple validation failures', () => {
  const input = { 
    file: '/non/existing/file.txt',
    url: 'not-a-url',
    port: 99999
  };
  const rules = { 
    file: { extensions: ['.js'] },
    url: true,
    port: true
  };
  
  const result = validateInput(input, rules);
  test.assert(!result.valid, 'Should return invalid for multiple validation failures');
  test.assert(result.errors.length > 0, 'Should have multiple errors');
});

// Run tests
if (require.main === module) {
  const success = test.run();
  process.exit(success ? 0 : 1);
}

module.exports = { test };
