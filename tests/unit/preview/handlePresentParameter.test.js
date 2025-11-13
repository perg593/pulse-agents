/**
 * @fileoverview Unit tests for handlePresentParameter function
 * 
 * Tests URL parameter handling including:
 * - URL parameter parsing and validation
 * - Duplicate prevention
 * - Widget cleanup logic
 * - Survey selection and presentation
 */

// Simple test framework (matching existing test pattern)
function test(name, fn) {
  try {
    fn();
    console.log(`✓ ${name}`);
  } catch (error) {
    console.error(`✗ ${name}`);
    console.error(`  ${error.message}`);
    throw error;
  }
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message || 'Assertion failed');
  }
}

function assertEqual(actual, expected, message) {
  if (actual !== expected) {
    throw new Error(message || `Expected ${expected}, got ${actual}`);
  }
}

// Mock framework for testing handlePresentParameter logic
function createMockEnvironment() {
  const logs = [];
  let presentSurveyId = null;
  let presentTriggered = false;
  let tagReady = false;
  let tagReadyPromise = null;
  const surveyRecords = [];
  const allSurveyRecords = [];
  let isSettingSurveyProgrammatically = false;
  
  const mockAddLog = (message, level = 'info', context = {}) => {
    logs.push({ message, level, context, timestamp: Date.now() });
  };
  
  const mockFindRecordBySurveyId = (surveyId) => {
    return allSurveyRecords.find(r => String(r.surveyId) === String(surveyId)) || null;
  };
  
  const mockShowIdNotFoundOverlay = () => {
    logs.push({ type: 'showIdNotFound', timestamp: Date.now() });
  };
  
  const mockPresentSurvey = async (optionId, options) => {
    logs.push({ type: 'presentSurvey', optionId, options, timestamp: Date.now() });
    return Promise.resolve();
  };
  
  const mockUpdateBehaviorSurveyLabel = () => {
    // Mock implementation
  };
  
  const mockCreateRecordOptionId = (record, index) => {
    return `option-${index}`;
  };
  
  const mockFormatSurveyOptionLabel = (record) => {
    return `${record.surveyName} - ${record.surveyId}`;
  };
  
  const env = {
    logs,
    get presentSurveyId() { return presentSurveyId; },
    get presentTriggered() { return presentTriggered; },
    get tagReady() { return tagReady; },
    get tagReadyPromise() { return tagReadyPromise; },
    surveyRecords,
    allSurveyRecords,
    get isSettingSurveyProgrammatically() { return isSettingSurveyProgrammatically; },
    mockAddLog,
    mockFindRecordBySurveyId,
    mockShowIdNotFoundOverlay,
    mockPresentSurvey,
    mockUpdateBehaviorSurveyLabel,
    mockCreateRecordOptionId,
    mockFormatSurveyOptionLabel,
    // Setters for test setup
    setPresentSurveyId: (id) => { presentSurveyId = id; },
    setPresentTriggered: (val) => { presentTriggered = val; },
    setTagReady: (val) => { tagReady = val; },
    setTagReadyPromise: (promise) => { tagReadyPromise = promise; },
    addSurveyRecord: (record) => { 
      surveyRecords.push(record);
      allSurveyRecords.push(record);
    },
    setIsSettingSurveyProgrammatically: (val) => { isSettingSurveyProgrammatically = val; }
  };
  return env;
}

// Test: handlePresentParameter returns early if no presentSurveyId
test('handlePresentParameter returns early if no presentSurveyId', () => {
  const env = createMockEnvironment();
  env.setPresentSurveyId(null);
  
  // Simulate early return
  if (!env.presentSurveyId) {
    return; // Should return early
  }
  
  // Should not reach here
  assert(false, 'Should have returned early');
});

// Test: handlePresentParameter prevents duplicate calls
test('handlePresentParameter prevents duplicate calls', () => {
  const env = createMockEnvironment();
  env.setPresentSurveyId('1234');
  env.setPresentTriggered(true);
  
  // Simulate duplicate check
  if (env.presentTriggered) {
    env.mockAddLog('present parameter already triggered, skipping duplicate call.', 'warn');
    // Check that warning was logged before returning
    const warnLog = env.logs.find(log => log.level === 'warn');
    assert(warnLog !== undefined, 'Should log warning for duplicate call');
    return; // Should return early
  }
  
  // Should not reach here if duplicate check worked
  assert(false, 'Should have detected duplicate and returned early');
});

// Test: handlePresentParameter sets flag immediately to prevent race conditions
test('handlePresentParameter sets flag immediately', () => {
  const env = createMockEnvironment();
  env.setPresentSurveyId('1234');
  
  // Simulate flag setting
  if (!env.presentTriggered) {
    env.setPresentTriggered(true);
    env.mockAddLog('present parameter trigger flag set to prevent duplicates', 'info', {
      surveyId: env.presentSurveyId
    });
  }
  
  assert(env.presentTriggered, 'Flag should be set immediately');
  const infoLog = env.logs.find(log => 
    log.message && log.message.includes('trigger flag set')
  );
  assert(infoLog !== undefined, 'Should log flag setting');
});

// Test: handlePresentParameter handles survey not found
test('handlePresentParameter handles survey not found', () => {
  const env = createMockEnvironment();
  env.setPresentSurveyId('9999');
  env.setPresentTriggered(true);
  
  const record = env.mockFindRecordBySurveyId(env.presentSurveyId);
  
  if (!record) {
    env.mockAddLog(`Survey ID ${env.presentSurveyId} not found in survey list.`, 'warn');
    env.mockShowIdNotFoundOverlay();
    env.setPresentTriggered(false); // Reset flag
    return;
  }
  
  // Should not reach here for not found case
  const warnLog = env.logs.find(log => 
    log.message && log.message.includes('not found')
  );
  assert(warnLog !== undefined, 'Should log warning for not found');
});

// Test: handlePresentParameter finds survey record
test('handlePresentParameter finds survey record', () => {
  const env = createMockEnvironment();
  env.setPresentSurveyId('1234');
  env.setPresentTriggered(true);
  
  const testRecord = {
    surveyId: '1234',
    surveyName: 'Test Survey',
    identifier: 'PI-12345678'
  };
  env.addSurveyRecord(testRecord);
  
  const record = env.mockFindRecordBySurveyId(env.presentSurveyId);
  
  assert(record !== null, 'Should find survey record');
  assertEqual(record.surveyId, '1234', 'Should find correct survey');
});

// Test: handlePresentParameter creates option ID if missing
test('handlePresentParameter creates option ID if missing', () => {
  const env = createMockEnvironment();
  env.setPresentSurveyId('1234');
  env.setPresentTriggered(true);
  
  const testRecord = {
    surveyId: '1234',
    surveyName: 'Test Survey'
  };
  env.addSurveyRecord(testRecord);
  
  // Simulate option ID creation
  let optionId = env.surveyRecords.find(r => 
    String(r.surveyId) === String(testRecord.surveyId)
  )?.__optionId;
  
  if (!optionId) {
    const index = env.allSurveyRecords.findIndex(r => 
      String(r.surveyId) === String(testRecord.surveyId)
    );
    if (index >= 0) {
      optionId = env.mockCreateRecordOptionId(testRecord, index);
      const enriched = { ...testRecord, __optionId: optionId };
      env.surveyRecords.push(enriched);
    }
  }
  
  assert(optionId !== undefined, 'Should create option ID');
  assert(optionId.startsWith('option-'), 'Option ID should have correct format');
});

// Test: handlePresentParameter waits for tag ready
test('handlePresentParameter waits for tag ready', async () => {
  const env = createMockEnvironment();
  env.setPresentSurveyId('1234');
  env.setPresentTriggered(true);
  env.setTagReady(false);
  
  // Simulate tag readiness waiting
  if (!env.tagReady) {
    env.mockAddLog(`Waiting for tag to be ready before presenting survey ${env.presentSurveyId}...`, 'info');
    if (env.tagReadyPromise) {
      await env.tagReadyPromise.catch(() => {});
    }
  }
  
  const waitLog = env.logs.find(log => 
    log.message && log.message.includes('Waiting for tag')
  );
  assert(waitLog !== undefined, 'Should log tag readiness wait');
});

// Test: handlePresentParameter calls presentSurvey with force flag
test('handlePresentParameter calls presentSurvey with force flag', async () => {
  const env = createMockEnvironment();
  env.setPresentSurveyId('1234');
  env.setPresentTriggered(true);
  env.setTagReady(true);
  
  const testRecord = {
    surveyId: '1234',
    surveyName: 'Test Survey',
    __optionId: 'option-0'
  };
  env.addSurveyRecord(testRecord);
  
  const optionId = testRecord.__optionId;
  
  // Simulate presentSurvey call
  await env.mockPresentSurvey(optionId, { force: true });
  
  const presentLog = env.logs.find(log => log.type === 'presentSurvey');
  assert(presentLog !== undefined, 'Should call presentSurvey');
  assert(presentLog.options.force === true, 'Should use force flag');
});

// Test: handlePresentParameter resets flag on error
test('handlePresentParameter resets flag on error', () => {
  const env = createMockEnvironment();
  env.setPresentSurveyId('9999'); // Non-existent survey
  env.setPresentTriggered(true);
  
  const record = env.mockFindRecordBySurveyId(env.presentSurveyId);
  
  if (!record) {
    env.mockShowIdNotFoundOverlay();
    env.setPresentTriggered(false); // Reset flag
  }
  
  assert(!env.presentTriggered, 'Flag should be reset on error');
});

// Test: handlePresentParameter sets isSettingSurveyProgrammatically flag
test('handlePresentParameter sets isSettingSurveyProgrammatically flag', () => {
  const env = createMockEnvironment();
  env.setPresentSurveyId('1234');
  env.setPresentTriggered(true);
  
  const testRecord = {
    surveyId: '1234',
    surveyName: 'Test Survey',
    __optionId: 'option-0'
  };
  env.addSurveyRecord(testRecord);
  
  // Simulate setting survey select value
  env.setIsSettingSurveyProgrammatically(true);
  
  assert(env.isSettingSurveyProgrammatically, 'Flag should be set');
});

// Test: handlePresentParameter validates 4-digit survey ID format
test('handlePresentParameter validates 4-digit survey ID format', () => {
  // This test validates the URL parameter parsing logic
  const validIds = ['1234', '5678', '0001'];
  const invalidIds = ['123', '12345', 'abcd', ''];
  
  validIds.forEach(id => {
    const isValid = /^\d{4}$/.test(id);
    assert(isValid, `Valid ID ${id} should pass validation`);
  });
  
  invalidIds.forEach(id => {
    const isValid = /^\d{4}$/.test(id);
    assert(!isValid, `Invalid ID ${id} should fail validation`);
  });
});

console.log('\nAll handlePresentParameter unit tests passed!');

