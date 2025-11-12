/**
 * @fileoverview Presentation Helper Functions
 * 
 * Extracted helper functions from presentSurvey to improve testability
 * and maintainability. These functions handle individual steps of the
 * presentation process.
 */

/**
 * Validate survey option ID and find record
 * @param {string} optionId - Option ID to validate
 * @param {Function} findRecordByOptionId - Function to find record
 * @param {Function} addLog - Logging function
 * @param {string} operationKey - Operation key for logging
 * @returns {Object|null} Survey record or null if invalid
 */
function validateSurveyOption(optionId, findRecordByOptionId, addLog, operationKey) {
  const key = String(optionId || '').trim();
  if (!key) {
    addLog('No survey id selected.', 'warn', { operationId: operationKey });
    return null;
  }

  const record = findRecordByOptionId(key);
  if (!record) {
    addLog(
      `No survey record found for option ${key}`,
      'warn',
      { operationId: operationKey, optionId: key }
    );
    return null;
  }

  return record;
}

/**
 * Check for duplicate presentation for present parameter scenario
 * @param {Object} record - Survey record
 * @param {string|null} presentSurveyId - Present parameter survey ID
 * @param {boolean} presentTriggered - Whether present parameter was triggered
 * @param {Object|null} activePresentOperation - Active operation tracking
 * @param {string|null} lastPresentedOptionId - Last presented option ID
 * @param {Object} options - Presentation options
 * @param {Function} addLog - Logging function
 * @param {string} operationKey - Operation key for logging
 * @returns {boolean} True if duplicate should be skipped
 */
function checkPresentParameterDuplicate(
  record,
  presentSurveyId,
  presentTriggered,
  activePresentOperation,
  lastPresentedOptionId,
  options,
  addLog,
  operationKey
) {
  if (!presentSurveyId || String(record.surveyId) !== String(presentSurveyId)) {
    return false;
  }

  const optionIdStr = record.__optionId || String(record.surveyId || '');
  
  // Check if operation already in progress
  if (presentTriggered && 
      activePresentOperation && 
      activePresentOperation.surveyId === record.surveyId && 
      !options.forceReload && 
      !options.allowDuplicate) {
    addLog(
      `present parameter survey ${record.surveyId} presentation already in progress; skipping duplicate presentSurvey call.`,
      'info',
      { operationId: operationKey, surveyId: record.surveyId, activeOperationId: activePresentOperation.key }
    );
    return true;
  }
  
  // Check if already completed
  if (presentTriggered && 
      lastPresentedOptionId === optionIdStr && 
      !options.force && 
      !options.forceReload && 
      !options.allowDuplicate) {
    addLog(
      `present parameter survey ${record.surveyId} already presented; skipping duplicate presentSurvey call.`,
      'info',
      { operationId: operationKey, surveyId: record.surveyId }
    );
    return true;
  }

  return false;
}

/**
 * Create cancellation token for operation
 * @returns {Object} Cancellation token with cancel() method and cancelled getter
 */
function createCancelToken() {
  let cancelled = false;
  return {
    cancel: () => { cancelled = true; },
    get cancelled() { return cancelled; }
  };
}

/**
 * Create operation tracking object
 * @param {number} operationId - Operation ID
 * @param {string} optionId - Option ID
 * @param {Object} record - Survey record
 * @param {Object} cancelToken - Cancellation token
 * @returns {Object} Operation tracking object
 */
function createOperationTracking(operationId, optionId, record, cancelToken) {
  return {
    id: operationId,
    key: `present-${operationId}`,
    optionId,
    surveyId: record.surveyId,
    cancelToken,
    startTime: Date.now()
  };
}

/**
 * Ensure background page is loaded
 * @param {Object} record - Survey record
 * @param {Object} options - Options with force and skipBridgeLoad flags
 * @param {Function} ensureBackgroundForRecord - Function to ensure background
 * @param {Function} addLog - Logging function
 * @param {string} operationKey - Operation key for logging
 * @param {Function} checkCancelled - Function to check if cancelled
 * @returns {Promise<void>}
 */
async function ensureBackground(
  record,
  options,
  ensureBackgroundForRecord,
  addLog,
  operationKey,
  checkCancelled
) {
  if (checkCancelled()) {
    addLog(`Operation cancelled`, 'warn', { operationId: operationKey });
    return;
  }

  addLog(
    `Step 1/4: Ensuring background page...`,
    'info',
    { operationId: operationKey, step: 1, total: 4, surveyId: record.surveyId }
  );

  await ensureBackgroundForRecord(record, {
    force: Boolean(options.force),
    skipBridgeLoad: Boolean(options.skipBridgeLoad)
  });
}

/**
 * Ensure player iframe is loaded and ready
 * @param {Object} record - Survey record
 * @param {Object} options - Options with force, forceReload flags
 * @param {Function} ensurePlayerLoadedForRecord - Function to ensure player
 * @param {Function} waitForPlayerBridgeReady - Function to wait for bridge
 * @param {Function} addLog - Logging function
 * @param {string} operationKey - Operation key for logging
 * @param {Function} checkCancelled - Function to check if cancelled
 * @param {boolean} surveyBridgeReady - Whether bridge is ready
 * @returns {Promise<Object>} Ensure result object
 */
async function ensurePlayer(
  record,
  options,
  ensurePlayerLoadedForRecord,
  waitForPlayerBridgeReady,
  addLog,
  operationKey,
  checkCancelled,
  surveyBridgeReady
) {
  if (checkCancelled()) return null;

  addLog(
    `Step 2/4: Ensuring player iframe...`,
    'info',
    { operationId: operationKey, step: 2, total: 4, surveyId: record.surveyId }
  );

  const ensureResult = ensurePlayerLoadedForRecord(record, {
    forceReload: Boolean(options.forceReload || options.force),
    excludePresent: true
  });

  // Wait for player bridge to be ready
  if (ensureResult.reloaded || !surveyBridgeReady) {
    addLog(
      `Waiting for player bridge ready...`,
      'info',
      { operationId: operationKey, surveyId: record.surveyId }
    );
    await waitForPlayerBridgeReady(10000);
  }

  return ensureResult;
}

/**
 * Ensure tag is ready
 * @param {boolean} tagReady - Whether tag is ready
 * @param {string} tagState - Current tag state
 * @param {string} TAG_STATES_READY - Ready state constant
 * @param {Function} bootPulseTag - Function to boot tag
 * @param {Function} addLog - Logging function
 * @param {string} operationKey - Operation key for logging
 * @param {Function} checkCancelled - Function to check if cancelled
 * @returns {Promise<void>}
 */
async function ensureTagReady(
  tagReady,
  tagState,
  TAG_STATES_READY,
  bootPulseTag,
  addLog,
  operationKey,
  checkCancelled
) {
  if (checkCancelled()) return;

  addLog(
    `Step 3/4: Ensuring tag ready...`,
    'info',
    { operationId: operationKey, step: 3, total: 4 }
  );

  if (!tagReady || tagState !== TAG_STATES_READY) {
    addLog(
      `Tag not ready; booting...`,
      'info',
      { operationId: operationKey }
    );
    await bootPulseTag();
  }
}

/**
 * Apply identifier to tag
 * @param {Object} record - Survey record
 * @param {Function} resolveIdentifier - Function to resolve identifier
 * @param {Function} applyIdentifier - Function to apply identifier
 * @param {Function} addLog - Logging function
 * @param {string} operationKey - Operation key for logging
 */
function applySurveyIdentifier(record, resolveIdentifier, applyIdentifier, addLog, operationKey) {
  addLog(
    `Step 4/4: Applying identifier...`,
    'info',
    { operationId: operationKey, step: 4, total: 4 }
  );

  const trimmedQueue = (typeof window !== 'undefined' && window.pi && Array.isArray(window.pi.commands))
    ? window.pi.commands.map((args) => args[0])
    : [];

  addLog(
    `pi() queue: ${trimmedQueue.join(', ') || 'empty'}`,
    'info',
    { operationId: operationKey, queue: trimmedQueue }
  );

  applyIdentifier(resolveIdentifier(record));
}

module.exports = {
  validateSurveyOption,
  checkPresentParameterDuplicate,
  createCancelToken,
  createOperationTracking,
  ensureBackground,
  ensurePlayer,
  ensureTagReady,
  applySurveyIdentifier
};

