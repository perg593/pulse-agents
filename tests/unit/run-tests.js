#!/usr/bin/env node

/**
 * Test runner for pulse widgets utilities
 * @fileoverview Runs all unit tests and provides summary
 */

const fs = require('fs');
const path = require('path');

// Test files to run
const TEST_FILES = [
  'lib/errors.test.js',
  'lib/validators.test.js', 
  'lib/logger.test.js',
  'config/config.test.js'
];

// Colors for console output
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m'
};

function colorize(text, color) {
  return `${colors[color]}${text}${colors.reset}`;
}

function runTestFile(testFile) {
  const testPath = path.join(__dirname, testFile);
  
  if (!fs.existsSync(testPath)) {
    console.log(colorize(`❌ Test file not found: ${testFile}`, 'red'));
    return { passed: 0, failed: 1, total: 1 };
  }
  
  try {
    console.log(colorize(`\n🧪 Running ${testFile}...`, 'cyan'));
    
    // Capture console output
    let output = '';
    const originalLog = console.log;
    console.log = (msg) => { output += msg + '\n'; };
    
    // Run the test
    const testModule = require(testPath);
    const success = testModule.test.run();
    
    // Restore console.log
    console.log = originalLog;
    
    // Parse results from output
    const lines = output.split('\n');
    let passed = 0;
    let failed = 0;
    
    for (const line of lines) {
      if (line.includes('✅')) {
        passed++;
      } else if (line.includes('❌')) {
        failed++;
      }
    }
    
    const total = passed + failed;
    
    if (success) {
      console.log(colorize(`✅ ${testFile} completed successfully`, 'green'));
    } else {
      console.log(colorize(`❌ ${testFile} failed`, 'red'));
    }
    
    return { passed, failed, total };
    
  } catch (error) {
    console.log(colorize(`❌ Error running ${testFile}: ${error.message}`, 'red'));
    return { passed: 0, failed: 1, total: 1 };
  }
}

function main() {
  console.log(colorize('🚀 Pulse Widgets Test Runner', 'bright'));
  console.log(colorize('============================', 'bright'));
  
  let totalPassed = 0;
  let totalFailed = 0;
  let totalTests = 0;
  
  for (const testFile of TEST_FILES) {
    const results = runTestFile(testFile);
    totalPassed += results.passed;
    totalFailed += results.failed;
    totalTests += results.total;
  }
  
  console.log(colorize('\n📊 Test Summary', 'bright'));
  console.log(colorize('===============', 'bright'));
  console.log(`Total tests: ${totalTests}`);
  console.log(colorize(`Passed: ${totalPassed}`, 'green'));
  console.log(colorize(`Failed: ${totalFailed}`, 'red'));
  
  const successRate = totalTests > 0 ? ((totalPassed / totalTests) * 100).toFixed(1) : 0;
  console.log(`Success rate: ${successRate}%`);
  
  if (totalFailed === 0) {
    console.log(colorize('\n🎉 All tests passed!', 'green'));
    process.exit(0);
  } else {
    console.log(colorize('\n💥 Some tests failed!', 'red'));
    process.exit(1);
  }
}

// Run tests if this file is executed directly
if (require.main === module) {
  main();
}

module.exports = { runTestFile, main };
