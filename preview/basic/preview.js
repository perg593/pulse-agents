import { createSurveyBridge } from '../app/survey/bridge.js';
import { resolveProxyUrl, getProxyOrigin } from '../app/services/proxy.js';
import { bus, installBehaviorLogProxy } from './lib/behaviorBus.js';
import { createScrollDepthEngine } from './lib/scrollDepthTarget.js';
import { RulesStore } from './lib/rulesStore.js';
import { PresentationController } from './lib/presentationController.js';
import { attachResponses } from './lib/responsesDriver.js';
import {
  BEHAVIOR_CONSTANTS,
  UI_CONSTANTS,
  BEHAVIOR_LISTENER_DEFAULTS,
  BEHAVIOR_LABELS,
  DEFAULT_BEHAVIOR_MESSAGE,
  PRESENTATION_SETTINGS,
  PATH_CONSTANTS
} from '../../config/constants-browser.js';

const LIPSUM_BASE = PATH_CONSTANTS.LIPSUM_BASE;
const LIPSUM_INDEX = PATH_CONSTANTS.LIPSUM_INDEX;
const SHEET_CSV_URL = 'https://docs.google.com/spreadsheets/d/17k7uKh_TGMNy0hJblfImUGmmbkW_71rDbYlIEfya5Z8/gviz/tq?tqx=out:csv&gid=0';
const DEFAULT_IDENTIFIER = 'PI-81598442';
const DEFAULT_HOST_URL = 'https://www.pulseinsights.com/agents';
const DEFAULT_PULSE_HOST = 'survey.pulseinsights.com';
const PROXY_ORIGIN = (window.__PI_PROXY_ORIGIN__ || '').trim();
const DEFAULT_TAG_SRC = 'https://js.pulseinsights.com/surveys.js';
const INLINE_PATTERN = /inline/i;
const RAIL_TOGGLE_SEQUENCE = UI_CONSTANTS.RAIL_TOGGLE_SEQUENCE;
const DEMO_LIBRARY_SEQUENCE = UI_CONSTANTS.DEMO_LIBRARY_SEQUENCE;
const SEQUENCE_MAX_LENGTH = UI_CONSTANTS.SEQUENCE_MAX_LENGTH;
const RAIL_SHORTCUT_RESET_MS = UI_CONSTANTS.RAIL_SHORTCUT_RESET_MS;
const PREVIEW_BUILD_STAMP = '2025-02-15T17:30:00Z';

// Tag lifecycle states
const TAG_STATES = {
  NOT_STARTED: 'not-started',
  LOADING: 'loading',
  READY: 'ready',
  FAILED: 'failed',
  RETRYING: 'retrying'
};

// Tag configuration
const MAX_TAG_RETRIES = 3;
const TAG_TIMEOUT = 15000; // Increased from 10s
const TAG_RETRY_DELAYS = [1000, 2000, 5000]; // Progressive delays

const FALLBACK_SURVEYS = [
  {
    surveyId: '7990',
    surveyName: 'Cyberhill Partners – Experience Agent Demo',
    accountName: 'Pulse Insights',
    identifier: DEFAULT_IDENTIFIER,
    surveyTypeName: 'Overlay',
    demoFor: '',
    demoCode: '',
    url: 'https://www.cyberhillpartners.com',
    backgroundUrl: 'https://www.cyberhillpartners.com',
    enabled: true
  }
];

const siteRoot = document.getElementById('site-root');
const logPanel = document.getElementById('log-panel');
const logList = document.getElementById('log-list');
const closeLogBtn = document.getElementById('close-log-btn');
const surveySelect = document.getElementById('survey-select');
const presentBtn = document.getElementById('present-btn');
const controlRail = document.getElementById('control-rail');
const railToggle = document.getElementById('rail-toggle');
const demoSubtitle = document.getElementById('demo-subtitle');
const accordionRoot = document.getElementById('rail-accordion');
const backgroundInput = document.getElementById('background-input');
const behaviorSurveyLabel = document.getElementById('behavior-survey-label');
const behaviorPresentBtn = document.getElementById('behavior-present-btn');
const behaviorButtonList = document.getElementById('behavior-button-list');
const behaviorMessage = document.getElementById('behavior-message');
const behaviorStage = document.getElementById('behavior-stage');
const behaviorRageBtn = document.getElementById('behavior-rage-btn');
const behaviorLab = document.getElementById('behavior-lab');
const behaviorToggle = document.getElementById('behavior-toggle');
const behaviorCloseBtn = document.getElementById('behavior-close-btn');
const behaviorListenerList = document.getElementById('behavior-listener-list');
const behaviorBanner = document.getElementById('behavior-banner');
const demoDirectory = document.getElementById('demo-directory');
const demoDirectoryBackdrop = document.getElementById('demo-directory-backdrop');
const demoDirectoryList = document.getElementById('demo-directory-list');
const demoDirectoryClose = document.getElementById('demo-directory-close');
const behaviorRulesStore = RulesStore.shared();
behaviorRulesStore.replaceWith([]);
const scrollDepthEngine = createScrollDepthEngine({
  target: behaviorStage,
  logEvery: 10,
  bus,
  log: (message) => logBehavior(message)
});
scrollDepthEngine.start();
const stylesheetRegistry = new Map();
// Track if the background page returned a 403 error
let backgroundPage403 = false;
const overlayContainer = (() => {
  const container = document.createElement('div');
  container.className = 'survey-overlay-container';
  if (siteRoot) {
    siteRoot.appendChild(container);
  }
  container.style.visibility = 'hidden';
  container.style.opacity = '0';
  container.style.pointerEvents = 'none';
  return container;
})();

// Create "ID Not Found" overlay element
const idNotFoundOverlay = (() => {
  const overlay = document.createElement('div');
  overlay.className = 'pi-present-id-not-found';
  overlay.textContent = 'ID Not Found';
  overlay.setAttribute('aria-live', 'polite');
  overlay.setAttribute('aria-atomic', 'true');
  if (siteRoot) {
    siteRoot.appendChild(overlay);
  }
  return overlay;
})();
const surveyBridge = createSurveyBridge({
  container: overlayContainer,
  onReady: handlePlayerReady,
  onStatus: handlePlayerStatus,
  onStateChange: handleBridgeStateChange
});

const presenter = new PresentationController(
  {
    present: (id, meta = {}) => {
      if (typeof presentSurvey === 'function') {
        return presentSurvey(id, {
          force: Boolean(meta.force),
          allowDuplicate: Boolean(meta.allowDuplicate),
          source: meta.source || 'auto'
        });
      }
      return surveyBridge.present(id);
    }
  },
  { manualLockMs: PRESENTATION_SETTINGS.MANUAL_LOCK_MS, autoCooldownMs: PRESENTATION_SETTINGS.AUTO_COOLDOWN_MS }
);

if (typeof window !== 'undefined') {
  window.__PI_PRESENTER__ = presenter;
}
attachResponses({
  presenter,
  rules: () => behaviorRulesStore.all(),
  bus,
  getPercent: () => scrollDepthEngine.getPercent()
});

const TRIGGER_CONFIG = [
  { id: 'present-selected', label: 'Present Selected Survey' },
  { id: 'exit-intent', label: 'Simulate Exit Intent' },
  { id: 'rage-click', label: 'Simulate Rage Click' },
  { id: 'scroll-depth', label: 'Simulate Scroll Depth' },
  { id: 'time-delay', label: 'Simulate Timer' },
  { id: 'pageview', label: 'Increment Pageview' }
];
const BEHAVIOR_IDLE_MS = BEHAVIOR_CONSTANTS.IDLE_MS;
const BEHAVIOR_OVERLAY_AUTO_HIDE_MS = BEHAVIOR_CONSTANTS.OVERLAY_AUTO_HIDE_MS;
const BEHAVIOR_SCROLL_TRIGGER = BEHAVIOR_CONSTANTS.SCROLL_TRIGGER;
const BEHAVIOR_SCROLL_RESET = BEHAVIOR_CONSTANTS.SCROLL_RESET;
const BEHAVIOR_RAGE_WINDOW = BEHAVIOR_CONSTANTS.RAGE_WINDOW;
const BEHAVIOR_RAGE_THRESHOLD = BEHAVIOR_CONSTANTS.RAGE_THRESHOLD;
const BEHAVIOR_RAGE_DISTANCE = BEHAVIOR_CONSTANTS.RAGE_DISTANCE;
const BEHAVIOR_LISTENER_DEFAULTS_CONFIG = BEHAVIOR_LISTENER_DEFAULTS;
const BEHAVIOR_LABELS_CONFIG = BEHAVIOR_LABELS;
const DEFAULT_BEHAVIOR_MESSAGE_CONFIG = DEFAULT_BEHAVIOR_MESSAGE;
function baseBehaviorLog(message, level = 'info') {
  addLog(`[behavior] ${message}`, level);
}
const logBehavior = installBehaviorLogProxy({ logBehavior: baseBehaviorLog });
/**
 * Flag to prevent simulation events from being processed by behavior detectors.
 * When true, behavior detector handlers (handlePointerLeave, handleRagePointer, handleScroll, noteBehaviorActivity)
 * will return early without processing events. This prevents simulation functions from triggering duplicate behavior detections.
 * @type {boolean}
 */
let isSimulatingBehavior = false;

const params = new URLSearchParams(window.location.search);
const demoCodeFilter = (params.get('demo') || params.get('demo_code') || '').trim().toLowerCase();
const demoForFilterRaw = (params.get('demo_for') || '').trim();
const demoForFilterParam = demoForFilterRaw ? demoForFilterRaw.toLowerCase() : '';
const demoDismissed = params.get('demo_dismissed') === 'true';
const demoForFilter = demoDismissed ? '' : demoForFilterParam;

// Parse present parameter (4-digit survey ID)
const presentParam = (params.get('present') || '').trim();
const presentSurveyId = (() => {
  if (!presentParam) return null;
  // Validate: must be exactly 4 digits
  if (!/^\d{4}$/.test(presentParam)) return null;
  return presentParam;
})();

const loadedAssets = new Set();
let tagReady = false;
// Tag state management
let tagState = TAG_STATES.NOT_STARTED;
let tagReadyPromise = null;
let tagRetryCount = 0;
let tagHealthCheckInterval = null;
let pendingPresent = null;
// Operation tracking
let activePresentOperation = null;
let presentOperationId = 0;
let surveyBridgeReady = false;
let lastPresentedOptionId = null;
// Track if present parameter has already triggered a presentation to prevent double triggers
let presentTriggered = false;
let logVisible = false;
let railOpen = false;
let sequenceBuffer = '';
let sequenceTimeout = null;
let allSurveyRecords = [];
let surveyRecords = [];
let demoSubtitleText = '';
let currentIdentifier = DEFAULT_IDENTIFIER;
let identifierDirty = true;
let identifierApplied = false;
let blockAutoPresent = true;
let presentGuardInterval = null;
let currentThemeId = null;
let currentThemeHref = null;
let demoDirectoryActive = false;
let demoDirectoryOptions = [];
let lastDemoDirectoryFocus = null;
let currentBackgroundUrl = DEFAULT_HOST_URL;
// Flag to prevent change event handler from running when setting survey programmatically
let isSettingSurveyProgrammatically = false;
let playerFrameEl = null;
let playerWidgetRect = null;
let playerViewportSize = { width: 0, height: 0 };
let playerMode = 'overlay';
let lastSurveyRecord = null;
let overlayPlacementHint = 'CENTER';
let overlayFallbackActive = false;
let overlayFallbackLogged = false;
const PLAYER_FRAME_MARGIN = 24;
let overlayLayoutRaf = null;
let overlayLayoutTimeout = null;
let widgetFallbackTimer = null;
let widgetFallbackApplied = false;
let iframePositioned = false;
let pendingGeometryUpdates = [];
let geometryRetryCount = 0;
let geometryRetryTimeout = null;
const MAX_GEOMETRY_RETRIES = 3;
const GEOMETRY_RETRY_DELAYS = [500, 1000, 2000];
let corsErrorLogged = false;
const behaviorButtons = new Map();
let behaviorMessageTimeout = null;
let behaviorStageTimeout = null;
let behaviorIdleTimer = null;
let behaviorScrollArmed = true;
let behaviorRageClicks = [];
let behaviorOverlayVisible = false;
let behaviorEscBound = false;
const behaviorListenerState = { ...BEHAVIOR_LISTENER_DEFAULTS_CONFIG };
let behaviorBannerTimeout = null;
let behaviorScrollProgress = 0;
let behaviorOverlayHideTimeout = null;

function isBehaviorListenerEnabled(listenerId) {
  return Boolean(behaviorListenerState[listenerId]);
}

function setBehaviorListener(listenerId, enabled) {
  if (!Object.prototype.hasOwnProperty.call(behaviorListenerState, listenerId)) return;
  behaviorListenerState[listenerId] = Boolean(enabled);
  if (listenerId === 'time-delay') {
    resetBehaviorIdleTimer();
  }
  if (listenerId === 'scroll-depth') {
    behaviorScrollArmed = true;
    if (enabled) {
      behaviorScrollProgress = 0;
      logBehavior('Scroll-depth listener armed (progress reset to 0%)');
    }
  }
  if (listenerId === 'rage-click' && !enabled) {
    behaviorRageClicks = [];
  }
  renderBehaviorListenerControls();
  const label = BEHAVIOR_LABELS[listenerId] || listenerId;
  logBehavior(`${enabled ? 'Enabled' : 'Disabled'} ${label} listener`);
}

function renderBehaviorListenerControls() {
  if (!behaviorListenerList) return;
  behaviorListenerList.innerHTML = '';
  Object.keys(behaviorListenerState).forEach((listenerId) => {
    const wrapper = document.createElement('div');
    wrapper.className = 'behavior-listener';
    const input = document.createElement('input');
    input.type = 'checkbox';
    input.id = `behavior-listener-${listenerId}`;
    input.checked = isBehaviorListenerEnabled(listenerId);
    input.addEventListener('change', (event) => {
      setBehaviorListener(listenerId, event.target.checked);
      const label = BEHAVIOR_LABELS[listenerId] || listenerId;
      showBehaviorBanner(`${event.target.checked ? 'Enabled' : 'Disabled'} ${label} listener`);
    });
    const label = document.createElement('label');
    label.setAttribute('for', input.id);
    label.textContent = BEHAVIOR_LABELS[listenerId] || listenerId;
    wrapper.appendChild(input);
    wrapper.appendChild(label);
    behaviorListenerList.appendChild(wrapper);
  });
}

function showBehaviorBanner(message) {
  if (!behaviorBanner) return;
  behaviorBanner.textContent = message;
  behaviorBanner.classList.add('is-visible');
  clearTimeout(behaviorBannerTimeout);
  behaviorBannerTimeout = window.setTimeout(() => {
    behaviorBanner.classList.remove('is-visible');
  }, 2500);
}

init().catch((error) => {
  console.error('Preview init failed', error);
  addLog(`Fatal: ${error.message}`, 'error');
});

// Global error handler for PulseInsightsObject/surveys.js errors
function setupGlobalErrorHandling() {
  // Handle unhandled errors that might come from surveys.js
  window.addEventListener('error', (event) => {
    const { message, filename, lineno, colno, error } = event;
    // Check if error is related to PulseInsightsObject, surveys.js, or proxy issues
    if (
      filename &&
      (filename.includes('surveys.js') ||
        filename.includes('proxy') ||
        filename.includes('pulse') ||
        message.includes('render') ||
        message.includes('PulseInsightsObject') ||
        message.includes('survey') ||
        message.includes('Pulse') ||
        message.includes('bridge'))
    ) {
      try {
        console.error('[preview] Caught PulseInsights error', {
          message,
          filename,
          lineno,
          colno,
          error: error?.message || String(error)
        });
        addLog(
          `Survey error: ${message || 'Unknown error'}${filename ? ` (${filename.split('/').pop()})` : ''}`,
          'error'
        );
        
        // Dispatch event for bridge to handle
        if (typeof window.dispatchEvent === 'function') {
          window.dispatchEvent(
            new CustomEvent('pulseinsights:error', {
              detail: {
                type: 'unhandled-error',
                message: message || 'Unknown error',
                filename,
                lineno,
                colno,
                error: error?.message || String(error)
              }
            })
          );
        }
      } catch (_catchError) {
        // Ignore errors in error handler
      }
    }
  });

  // Handle unhandled promise rejections
  window.addEventListener('unhandledrejection', (event) => {
    const { reason } = event;
    const errorMessage = reason?.message || String(reason || 'Unknown promise rejection');
    if (
      errorMessage.includes('render') ||
      errorMessage.includes('PulseInsightsObject') ||
      errorMessage.includes('survey')
    ) {
      try {
        console.error('[preview] Caught PulseInsights promise rejection', reason);
        addLog(`Survey promise error: ${errorMessage}`, 'error');
        
        // Dispatch event for bridge to handle
        if (typeof window.dispatchEvent === 'function') {
          window.dispatchEvent(
            new CustomEvent('pulseinsights:error', {
              detail: {
                type: 'unhandled-rejection',
                message: errorMessage,
                reason
              }
            })
          );
        }
      } catch (_catchError) {
        // Ignore errors in error handler
      }
    }
  });
}

setupGlobalErrorHandling();

// Listen for PulseInsights error events
window.addEventListener('pulseinsights:error', (event) => {
  try {
    const { detail } = event;
    const errorMsg = detail?.message || detail?.error || 'Unknown error';
    const errorType = detail?.type || 'unknown';
    const surveyId = detail?.surveyId;
    const isSurveyNullError = errorType === 'survey-null-error' || detail?.surveyNull;
    
    console.error('[preview] PulseInsights error event', detail);
    
    // Provide more specific error messages for survey-null errors
    if (isSurveyNullError) {
      const surveyLabel = surveyId ? `survey ${surveyId}` : 'survey';
      const waitInfo = detail?.waited ? ` (waited ${detail.waited}ms)` : '';
      addLog(
        `Survey error: Cannot present ${surveyLabel} - PulseInsightsObject.survey is null${waitInfo}. This typically happens when switching surveys and the new iframe hasn't finished loading survey data yet, or there's a configuration issue.`,
        'error'
      );
    } else {
      addLog(`Survey error (${errorType}): ${errorMsg}`, 'error');
    }
    
    // Also report to bridge as present-error if we have a survey context
    if (lastSurveyRecord || surveyId) {
      const surveyIdToReport = surveyId || lastSurveyRecord?.surveyId || lastSurveyRecord?.surveyName || 'unknown';
      handlePlayerStatus({
        type: 'player-status',
        status: 'present-error',
        surveyId: String(surveyIdToReport),
        source: 'error-handler',
        message: isSurveyNullError 
          ? `Survey null error: ${errorMsg}` 
          : errorMsg,
        errorType
      });
    }
  } catch (_catchError) {
    // Ignore errors in error handler
  }
});

async function init() {
  addLog('Initializing basic preview…');
  addLog(`Preview build stamp ${PREVIEW_BUILD_STAMP}`);
  startPresentGuard();

  const surveyInfo = await populateSurveySelect().catch((error) => {
    addLog(`Failed to load survey list: ${error.message}`, 'warn');
    return {
      initialSurveyId: surveySelect.value || null,
      backgroundUrl: '',
      identifier: DEFAULT_IDENTIFIER
    };
  });

  if (surveyInfo?.initialOptionId && surveySelect) {
    surveySelect.value = surveyInfo.initialOptionId;
  }

  applyIdentifier(surveyInfo?.identifier || DEFAULT_IDENTIFIER);
  const hasDemoFilter = Boolean(demoCodeFilter || demoForFilter);
  
  // Check if present parameter is set - if so, use that survey's background instead of default
  let requestedHost = '';
  if (presentSurveyId) {
    const presentRecord = findRecordBySurveyId(presentSurveyId);
    if (presentRecord && presentRecord.backgroundUrl) {
      requestedHost = presentRecord.backgroundUrl;
      addLog(`Using background URL from present survey ${presentSurveyId}: ${requestedHost}`, 'info');
    }
  }
  
  // Fall back to demo filter or default if present parameter didn't provide a background
  if (!requestedHost) {
    requestedHost = hasDemoFilter ? surveyInfo?.backgroundUrl || '' : '';
  }
  
  // Preserve existing background URL if already loaded (prevent redirect away from current page)
  // Check if there's already a background iframe with a URL different from default
  const existingFrame = siteRoot?.querySelector('iframe.background-frame');
  const existingFrameUrlRaw = existingFrame?.dataset?.previewOriginalUrl || '';
  
  // Validate existing URL before using it (prevents CodeQL unvalidated redirect warning)
  let existingFrameUrl = '';
  if (existingFrameUrlRaw) {
    try {
      // Validate URL format - must be http/https or relative path
      const testUrl = existingFrameUrlRaw.startsWith('/') || existingFrameUrlRaw.startsWith('./') || existingFrameUrlRaw.startsWith('../')
        ? new URL(existingFrameUrlRaw, window.location.origin)
        : new URL(existingFrameUrlRaw);
      // Only allow http/https protocols
      if (['http:', 'https:'].includes(testUrl.protocol)) {
        existingFrameUrl = existingFrameUrlRaw;
      }
    } catch (_error) {
      // Invalid URL, ignore
    }
  }
  
  const hasExistingBackground = existingFrameUrl && 
                                 existingFrameUrl !== DEFAULT_HOST_URL && 
                                 existingFrameUrl !== buildProxySrc(DEFAULT_HOST_URL);
  
  // Only use default if no background is requested AND no existing background is loaded
  const hostToLoad = requestedHost || (hasExistingBackground ? existingFrameUrl : DEFAULT_HOST_URL);
  
  if (!hasDemoFilter && !presentSurveyId && !hasExistingBackground) {
    addLog(`No demo parameter detected; defaulting host to ${DEFAULT_HOST_URL}.`);
  } else if (!requestedHost && (hasDemoFilter || presentSurveyId) && !hasExistingBackground) {
    addLog(`Background URL not found; falling back to ${DEFAULT_HOST_URL}.`, 'warn');
  } else if (hasExistingBackground && !requestedHost) {
    addLog(`Preserving existing background URL: ${existingFrameUrl}`, 'info');
  }

  let hostLoaded = false;
  // Skip bridge load if present parameter is set - presentSurvey() will handle it with correct account
  hostLoaded = await loadHostPage(hostToLoad, { skipBridgeLoad: Boolean(presentSurveyId) });
  if (hostLoaded && hostToLoad) {
    currentBackgroundUrl = normalizeBackgroundUrl(hostToLoad) || hostToLoad;
    if (backgroundInput) {
      backgroundInput.value = currentBackgroundUrl;
    }
  }

  // Skip loading Pulse Insights tag in main document when present parameter is active
  // The tag should only be loaded inside the player iframe, not in the main document
  // This prevents duplicate survey widgets from being created in the main document
  if (!presentSurveyId) {
    await bootPulseTag();
  } else {
    addLog('Skipping Pulse tag boot in main document - tag will be loaded inside player iframe only', 'info');
  }
  
  wireUi();
  setRailOpen(false);
  setLogVisibility(false);

  // Hide control rail if present parameter is active
  if (presentSurveyId) {
    hideControlRail();
  }

  const initialOptionId = surveyInfo?.initialOptionId || surveySelect.value;
  if (initialOptionId) {
    surveySelect.value = initialOptionId;
    updateBehaviorSurveyLabel();
  }

  // Handle present parameter if present
  if (presentSurveyId) {
    await handlePresentParameter();
  }

  // Surface the demo directory so presenters can pick the correct demo before interacting.
  // Skip demo directory if present parameter is set (user wants specific survey)
  if (demoDirectoryOptions.length && !demoForFilterParam && !demoDismissed && !presentSurveyId) {
    openDemoDirectory();
    logBehavior('Demo directory opened by default so the demo context is explicit.');
  } else {
    logBehavior('Demo directory not available yet; listeners still armed with defaults.');
  }
}

function wireUi() {
  presentBtn.addEventListener('click', async () => {
    await presentSurvey(surveySelect.value, { force: true });
  });

  surveySelect.addEventListener('change', async () => {
    // Skip if this change was triggered programmatically (e.g., from present parameter)
    if (isSettingSurveyProgrammatically) {
      return;
    }
    
    if (railOpen) {
      setRailOpen(false);
    }
    
    const newOptionId = surveySelect.value;
    const record = findRecordByOptionId(newOptionId);
    
    // Skip if present parameter has already triggered a presentation for this survey
    // This prevents double triggers when present parameter sets the select value
    if (presentTriggered && presentSurveyId && record && String(record.surveyId) === String(presentSurveyId)) {
      addLog('Skipping survey select change handler - present parameter already handled this survey', 'info', {
        surveyId: presentSurveyId,
        optionId: newOptionId
      });
      return;
    }
    
    if (!record) {
      addLog('Invalid survey selection', 'warn', { optionId: newOptionId });
      return;
    }
    
    // Clear previous survey state
    addLog(
      `Switching to survey ${record.surveyId}...`,
      'info',
      {
        operationId: 'survey-switch',
        surveyId: record.surveyId,
        previousSurveyId: lastSurveyRecord?.surveyId
      }
    );
    
    // Cancel any in-flight operations
    if (activePresentOperation) {
      addLog(
        'Cancelling previous survey operation...',
        'info',
        {
          operationId: 'survey-switch',
          cancelledOperationId: activePresentOperation.id,
          cancelledSurveyId: activePresentOperation.surveyId
        }
      );
      if (activePresentOperation.cancelToken) {
        activePresentOperation.cancelToken.cancel();
      }
    }
    
    // Reset widget state
    playerWidgetRect = null;
    overlayFallbackActive = false;
    overlayFallbackLogged = false;
    resetPlayerOverlayLayout(playerFrameEl);
    
    // Clear any pending presents
    pendingPresent = null;
    
    // Wait a brief moment for cleanup
    await new Promise(resolve => setTimeout(resolve, 100));
    
    // Present new survey
    await presentSurvey(newOptionId, { force: true, forceReload: true });
    updateBehaviorSurveyLabel();
    showBehaviorMessage('Survey updated. Perform a behavior to trigger it.');
  });

  if (railToggle) {
    const shortcutLabel = `type ${RAIL_TOGGLE_SEQUENCE}`;
    const toggleLabel = `Toggle controls (${shortcutLabel})`;
    railToggle.setAttribute('title', toggleLabel);
    railToggle.setAttribute('aria-label', toggleLabel);
    railToggle.addEventListener('click', () => {
      setRailOpen(!railOpen);
    });
  }

  if (closeLogBtn) {
    closeLogBtn.addEventListener('click', () => {
      setLogVisibility(false);
    });
  }

  if (demoDirectoryClose) {
    demoDirectoryClose.addEventListener('click', () => {
      closeDemoDirectory();
    });
  }

  if (demoDirectoryBackdrop) {
    demoDirectoryBackdrop.addEventListener('click', () => {
      closeDemoDirectory();
    });
  }

  if (demoDirectoryList) {
    demoDirectoryList.addEventListener('click', handleDemoDirectoryListClick);
  }

  document.addEventListener('keydown', handleDemoDirectoryKeydown);
  document.addEventListener('keydown', handleRailToggleShortcut);

  initializeAccordion();
  initializeBehaviorLab();
  refreshAccordionHeights();
}

async function loadHostPage(url, { skipBridgeLoad = false } = {}) {
  if (!skipBridgeLoad) {
    const playerFrame = surveyBridge.load({
      account: DEFAULT_IDENTIFIER,
      host: DEFAULT_PULSE_HOST,
      themeCss: resolveThemeHref(currentThemeHref) || undefined,
      tagSrc: resolveProxyUrl(DEFAULT_TAG_SRC),
      proxyOrigin: getProxyOrigin()
    });
    registerPlayerFrame(playerFrame);
  }

  const target = (url || '').trim();
  if (!target) {
    // Keep the last background (or nothing) instead of falling back to default/lipsum.
    backgroundPage403 = false;
    addLog('No background URL provided; skipping background load to preserve current page.', 'warn');
    return false;
  }

  addLog(`Loading host page ${target}`);
  
  // Reset 403 flag
  backgroundPage403 = false;
  
  // If we're using a proxy, check the response status first
  const frameSrc = buildProxySrc(target);
  if (frameSrc !== target) {
    addLog(`Proxying background via ${frameSrc}`);
    try {
      // Fetch the page first to check for 403 errors
      // Use a timeout to avoid blocking too long
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 3000);
      try {
        const response = await fetch(frameSrc, { 
          signal: controller.signal,
          method: 'GET'
        });
        if (response.status === 403) {
          backgroundPage403 = true;
          addLog(`Background page returned 403 Forbidden: ${target}`, 'warn');
        }
      } catch (err) {
        // If fetch fails (CORS, network error, timeout), we'll rely on DOM detection
        if (err.name !== 'AbortError') {
          addLog(`Could not check response status, will rely on DOM detection: ${err.message}`, 'debug');
        }
      } finally {
        clearTimeout(timeoutId);
      }
    } catch (err) {
      // If status check fails, we'll rely on DOM detection in has403Error()
      addLog(`Could not check response status, will rely on DOM detection: ${err.message}`, 'debug');
    }
  }
  
  if (overlayContainer && overlayContainer.parentNode === siteRoot) {
    siteRoot.removeChild(overlayContainer);
  }
  siteRoot.innerHTML = '';
  siteRoot.classList.remove('loaded-site');

  // Clear any existing iframes from overlayContainer before re-adding it
  // This prevents duplicate survey widgets when loadHostPage is called multiple times
  if (overlayContainer) {
    const existingIframes = overlayContainer.querySelectorAll('iframe');
    existingIframes.forEach(iframe => {
      try {
        iframe.remove();
      } catch (_error) {
        // Ignore errors when removing iframes
      }
    });
  }

  const frame = document.createElement('iframe');
  frame.className = 'background-frame';
  if (frameSrc !== target) {
    addLog(`Proxying background via ${frameSrc}`);
  }
  frame.src = frameSrc;
  frame.title = 'Preview background';
  frame.loading = 'lazy';
  frame.dataset.previewOriginalUrl = target;
  siteRoot.appendChild(frame);
  if (overlayContainer) {
    siteRoot.appendChild(overlayContainer);
  }

  initializeStylesheetRegistry();
  return new Promise((resolve) => {
    let settled = false;
    const finish = (success) => {
      if (settled) return;
      settled = true;
      setTimeout(() => {
        if (success) {
          applyThemeToBackgroundFrame(currentThemeHref);
        }
        resolve(success);
      }, 0);
    };
    frame.addEventListener('load', () => {
      // Double-check for 403 banner after iframe loads
      // Check multiple times with increasing delays to catch banners injected asynchronously
      const check403 = () => {
        if (has403Error()) {
          backgroundPage403 = true;
          addLog(`403 error detected in background frame: ${target}`, 'warn');
        }
      };
      // Check immediately, then after delays
      check403();
      setTimeout(check403, 200);
      setTimeout(check403, 500);
      setTimeout(check403, 1000);
      finish(true);
    }, { once: true });
    frame.addEventListener('error', () => finish(false), { once: true });
    setTimeout(() => finish(true), 2000);
  });
}

function getBackgroundDocument() {
  const frame = siteRoot.querySelector('iframe.background-frame');
  if (!frame) return null;
  try {
    return frame.contentDocument || frame.contentWindow?.document || null;
  } catch (error) {
    console.warn('[preview] Background document not accessible', error);
    return null;
  }
}

/**
 * Checks if the background frame has a 403 error banner.
 * Returns true if a 403 error is detected, false otherwise.
 *
 * @returns {boolean} True if 403 error detected
 */
function has403Error() {
  // First check the stored flag (set during loadHostPage)
  if (backgroundPage403) {
    return true;
  }
  
  try {
    const doc = getBackgroundDocument();
    if (!doc) return false;
    
    // Check for the 403 banner element
    const banner = doc.querySelector('.pi-proxy-403-banner[data-pi-proxy="403-message"]');
    if (banner) {
      backgroundPage403 = true; // Cache the result
      return true;
    }
    
    // Also check for common 403 error indicators in the page content
    const bodyText = doc.body?.innerText || doc.body?.textContent || '';
    const hasAccessDenied = /access\s+denied|403|forbidden/i.test(bodyText);
    const hasErrorReference = /reference\s+#/i.test(bodyText);
    
    // If we see both "Access Denied" and a reference number, it's likely a 403 page
    if (hasAccessDenied && hasErrorReference) {
      backgroundPage403 = true; // Cache the result
      return true;
    }
    
    return false;
  } catch (error) {
    // If we can't access the document, check the stored flag
    // (might be cross-origin, but we may have detected 403 during fetch)
    return backgroundPage403;
  }
}

function applyThemeToBackgroundFrame(href) {
  const doc = getBackgroundDocument();
  if (!doc || !doc.head) return;
  let link = doc.getElementById('preview-theme-css');
  if (link && link.parentNode) {
    link.parentNode.removeChild(link);
  }
  if (!href) return;
  link = doc.createElement('link');
  link.rel = 'stylesheet';
  const resolvedHref = resolveThemeHref(href);
  link.href = resolvedHref;
  link.id = 'preview-theme-css';
  doc.head.appendChild(link);
}

function resolveThemeHref(href) {
  if (!href) return '';
  if (href.startsWith('blob:') || /^https?:/i.test(href)) return href;
  return new URL(href, window.location.origin).href;
}

async function loadLipsumSite() {
  addLog('Loading Lipsum HTML…');
  try {
    const res = await fetch(LIPSUM_INDEX, { cache: 'no-cache' });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const html = await res.text();
    const parser = new DOMParser();
    const doc = parser.parseFromString(html, 'text/html');

    injectHeadResources(doc);

    const fragment = document.createDocumentFragment();
    Array.from(doc.body.children).forEach((node) => {
      rewriteNodeUrls(node);
      fragment.appendChild(node);
    });

  siteRoot.innerHTML = '';
  siteRoot.classList.add('loaded-site');
  siteRoot.appendChild(fragment);
  if (overlayContainer) {
    siteRoot.appendChild(overlayContainer);
  }
    addLog('Lipsum site loaded.');
    initializeStylesheetRegistry();
    currentBackgroundUrl = LIPSUM_INDEX;
    return true;
  } catch (error) {
    addLog(`Failed to load Lipsum site: ${error.message}`, 'error');
    siteRoot.innerHTML = `<div class="placeholder error">Failed to load Lipsum site: ${error.message}</div>`;
    return false;
  }
}

function injectHeadResources(doc) {
  const assets = doc.querySelectorAll('link[rel="stylesheet"], link[rel="icon"], style');
  assets.forEach((asset) => {
    const clone = asset.cloneNode(true);
    if (clone.tagName === 'LINK') {
      rewriteAttribute(clone, 'href');
      const key = `${clone.tagName}:${clone.getAttribute('rel')}:${clone.getAttribute('href')}`;
      if (loadedAssets.has(key)) return;
      loadedAssets.add(key);
      document.head.appendChild(clone);
    } else if (clone.tagName === 'STYLE') {
      document.head.appendChild(clone);
    }
  });
}

function rewriteNodeUrls(node) {
  if (node.nodeType !== Node.ELEMENT_NODE) return;
  rewriteAttribute(node, 'src');
  rewriteAttribute(node, 'href');

  Array.from(node.children).forEach(rewriteNodeUrls);
}

function rewriteAttribute(element, attr) {
  if (!element.hasAttribute(attr)) return;
  const value = element.getAttribute(attr);
  const rewritten = rewriteUrl(value);
  if (rewritten !== value) {
    element.setAttribute(attr, rewritten);
  }
}

function rewriteUrl(value) {
  if (!value) return value;
  const trimmed = value.trim();
  if (!trimmed) return trimmed;
  if (/^(https?:)?\/\//i.test(trimmed)) return trimmed;
  if (/^(mailto:|tel:|data:|#)/i.test(trimmed)) return trimmed;
  const normalized = trimmed.replace(/^\.\//, '');
  return `${LIPSUM_BASE}${normalized}`;
}

async function bootPulseTag({ force = false } = {}) {
  // Allow re-initialization if forced or failed
  if (tagState === TAG_STATES.READY && !force) {
    addLog('Pulse tag already ready.', 'info', { operationId: 'tag-boot' });
    return Promise.resolve();
  }
  
  // If already loading, return existing promise
  if (tagState === TAG_STATES.LOADING && tagReadyPromise) {
    addLog('Tag loading already in progress; waiting...', 'info', { operationId: 'tag-boot' });
    return tagReadyPromise;
  }

  tagState = TAG_STATES.LOADING;
  setTagStatus('Tag: loading...');
  
  if (!window.PULSE_TAG_SRC) {
    window.PULSE_TAG_SRC = resolveProxyUrl(DEFAULT_TAG_SRC);
  } else {
    window.PULSE_TAG_SRC = resolveProxyUrl(window.PULSE_TAG_SRC);
  }

  const attemptNumber = tagRetryCount + 1;
  addLog(
    `Loading Pulse tag (attempt ${attemptNumber}/${MAX_TAG_RETRIES + 1})...`,
    'info',
    { operationId: 'tag-boot', attempt: attemptNumber }
  );
  
  tagReadyPromise = (async () => {
    try {
      await injectScript('/preview/scripts/pulse-insights-official-tag.js');
      addLog('Tag script injected; verifying readiness...', 'info', { operationId: 'tag-boot' });
      
      await waitForOfficialTag(TAG_TIMEOUT);
      
      // Verify tag is actually functional
      await verifyTagFunctionality();
      
      tagState = TAG_STATES.READY;
      tagReady = true;
      tagRetryCount = 0;
      setTagStatus('Tag: ready');
      addLog('Pulse tag ready and verified.', 'info', { operationId: 'tag-boot' });
      
      // Start health monitoring
      startTagHealthMonitoring();
      
      clearPresentCommands({ log: true });
      applyPendingIdentifier({ reason: 'ready' });
      
      // Process pending presents
      if (pendingPresent && pendingPresent.optionId) {
        const record = findRecordByOptionId(pendingPresent.optionId);
        if (record) {
          sendPresentForRecord(record, pendingPresent.options);
        }
        pendingPresent = null;
      }
      
      return true;
    } catch (error) {
      tagRetryCount++;
      
      if (tagRetryCount <= MAX_TAG_RETRIES) {
        tagState = TAG_STATES.RETRYING;
        const retryDelay = TAG_RETRY_DELAYS[tagRetryCount - 1] || 2000;
        addLog(
          `Tag initialization failed: ${error.message}. Retrying in ${retryDelay}ms...`,
          'warn',
          {
            operationId: 'tag-boot',
            error: error.message,
            retryCount: tagRetryCount,
            retryDelay
          }
        );
        setTagStatus(`Tag: retrying (${tagRetryCount}/${MAX_TAG_RETRIES})...`);
        
        await new Promise(resolve => setTimeout(resolve, retryDelay));
        return bootPulseTag({ force: true });
      } else {
        tagState = TAG_STATES.FAILED;
        tagReady = false;
        setTagStatus('Tag: failed');
        addLog(
          `Tag failed after ${MAX_TAG_RETRIES + 1} attempts: ${error.message}`,
          'error',
          {
            operationId: 'tag-boot',
            error: error.message,
            totalAttempts: MAX_TAG_RETRIES + 1
          }
        );
        throw error;
      }
    } finally {
      tagReadyPromise = null;
    }
  })();
  
  return tagReadyPromise;
}

async function populateSurveySelect() {
  if (!surveySelect) return null;

  const records = applyBackgroundNormalization(await fetchSurveySheet());
  allSurveyRecords = records;
  if (!records.length) {
    demoSubtitleText = '';
    updateDemoSubtitle();
    refreshDemoDirectory();
    return {
      initialOptionId: null,
      initialSurveyId: surveySelect.value || null,
      backgroundUrl: '',
      identifier: DEFAULT_IDENTIFIER
    };
  }

  const filtered = filterByDemoSelection(records);
  const filteredRecords = filtered.records;
  demoSubtitleText = filtered.demoFor || '';
  updateDemoSubtitle();
  refreshDemoDirectory();

  if (!filteredRecords.length) {
    addLog('Survey sheet returned no records; keeping existing options.', 'warn');
    demoSubtitleText = '';
    updateDemoSubtitle();
    refreshDemoDirectory();
    return {
      initialOptionId: surveySelect.value || null,
      initialSurveyId: surveySelect.value || null,
      backgroundUrl: '',
      identifier: DEFAULT_IDENTIFIER
    };
  }

  surveySelect.innerHTML = '';

  const placeholderOption = document.createElement('option');
  placeholderOption.value = '';
  placeholderOption.textContent = 'Select a demo';
  placeholderOption.disabled = true;
  placeholderOption.selected = true;
  placeholderOption.hidden = false;
  surveySelect.appendChild(placeholderOption);

  surveyRecords = filteredRecords.map((record, index) => {
    const optionId = createRecordOptionId(record, index);
    const enriched = { ...record, __optionId: optionId };
    const option = document.createElement('option');
    option.value = optionId;
    option.textContent = formatSurveyOptionLabel(enriched);
    surveySelect.appendChild(option);
    return enriched;
  });

  const firstRecord = surveyRecords[0];
  return {
    initialOptionId: null, // Default to placeholder "Select a demo"
    initialSurveyId: firstRecord?.surveyId || null,
    backgroundUrl: firstRecord?.backgroundUrl || '',
    identifier: resolveIdentifier(firstRecord)
  };
}

async function handlePresentParameter() {
  if (!presentSurveyId) return;
  
  // Prevent double triggers - if we've already handled present parameter, don't do it again
  if (presentTriggered) {
    addLog(`present parameter already triggered, skipping duplicate call.`, 'warn', {
      stack: new Error().stack
    });
    return;
  }
  
  // Mark as triggered immediately to prevent race conditions
  presentTriggered = true;
  addLog(`present parameter trigger flag set to prevent duplicates`, 'info', {
    surveyId: presentSurveyId,
    stack: new Error().stack
  });
  
  // Remove any survey widgets that may have been created in the main document
  // (e.g., if bootPulseTag was called before present parameter was detected, or if tag loaded asynchronously)
  // Survey widgets should only exist inside the player iframe, not in the main document
  const mainDocWidgetContainer = document.getElementById('_pi_surveyWidgetContainer');
  if (mainDocWidgetContainer) {
    // Check if it's not inside overlayContainer (which contains the player iframe)
    // or if it's directly in the body or another part of the main document
    const isInMainDocument = mainDocWidgetContainer.parentNode !== overlayContainer &&
                              (mainDocWidgetContainer.parentNode === document.body ||
                               !overlayContainer.contains(mainDocWidgetContainer));
    
    if (isInMainDocument) {
      addLog('Removing survey widget from main document - should only exist in player iframe', 'info', {
        surveyId: presentSurveyId,
        parentNode: mainDocWidgetContainer.parentNode?.tagName || 'unknown'
      });
      try {
        mainDocWidgetContainer.remove();
      } catch (_error) {
        addLog('Error removing survey widget from main document', 'warn', {
          error: _error.message
        });
      }
    }
  }
  
  // Also check for the widget element itself (in case container was already removed)
  const mainDocWidget = document.getElementById('_pi_surveyWidget');
  if (mainDocWidget && mainDocWidget.parentNode !== overlayContainer) {
    const isInMainDocument = mainDocWidget.parentNode === document.body ||
                             !overlayContainer.contains(mainDocWidget);
    if (isInMainDocument) {
      addLog('Removing survey widget element from main document', 'info', {
        surveyId: presentSurveyId
      });
      try {
        mainDocWidget.remove();
      } catch (_error) {
        addLog('Error removing survey widget element from main document', 'warn', {
          error: _error.message
        });
      }
    }
  }
  
  // Wait a bit for the UI to settle
  await new Promise((resolve) => setTimeout(resolve, 100));
  
  // Find the survey by ID
  const record = findRecordBySurveyId(presentSurveyId);
  
  if (!record) {
    // Survey not found - show overlay and keep default state
    addLog(`Survey ID ${presentSurveyId} not found in survey list.`, 'warn');
    showIdNotFoundOverlay();
    // Reset flag so user can try again if they fix the URL
    presentTriggered = false;
    return;
  }
  
  // Find the option ID for this record in surveyRecords (filtered list)
  let optionId = surveyRecords.find((r) => String(r.surveyId).trim() === String(record.surveyId).trim())?.__optionId;
  
  if (!optionId) {
    // Record exists but wasn't included in filtered results
    // Try to create an option ID for it manually so we can still present it
    const index = allSurveyRecords.findIndex((r) => String(r.surveyId).trim() === String(record.surveyId).trim());
    if (index >= 0) {
      optionId = createRecordOptionId(record, index);
      // Add to surveyRecords temporarily so presentSurvey can find it
      const enriched = { ...record, __optionId: optionId };
      surveyRecords.push(enriched);
      // Also add to select dropdown
      const option = document.createElement('option');
      option.value = optionId;
      option.textContent = formatSurveyOptionLabel(enriched);
      if (surveySelect) {
        surveySelect.appendChild(option);
      }
    } else {
      addLog(`Survey ID ${presentSurveyId} found but could not create option.`, 'warn');
      showIdNotFoundOverlay();
      // Reset flag so user can try again if they fix the URL
      presentTriggered = false;
      return;
    }
  }
  
  // Set the survey select value
  if (surveySelect) {
    isSettingSurveyProgrammatically = true;
    surveySelect.value = optionId;
    // Keep flag true during async operations to prevent change event handler from running
    // We'll reset it after presentSurvey completes
  }
  
  // Update behavior survey label
  updateBehaviorSurveyLabel();
  
  // Wait for tag to be ready before presenting
  if (!tagReady) {
    addLog(`Waiting for tag to be ready before presenting survey ${presentSurveyId}...`, 'info');
    // Wait for tag ready
    if (tagReadyPromise) {
      await tagReadyPromise.catch(() => {});
    }
  }
  
  // Wait a bit for iframe to load and check for 403 errors
  // This ensures we detect 403 banners that are injected by the proxy
  await new Promise(resolve => setTimeout(resolve, 1000));
  
  // Check for 403 error before presenting
  if (has403Error()) {
    addLog(
      `Cannot present survey ${presentSurveyId} because the background page is blocked (403 Forbidden).`,
      'warn',
      { surveyId: presentSurveyId, backgroundUrl: currentBackgroundUrl }
    );
    setSurveyStatus('Survey: Blocked (403 error)');
    // Reset flag so user can try again if they fix the URL
    setTimeout(() => {
      isSettingSurveyProgrammatically = false;
      presentTriggered = false;
    }, 0);
    return;
  }
  
  // Present the survey
  addLog(`Auto-presenting survey ${presentSurveyId} from present parameter.`, 'info', {
    optionId,
    surveyId: presentSurveyId,
    presentTriggered,
    activePresentOperation: activePresentOperation?.key || null,
    lastPresentedOptionId
  });
  
  try {
    await presentSurvey(optionId, { force: true });
  } finally {
    // Reset flag after presentSurvey completes (or fails)
    // Use setTimeout to ensure any queued change events have been processed
    setTimeout(() => {
      isSettingSurveyProgrammatically = false;
    }, 0);
  }
}

async function fetchSurveySheet() {
  addLog('Loading survey list from Google Sheet…');
  try {
    const response = await fetch(SHEET_CSV_URL, { cache: 'no-cache' });
    if (!response.ok) {
      throw new Error(`Google Sheet responded with ${response.status}`);
    }
    const text = await response.text();
    const rows = parseCsv(text);
    if (!rows.length) {
      addLog('Survey sheet returned no rows; using fallback demos.', 'warn');
      return FALLBACK_SURVEYS.map((record) => ({ ...record }));
    }

    const [header, ...dataRows] = rows;
    const indexMap = header.reduce((acc, key, idx) => {
      const trimmed = (key || '').trim();
      if (trimmed) acc[trimmed] = idx;
      return acc;
    }, {});
    const hasEnabledColumn = Object.prototype.hasOwnProperty.call(indexMap, 'enabled');

    const get = (row, key) => {
      const idx = indexMap[key];
      if (idx === undefined) return '';
      return (row[idx] || '').trim();
    };

    const records = dataRows
      .map((row) => {
        const enabledValue = get(row, 'enabled');
        const enabled = hasEnabledColumn ? /^yes$/i.test(enabledValue) : true;
        return {
          demoFor: get(row, 'demo_for'),
          demoCode: get(row, 'demo_code'),
          accountName: get(row, 'account_name'),
          surveyName: get(row, 'survey_name'),
          identifier: get(row, 'identifier'),
          surveyId: get(row, 'survey_id'),
          statusName: get(row, 'survey_status_name'),
          surveyTypeName: get(row, 'survey_type_name'),
          inlineTargetSelector: get(row, 'inline_target_selector'),
          surveyTags: get(row, 'survey_tags'),
          surveyTagAgent: /^true$/i.test(get(row, 'survey_tag_agent')),
          url: get(row, 'url'),
          enabled
        };
      })
      .filter((record) => record.enabled)
      .filter((record) => record.surveyId)
      .filter((record) => !record.statusName || /live/i.test(record.statusName))
      .map((record) => ({
        ...record,
        surveyId: record.surveyId.trim(),
        identifier: (record.identifier || '').trim() || DEFAULT_IDENTIFIER
      }));

    if (!records.length) {
      addLog('Survey sheet returned no demo-ready surveys; using fallback demos.', 'warn');
      return FALLBACK_SURVEYS.map((record) => ({ ...record }));
    }

    return records;
  } catch (error) {
    addLog(`Survey sheet unavailable (${error.message}); using fallback demos.`, 'warn');
    return FALLBACK_SURVEYS.map((record) => ({ ...record }));
  }
}

function injectScript(src) {
  return new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = src;
    script.async = true;
    script.onload = () => resolve();
    script.onerror = (event) => reject(new Error(`Failed to load script ${src}`));
    document.head.appendChild(script);
  });
}

function waitForOfficialTag(timeoutMs = TAG_TIMEOUT) {
  const start = Date.now();
  let lastProgressLog = 0;
  
  return new Promise((resolve, reject) => {
    (function poll() {
      const hasPi = typeof window.pi === 'function';
      const hasPulse = typeof window.PulseInsightsObject === 'object' && window.PulseInsightsObject;
      
      if (hasPi && hasPulse) {
        resolve();
        return;
      }
      
      const elapsed = Date.now() - start;
      if (elapsed >= timeoutMs) {
        reject(new Error(
          `Timeout: PulseInsightsObject/pi() not available after ${timeoutMs}ms`
        ));
        return;
      }
      
      // Log progress every 2 seconds
      if (elapsed - lastProgressLog >= 2000) {
        lastProgressLog = elapsed;
        const seconds = Math.round(elapsed / 1000);
        addLog(
          `Waiting for tag... (${seconds}s/${Math.round(timeoutMs / 1000)}s)`,
          'info',
          { operationId: 'tag-wait', elapsed, timeout: timeoutMs }
        );
      }
      
      setTimeout(poll, 100);
    })();
  });
}

async function verifyTagFunctionality() {
  // Verify pi() function works
  if (typeof window.pi !== 'function') {
    throw new Error('pi() function not available');
  }
  
  // Verify PulseInsightsObject exists and has expected structure
  if (!window.PulseInsightsObject || typeof window.PulseInsightsObject !== 'object') {
    throw new Error('PulseInsightsObject not available');
  }
  
  // Try a test command to ensure it's functional
  try {
    const testId = 'test-' + Date.now();
    window.pi('identify', testId);
    // If no error thrown, assume it's working
  } catch (error) {
    throw new Error(`Tag functionality test failed: ${error.message}`);
  }
}

function startTagHealthMonitoring() {
  if (tagHealthCheckInterval) return;
  
  tagHealthCheckInterval = setInterval(() => {
    if (tagState !== TAG_STATES.READY) return;
    
    const isHealthy = 
      typeof window.pi === 'function' &&
      window.PulseInsightsObject &&
      typeof window.PulseInsightsObject === 'object';
    
    if (!isHealthy) {
      addLog(
        'Tag health check failed; tag may have been removed or corrupted.',
        'warn',
        { operationId: 'tag-health' }
      );
      tagState = TAG_STATES.FAILED;
      tagReady = false;
      setTagStatus('Tag: unhealthy');
      
      // Attempt recovery
      bootPulseTag({ force: true }).catch(() => {
        addLog('Tag recovery failed.', 'error', { operationId: 'tag-health' });
      });
    }
  }, 5000);
}

function stopTagHealthMonitoring() {
  if (tagHealthCheckInterval) {
    clearInterval(tagHealthCheckInterval);
    tagHealthCheckInterval = null;
  }
}

async function presentSurvey(optionId, options = {}) {
  const operationId = ++presentOperationId;
  const operationKey = `present-${operationId}`;
  
  try {
    // Check if background page has a 403 error - don't present surveys on blocked pages
    if (has403Error()) {
      addLog(
        'Survey presentation blocked: The background page returned a 403 Forbidden error. Surveys cannot be displayed on blocked pages.',
        'warn',
        {
          operationId: operationKey,
          reason: '403-forbidden',
          backgroundUrl: currentBackgroundUrl
        }
      );
      setSurveyStatus('Survey: blocked (403 error)');
      return;
    }
    
    const key = String(optionId || '').trim();
    if (!key) {
      addLog('No survey id selected.', 'warn', { operationId: operationKey });
      return;
    }

    const record = findRecordByOptionId(key);
    if (!record) {
      addLog(
        `No survey record found for option ${key}`,
        'warn',
        { operationId: operationKey, optionId: key }
      );
      setSurveyStatus('Survey: idle');
      return;
    }

    // For present parameter scenarios, prevent double presentation
    // Check if this is the present parameter survey and if we've already started/completed presenting it
    if (presentSurveyId && String(record.surveyId) === String(presentSurveyId)) {
      const optionIdStr = record.__optionId || String(record.surveyId || '');
      // If we've already triggered present parameter and there's an active operation for this survey, skip
      // This prevents double triggers when present parameter is active
      if (presentTriggered && activePresentOperation && activePresentOperation.surveyId === record.surveyId && !options.forceReload && !options.allowDuplicate) {
        addLog(
          `present parameter survey ${record.surveyId} presentation already in progress; skipping duplicate presentSurvey call.`,
          'info',
          { operationId: operationKey, surveyId: record.surveyId, activeOperationId: activePresentOperation.key }
        );
        return;
      }
      // Also check if we've already completed presenting this survey
      if (presentTriggered && lastPresentedOptionId === optionIdStr && !options.force && !options.forceReload && !options.allowDuplicate) {
        addLog(
          `present parameter survey ${record.surveyId} already presented; skipping duplicate presentSurvey call.`,
          'info',
          { operationId: operationKey, surveyId: record.surveyId }
        );
        return;
      }
    }

    // Cancel previous operation if still in progress
    if (activePresentOperation && activePresentOperation.cancelToken) {
      addLog(
        `Cancelling previous present operation (${activePresentOperation.surveyId})`,
        'info',
        {
          operationId: operationKey,
          cancelledOperationId: activePresentOperation.id,
          cancelledSurveyId: activePresentOperation.surveyId
        }
      );
      activePresentOperation.cancelToken.cancel();
    }

    // Create cancellation token
    let cancelled = false;
    const cancelToken = {
      cancel: () => { cancelled = true; },
      get cancelled() { return cancelled; }
    };

    activePresentOperation = {
      id: operationId,
      key: operationKey,
      optionId: key,
      surveyId: record.surveyId,
      cancelToken,
      startTime: Date.now()
    };

    if (surveySelect && surveySelect.value !== key) {
      surveySelect.value = key;
    }

    lastSurveyRecord = record;
    const placementHint = derivePlacementHintFromRecord(record);
    if (placementHint) {
      overlayPlacementHint = placementHint;
    }
    overlayFallbackActive = false;
    overlayFallbackLogged = false;

    const { force = false, forceReload = false, allowDuplicate = false } = options;

    addLog(
      `Starting present operation for survey ${record.surveyId}`,
      'info',
      {
        operationId: operationKey,
        surveyId: record.surveyId,
        account: resolveIdentifier(record),
        force,
        forceReload,
        allowDuplicate
      }
    );

    // Step 1: Ensure background
    if (cancelled) {
      addLog(`Operation cancelled`, 'warn', { operationId: operationKey });
      return;
    }
    addLog(
      `Step 1/4: Ensuring background page...`,
      'info',
      { operationId: operationKey, step: 1, total: 4, surveyId: record.surveyId }
    );
    await ensureBackgroundForRecord(record, { 
      force: Boolean(force),
      skipBridgeLoad: Boolean(presentSurveyId)
    });

    // Step 2: Ensure player loaded and ready
    if (cancelled) return;
    addLog(
      `Step 2/4: Ensuring player iframe...`,
      'info',
      { operationId: operationKey, step: 2, total: 4, surveyId: record.surveyId }
    );
    const ensureResult = ensurePlayerLoadedForRecord(record, {
      forceReload: Boolean(forceReload || force),
      excludePresent: true  // Don't auto-present via URL, we'll call sendPresentForRecord explicitly
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

    // Step 3: Ensure tag ready
    if (cancelled) return;
    addLog(
      `Step 3/4: Ensuring tag ready...`,
      'info',
      { operationId: operationKey, step: 3, total: 4, surveyId: record.surveyId }
    );
    if (!tagReady || tagState !== TAG_STATES.READY) {
      addLog(
        `Tag not ready; booting...`,
        'info',
        { operationId: operationKey, surveyId: record.surveyId }
      );
      await bootPulseTag();
    }

    // Step 4: Apply identifier
    if (cancelled) return;
    addLog(
      `Step 4/4: Applying identifier...`,
      'info',
      { operationId: operationKey, step: 4, total: 4, surveyId: record.surveyId }
    );
    const trimmedQueue = (window.pi && Array.isArray(window.pi.commands)) 
      ? window.pi.commands.map((args) => args[0]) 
      : [];
    addLog(
      `pi() queue: ${trimmedQueue.join(', ') || 'empty'}`,
      'info',
      { operationId: operationKey, queue: trimmedQueue }
    );
    applyIdentifier(resolveIdentifier(record));

    if (cancelled) {
      addLog(`Operation cancelled before present`, 'warn', { operationId: operationKey });
      return;
    }

    // Step 5: Send present
    addLog(
      `Sending present command...`,
      'info',
      { operationId: operationKey, surveyId: record.surveyId }
    );
    sendPresentForRecord(record, { force, forceReload, allowDuplicate }, ensureResult, operationKey);
    
    const duration = Date.now() - activePresentOperation.startTime;
    addLog(
      `Present operation completed in ${duration}ms`,
      'info',
      {
        operationId: operationKey,
        surveyId: record.surveyId,
        duration
      }
    );
    activePresentOperation = null;
    
  } catch (error) {
    addLog(
      `Present failed: ${error.message}`,
      'error',
      {
        operationId: operationKey,
        error: error.message,
        stack: error.stack
      }
    );
    activePresentOperation = null;
  }
}

function sendPresentForRecord(record, { force = false, forceReload = false, allowDuplicate = false } = {}, ensured = null, operationKey = null) {
  if (!record) return;
  pendingPresent = null;
  const optionId = record.__optionId || String(record.surveyId || '');
  const surveyId = record.surveyId;
  const label = String(surveyId || record.surveyName || optionId);
  const opKey = operationKey || activePresentOperation?.key || 'present';

  lastSurveyRecord = record;
  const placementHint = derivePlacementHintFromRecord(record);
  if (placementHint) {
    overlayPlacementHint = placementHint;
  }

  if (!surveyId) {
    addLog(
      `Survey record ${label} is missing a surveyId; skipping present.`,
      'warn',
      { operationId: opKey, surveyId: label }
    );
    return;
  }

  // For present parameter scenarios, check if we've already presented this survey
  // This prevents double triggers when present parameter is active
  if (presentSurveyId && String(surveyId) === String(presentSurveyId) && !force && !forceReload && !allowDuplicate && lastPresentedOptionId === optionId) {
    addLog(
      `present parameter survey ${label} already presented; skipping duplicate.`,
      'info',
      { operationId: opKey, surveyId: label }
    );
    setSurveyStatus(`Survey: already presenting ${label}`);
    return;
  }

  const ensureResult =
    ensured && ensured.config
      ? ensured
      : ensurePlayerLoadedForRecord(record, { 
          forceReload: Boolean(force || forceReload),
          excludePresent: true  // Don't auto-present via URL, we're calling present explicitly
        });
  const reloaded = Boolean(ensureResult && ensureResult.reloaded);

  if (!force && !forceReload && !allowDuplicate && !reloaded && lastPresentedOptionId === optionId) {
    addLog(
      `pi('present', ${label}) already sent; skipping duplicate.`,
      'info',
      { operationId: opKey, surveyId: label }
    );
    setSurveyStatus(`Survey: already presenting ${label}`);
    return;
  }

  clearPresentCommands({ log: true });
  blockAutoPresent = false;
  stopPresentGuard();
  const modeNote = forceReload || force ? ' (reload)' : allowDuplicate ? ' (duplicate)' : '';
  addLog(
    `Calling pi('present', ${label})${modeNote}`,
    'info',
    {
      operationId: opKey,
      surveyId: label,
      force,
      forceReload,
      allowDuplicate
    }
  );
  setSurveyStatus(`Survey: presenting ${label}`);
  if (surveyBridge && typeof surveyBridge.present === 'function') {
    surveyBridge.present(surveyId);
  } else if (typeof window.pi === 'function') {
    window.pi('present', surveyId);
  }
  lastPresentedOptionId = optionId;
  scheduleOverlayLayoutUpdate({ immediate: true, trailing: true });
  monitorWidgetVisibility({ surveyId: label, url: record.backgroundUrl || record.url });
}

function formatSurveyOptionLabel(record) {
  const surveyName = record.surveyName || 'Untitled Survey';
  const account = record.identifier || record.accountName || '';
  if (!account) return surveyName;
  return `${surveyName} · ${account}`;
}

function createRecordOptionId(record, index) {
  const rowIndex = typeof record.__rowIndex === 'number' ? record.__rowIndex : index;
  const base = record.surveyId ? `survey-${record.surveyId}` : 'survey';
  const suffixSource = record.demoCode || record.demoFor || record.surveyName || rowIndex;
  const slug = String(suffixSource || rowIndex)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
  return slug ? `${base}-${rowIndex}-${slug}` : `${base}-${rowIndex}`;
}

function filterByDemoSelection(records) {
  let filtered = records;
  let demoFor = '';

  if (demoCodeFilter) {
    const byCode = records.filter(
      (record) => (record.demoCode || '').trim().toLowerCase() === demoCodeFilter
    );
    if (byCode.length) {
      filtered = byCode;
      demoFor = byCode[0].demoFor || demoFor;
      addLog(`Filtered surveys by demo code "${demoCodeFilter}" (${byCode.length} found).`);
    } else {
      addLog(`No surveys found for demo code "${demoCodeFilter}".`, 'warn');
    }
  }

  if (demoForFilter) {
    const base = filtered.length && (demoCodeFilter ? filtered : records);
    let byFor = base.filter(
      (record) => (record.demoFor || '').trim().toLowerCase() === demoForFilter
    );
    if (!byFor.length && demoCodeFilter) {
      byFor = records.filter(
        (record) => (record.demoFor || '').trim().toLowerCase() === demoForFilter
      );
    }
    if (byFor.length) {
      filtered = byFor;
      demoFor = byFor[0].demoFor || demoFor;
      addLog(`Filtered surveys by demo "${demoForFilterRaw}" (${byFor.length} found).`);
    } else {
      addLog(`No surveys found for demo "${demoForFilterRaw}".`, 'warn');
    }
  }

  if (filtered.length) {
    demoFor = demoFor || filtered[0].demoFor || '';
  }

  return {
    records: filtered.length ? filtered : records,
    demoFor
  };
}

function updateDemoSubtitle() {
  if (!demoSubtitle) return;
  demoSubtitle.textContent = demoSubtitleText || '';
  demoSubtitle.style.display = demoSubtitleText ? 'block' : 'none';
  refreshAccordionHeights();
}

function findRecordByOptionId(optionId) {
  return surveyRecords.find((record) => record.__optionId === optionId) || null;
}

function findRecordBySurveyId(surveyId) {
  if (!surveyId) return null;
  const idStr = String(surveyId).trim();
  // Search in allSurveyRecords first (before filtering)
  return allSurveyRecords.find((record) => String(record.surveyId).trim() === idStr) || null;
}

function showIdNotFoundOverlay() {
  if (!idNotFoundOverlay) return;
  idNotFoundOverlay.classList.add('is-visible');
  // Auto-hide after 4 seconds
  setTimeout(() => {
    if (idNotFoundOverlay) {
      idNotFoundOverlay.classList.remove('is-visible');
    }
  }, 4000);
}

function resolveIdentifier(record) {
  const raw = record && record.identifier ? String(record.identifier).trim() : '';
  return raw || DEFAULT_IDENTIFIER;
}

function normalizeInlineSelector(value) {
  if (value === undefined || value === null) return '';
  const trimmed = String(value).trim();
  if (!trimmed) return '';
  if (/^(null|none|undefined)$/i.test(trimmed)) return '';
  return trimmed;
}

function buildPlayerConfigForRecord(record, { excludePresent = false } = {}) {
  if (!record) return null;
  const account = resolveIdentifier(record);
  const inlineSelector = normalizeInlineSelector(record.inlineTargetSelector);
  const inlineMode =
    inlineSelector || INLINE_PATTERN.test(record.surveyTypeName || '');
  const config = {
    account,
    host: DEFAULT_PULSE_HOST,
    mode: inlineMode ? 'inline' : 'overlay',
    tagSrc: resolveProxyUrl(DEFAULT_TAG_SRC),
    present: excludePresent ? [] : (record.surveyId ? [String(record.surveyId)] : [])
  };
  const proxyOrigin = getProxyOrigin();
  if (proxyOrigin) {
    config.proxyOrigin = proxyOrigin;
  }
  const themeHref = resolveThemeHref(currentThemeHref);
  if (themeHref) {
    config.themeCss = themeHref;
  }
  if (inlineSelector) {
    config.inlineSelector = inlineSelector;
  }
  return config;
}

function playerConfigsEqual(prev, next) {
  if (!prev || !next) return false;
  const fields = ['account', 'host', 'mode', 'inlineSelector', 'themeCss', 'manualCss', 'tagSrc', 'proxyOrigin'];
  for (const field of fields) {
    if (normalizeConfigValue(prev[field]) !== normalizeConfigValue(next[field])) {
      return false;
    }
  }
  return normalizePresentList(prev.present) === normalizePresentList(next.present);
}

function normalizeConfigValue(value) {
  if (value === undefined || value === null) return '';
  return String(value);
}

function normalizePresentList(value) {
  if (!Array.isArray(value) || !value.length) return '';
  return value.map((item) => String(item)).join('|');
}

function waitForPlayerBridgeReady(timeoutMs = 10000) {
  return new Promise((resolve, reject) => {
    if (surveyBridgeReady) {
      resolve();
      return;
    }
    
    const start = Date.now();
    let lastProgressLog = 0;
    
    const checkInterval = setInterval(() => {
      if (surveyBridgeReady) {
        clearInterval(checkInterval);
        resolve();
        return;
      }
      
      const elapsed = Date.now() - start;
      if (elapsed >= timeoutMs) {
        clearInterval(checkInterval);
        reject(new Error(`Player bridge ready timeout after ${timeoutMs}ms`));
        return;
      }
      
      // Log progress every 2 seconds
      if (elapsed - lastProgressLog >= 2000) {
        lastProgressLog = elapsed;
        const seconds = Math.round(elapsed / 1000);
        addLog(
          `Waiting for player bridge... (${seconds}s/${Math.round(timeoutMs / 1000)}s)`,
          'info',
          {
            operationId: activePresentOperation?.key || 'bridge-wait',
            elapsed,
            timeout: timeoutMs
          }
        );
      }
    }, 100);
  });
}

function ensurePlayerLoadedForRecord(record, { forceReload = false, excludePresent = false } = {}) {
  if (!record || !surveyBridge || typeof surveyBridge.load !== 'function') {
    return { reloaded: false, config: null };
  }

  const config = buildPlayerConfigForRecord(record, { excludePresent });
  if (!config) {
    return { reloaded: false, config: null };
  }

  const currentConfig =
    typeof surveyBridge.getConfig === 'function' ? surveyBridge.getConfig() : null;
  const shouldReload = forceReload || !playerConfigsEqual(currentConfig, config);

  if (shouldReload) {
    surveyBridgeReady = false; // Reset ready state when reloading
    const frame = surveyBridge.load(config);
    registerPlayerFrame(frame || null);
    playerMode = config.mode === 'inline' ? 'inline' : 'overlay';
    updatePlayerOverlayLayout();
    scheduleOverlayLayoutUpdate({ immediate: true, trailing: true });
    const presentLabel =
      config.present && config.present[0] ? ` (present ${config.present[0]})` : '';
    const modeLabel = config.mode === 'inline' ? ' in inline mode' : '';
    addLog(
      `Survey player reloading for ${config.account}${presentLabel}${modeLabel}...`,
      'info',
      {
        operationId: activePresentOperation?.key || 'player-load',
        account: config.account,
        mode: config.mode,
        surveyId: config.present?.[0]
      }
    );
  }

  return { reloaded: shouldReload, config };
}

function applyIdentifier(identifier) {
  const resolved = (identifier || DEFAULT_IDENTIFIER).trim() || DEFAULT_IDENTIFIER;
  const changed = currentIdentifier !== resolved;
  currentIdentifier = resolved;
  window.PULSE_TAG_IDENTIFIER = currentIdentifier;

  if (tagReady && typeof window.pi === 'function') {
    identifierDirty = identifierDirty || changed || !identifierApplied;
    applyPendingIdentifier({ reason: changed ? 'update' : 'initial' });
  } else {
    identifierDirty = identifierDirty || changed || !identifierApplied;
    if (changed) {
      addLog(`Staged identifier ${currentIdentifier} (applies when tag ready).`);
    }
  }
}

function applyPendingIdentifier(_options = {}) {
  if (!tagReady || typeof window.pi !== 'function') return false;
  if (!identifierDirty && identifierApplied) {
    return false;
  }
  const message = identifierApplied
    ? `Updating tag identifier to ${currentIdentifier}`
    : `Applying tag identifier ${currentIdentifier}`;
  addLog(message);
  window.pi('identify', currentIdentifier);
  identifierApplied = true;
  identifierDirty = false;
  return true;
}

function clearPresentCommands({ log = false } = {}) {
  if (!blockAutoPresent) return false;
  let removed = 0;

  const prune = (queue) => {
    if (!Array.isArray(queue)) return;
    for (let index = queue.length - 1; index >= 0; index -= 1) {
      const entry = queue[index];
      const name = Array.isArray(entry) ? entry[0] : entry && (entry.command || entry.name);
      if (String(name || '').toLowerCase() === 'present') {
        queue.splice(index, 1);
        removed += 1;
      }
    }
  };

  if (typeof window.pi === 'function') {
    prune(window.pi.q);
    prune(window.pi.commands);
    prune(window.pi.queue);
  }

  if (window.PulseInsightsObject && Array.isArray(window.PulseInsightsObject.commandQueue)) {
    prune(window.PulseInsightsObject.commandQueue);
  }

  if (removed && log) {
    addLog(`Removed ${removed} auto-present command${removed === 1 ? '' : 's'} from queue.`);
  }
  return removed > 0;
}

function monitorWidgetVisibility({ surveyId, url }) {
  if (monitorWidgetVisibility.timeout) {
    clearTimeout(monitorWidgetVisibility.timeout);
  }
  // Align timeout with geometry detection timeout (4000ms base, adaptive up to 6000ms)
  // Use 4200ms to check slightly after geometry timeout to avoid false negatives
  const timeoutMs = 4200;
  monitorWidgetVisibility.timeout = window.setTimeout(() => {
    const visible = playerWidgetRect && playerWidgetRect.width > 0 && playerWidgetRect.height > 0;
    if (!visible) {
      addLog(
        `Widget geometry not detected after present. The survey ${surveyId} may rely on inline placement or is blocked by ${url ||
          'the current page context'}. Try the "Cyberhill Partners – Experience Agent Demo" if you need a guaranteed overlay.`,
        'warn'
      );
    } else {
      console.debug('[preview] widget geometry detected', playerWidgetRect);
    }
    monitorWidgetVisibility.timeout = null;
  }, timeoutMs);
  
  // Also check immediately when geometry is detected (via callback from geometry update)
  // This is handled by checking in updatePlayerWidgetGeometry when rect becomes available
}

function startPresentGuard() {
  if (presentGuardInterval) return;
  presentGuardInterval = window.setInterval(() => {
    clearPresentCommands({ log: false });
  }, 150);
}

function stopPresentGuard() {
  if (!presentGuardInterval) return;
  window.clearInterval(presentGuardInterval);
  presentGuardInterval = null;
}

function refreshDemoDirectory() {
  if (!demoDirectoryList) return;
  const groups = new Map();

  allSurveyRecords.forEach((record) => {
    const label = (record.demoFor || '').trim();
    if (!label) return;
    const key = label.toLowerCase();
    const existing = groups.get(key);
    if (existing) {
      existing.count += 1;
    } else {
      groups.set(key, { key, label, count: 1 });
    }
  });

  demoDirectoryOptions = Array.from(groups.values()).sort((a, b) =>
    a.label.localeCompare(b.label, undefined, { sensitivity: 'base' })
  );
  renderDemoDirectory();
}

function renderDemoDirectory() {
  if (!demoDirectoryList) return;
  demoDirectoryList.innerHTML = '';

  const activeKey = (demoForFilter || demoSubtitleText || '').trim().toLowerCase();
  const totalRecords = allSurveyRecords.length;

  if (!demoDirectoryOptions.length) {
    const empty = document.createElement('li');
    empty.className = 'demo-directory__empty';
    empty.textContent = totalRecords
      ? 'Demo labels unavailable for this dataset.'
      : 'Demo library will populate once the Google Sheet loads.';
    demoDirectoryList.appendChild(empty);
    return;
  }

  demoDirectoryList.appendChild(
    createDemoDirectoryOption({
      key: '',
      label: 'All demos',
      count: totalRecords || demoDirectoryOptions.reduce((sum, entry) => sum + entry.count, 0),
      active: !activeKey && !demoCodeFilter
    })
  );

  demoDirectoryOptions.forEach((entry) => {
    demoDirectoryList.appendChild(
      createDemoDirectoryOption({
        key: entry.key,
        label: entry.label,
        count: entry.count,
        active: activeKey === entry.key
      })
    );
  });
}

function createDemoDirectoryOption({ key, label, count, active = false }) {
  const li = document.createElement('li');
  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'demo-directory__option';
  button.dataset.value = key ? label : '';
  button.dataset.active = active ? 'true' : 'false';

  const title = document.createElement('span');
  title.textContent = label;
  button.appendChild(title);

  const badge = document.createElement('span');
  badge.className = 'demo-directory__count';
  badge.textContent = `${count} ${count === 1 ? 'survey' : 'surveys'}`;
  button.appendChild(badge);

  li.appendChild(button);
  return li;
}

function openDemoDirectory() {
  if (!demoDirectory || !demoDirectoryList || demoDirectoryActive || !demoDirectoryOptions.length) {
    return;
  }
  demoDirectoryActive = true;
  lastDemoDirectoryFocus =
    document.activeElement && typeof document.activeElement.focus === 'function'
      ? document.activeElement
      : null;

  renderDemoDirectory();
  demoDirectory.classList.add('open');
  demoDirectory.setAttribute('aria-hidden', 'false');

  const firstButton = demoDirectoryList.querySelector('button');
  if (firstButton) {
    window.requestAnimationFrame(() => firstButton.focus());
  }
}

function closeDemoDirectory() {
  if (!demoDirectoryActive || !demoDirectory) return;
  demoDirectoryActive = false;
  demoDirectory.classList.remove('open');
  demoDirectory.setAttribute('aria-hidden', 'true');

  if (lastDemoDirectoryFocus && typeof lastDemoDirectoryFocus.focus === 'function') {
    lastDemoDirectoryFocus.focus();
  }
  lastDemoDirectoryFocus = null;
}

function handleDemoDirectoryListClick(event) {
  const target = event.target.closest('button.demo-directory__option');
  if (!target || !demoDirectoryList.contains(target)) return;
  event.preventDefault();
  const value = target.getAttribute('data-value') || '';
  handleDemoDirectorySelection(value);
}

function handleDemoDirectorySelection(rawValue) {
  closeDemoDirectory();
  const url = new URL(window.location.href);
  const value = (rawValue || '').trim();
  if (value) {
    url.searchParams.set('demo_for', value);
    url.searchParams.delete('demo_dismissed');
  } else {
    url.searchParams.delete('demo_for');
    url.searchParams.set('demo_dismissed', 'true');
  }
  url.searchParams.delete('demo');
  url.searchParams.delete('demo_code');
  window.location.href = url.toString();
}

function handleRailToggleShortcut(event) {
  if (event.altKey || event.metaKey || event.ctrlKey) {
    return;
  }

  if (event.key === 'Escape') {
    resetSequenceBuffer();
    if (railOpen) {
      event.preventDefault();
      setRailOpen(false);
    }
    return;
  }

  const target = event.target;
  if (
    target &&
    target.closest &&
    target.closest('input, textarea, select, [contenteditable="true"]')
  ) {
    resetSequenceBuffer();
    return;
  }

  const key = (event.key || '').toLowerCase();
  if (key.length !== 1 || !/[a-z0-9]/.test(key)) {
    resetSequenceBuffer();
    return;
  }

  sequenceBuffer += key;
  if (sequenceBuffer.length > SEQUENCE_MAX_LENGTH) {
    sequenceBuffer = sequenceBuffer.slice(-SEQUENCE_MAX_LENGTH);
  }

  window.clearTimeout(sequenceTimeout);
  sequenceTimeout = window.setTimeout(resetSequenceBuffer, RAIL_SHORTCUT_RESET_MS);

  if (sequenceBuffer.endsWith(RAIL_TOGGLE_SEQUENCE)) {
    resetSequenceBuffer();
    event.preventDefault();
    const nextState = !railOpen;
    setRailOpen(nextState);
    if (nextState && railToggle && typeof railToggle.focus === 'function') {
      railToggle.focus();
    }
    return;
  }

  if (sequenceBuffer.endsWith(DEMO_LIBRARY_SEQUENCE)) {
    resetSequenceBuffer();
    event.preventDefault();
    if (demoDirectoryActive) {
      closeDemoDirectory();
    } else {
      openDemoDirectory();
    }
  }
}

function resetSequenceBuffer() {
  sequenceBuffer = '';
  if (sequenceTimeout) {
    window.clearTimeout(sequenceTimeout);
    sequenceTimeout = null;
  }
}

function handleDemoDirectoryKeydown(event) {
  if (event.key === 'Escape' && demoDirectoryActive) {
    event.preventDefault();
    closeDemoDirectory();
    return;
  }

  if (isDemoLibraryShortcut(event)) {
    event.preventDefault();
    if (demoDirectoryActive) {
      closeDemoDirectory();
    } else {
      openDemoDirectory();
    }
  }
}

function isMacLike() {
  return navigator.platform ? /mac|iphone|ipad|ipod/i.test(navigator.platform) : false;
}

function isPrimaryModifierPressed(event) {
  const isMac = isMacLike();
  return isMac ? event.metaKey : event.ctrlKey;
}

function isDemoShortcutModifierPressed(event) {
  return isPrimaryModifierPressed(event);
}

function isDemoLibraryShortcut(event) {
  if (event.key !== '.' || event.altKey) return false;
  return isDemoShortcutModifierPressed(event);
}

function applyBackgroundNormalization(records) {
  if (!Array.isArray(records)) return [];
  return records.map((record, index) => {
    const normalized = normalizeBackgroundUrl(record?.url || record?.backgroundUrl || '');
    if (!normalized) {
      const trimmedUrl = typeof record?.url === 'string' ? record.url.trim() : record.url;
      return {
        ...record,
        __rowIndex: index,
        backgroundUrl: '',
        url: trimmedUrl || ''
      };
    }
    return {
      ...record,
      __rowIndex: index,
      backgroundUrl: normalized,
      url: normalized
    };
  });
}

async function ensureBackgroundForRecord(record, { force = false, skipBridgeLoad = false } = {}) {
  const raw = resolveRecordBackgroundUrl(record);
  const normalized = normalizeBackgroundUrl(raw);

  if (!normalized) {
    addLog('No background URL resolved for record; keeping existing background.', 'warn');
    return;
  }

  // Skip reloading if background already matches (even with force=true when present parameter is set)
  if (normalized === currentBackgroundUrl && skipBridgeLoad) {
    addLog(`Background already loaded: ${normalized}`, 'info');
    return;
  }

  if (!force && normalized === currentBackgroundUrl) {
    return;
  }

  const success = await loadHostPage(normalized, { skipBridgeLoad });
  if (success) {
    currentBackgroundUrl = normalized;
    if (backgroundInput) {
      backgroundInput.value = normalized;
    }
    addLog(`Background ready: ${normalized}`);
    scheduleOverlayLayoutUpdate({ immediate: true, trailing: true });
  } else {
    addLog(`Failed to load background ${normalized}`, 'warn');
  }
}

function resolveRecordBackgroundUrl(record) {
  if (!record) return '';
  const fields = ['backgroundUrl', 'url'];
  for (const field of fields) {
    const value = record[field];
    if (typeof value === 'string' && value.trim()) {
      return value.trim();
    }
  }
  return '';
}

function shouldProxyBackground(url) {
  if (!PROXY_ORIGIN) return false;
  if (!url) return false;
  const trimmed = String(url).trim();
  if (!/^https?:\/\//i.test(trimmed)) return false;
  if (trimmed.startsWith(PROXY_ORIGIN)) return false;
  if (trimmed.includes('/proxy?url=')) return false;
  if (trimmed.startsWith('about:') || trimmed.startsWith('data:') || trimmed.startsWith('blob:')) {
    return false;
  }
  return true;
}

function buildProxySrc(url) {
  if (!url) return url;
  const trimmed = url.trim();
  if (!shouldProxyBackground(trimmed)) return trimmed;
  const base = PROXY_ORIGIN.replace(/\/$/, '');
  const encoded = encodeURIComponent(trimmed);
  if (!base) {
    return `/proxy?url=${encoded}`;
  }
  return `${base}/proxy?url=${encoded}`;
}

function normalizeBackgroundUrl(value) {
  if (!value) return '';
  let trimmed = value.trim();
  trimmed = trimmed.replace(/\.+$/, '');
  if (!trimmed) return '';
  if (/^(null|none)$/i.test(trimmed)) return '';

  if (/^https?:\/\//i.test(trimmed) || trimmed.startsWith('/')) {
    return trimmed;
  }

  if (trimmed.startsWith('./')) {
    return trimmed.replace(/^\.\//, '/');
  }

  return `/${trimmed.replace(/^\/+/, '')}`;
}

function parseCsv(text) {
  const rows = [];
  let current = '';
  let row = [];
  let insideQuotes = false;

  for (let i = 0; i < text.length; i += 1) {
    const char = text[i];

    if (insideQuotes) {
      if (char === '"') {
        if (text[i + 1] === '"') {
          current += '"';
          i += 1;
        } else {
          insideQuotes = false;
        }
      } else {
        current += char;
      }
      continue;
    }

    if (char === '"') {
      insideQuotes = true;
      continue;
    }

    if (char === ',') {
      row.push(current);
      current = '';
      continue;
    }

    if (char === '\r') {
      continue;
    }

    if (char === '\n') {
      row.push(current);
      rows.push(row);
      row = [];
      current = '';
      continue;
    }

    current += char;
  }

  if (current !== '' || row.length > 0) {
    row.push(current);
    rows.push(row);
  }

  return rows;
}


function addLog(message, level = 'info', context = {}) {
  const timestamp = new Date().toISOString();
  const operationId = context.operationId || activePresentOperation?.key || 'none';
  const surveyId = context.surveyId || activePresentOperation?.surveyId || lastSurveyRecord?.surveyId || 'none';
  const account = context.account || currentIdentifier || 'none';
  
  // Build structured log entry
  const logEntry = {
    timestamp,
    level,
    message,
    operationId,
    surveyId,
    account,
    ...context
  };
  
  // Format for display
  const timeOnly = timestamp.split('T')[1].split('.')[0];
  const parts = [
    timeOnly,
    operationId !== 'none' ? `[${operationId}]` : '',
    surveyId !== 'none' ? `survey:${surveyId}` : '',
    account !== 'none' && account !== DEFAULT_IDENTIFIER ? `account:${account}` : '',
    message
  ].filter(Boolean);
  
  const displayMessage = parts.join(' — ');
  
  const li = document.createElement('li');
  li.textContent = displayMessage;
  li.dataset.level = level;
  li.dataset.operationId = operationId;
  li.dataset.surveyId = surveyId;
  li.dataset.account = account;
  li.title = JSON.stringify(logEntry, null, 2); // Full context on hover
  
  logList.appendChild(li);
  logList.scrollTop = logList.scrollHeight;
  
  // Console logging with structured data
  const consoleMethod = level === 'error' ? 'error' : level === 'warn' ? 'warn' : 'log';
  console[consoleMethod]('[preview]', logEntry);
  
  // Store in log history for debugging
  if (!window.__previewLogHistory) {
    window.__previewLogHistory = [];
  }
  window.__previewLogHistory.push(logEntry);
  
  // Keep last 1000 entries
  if (window.__previewLogHistory.length > 1000) {
    window.__previewLogHistory.shift();
  }
}

// Helper for operation-scoped logging
function addOperationLog(operationKey, message, level = 'info', context = {}) {
  addLog(message, level, {
    ...context,
    operationId: operationKey
  });
}

// Helper for progress logging
function addProgressLog(step, total, message, context = {}) {
  const progress = `[${step}/${total}]`;
  addLog(`${progress} ${message}`, 'info', {
    ...context,
    step,
    total,
    progress: `${step}/${total}`
  });
}

function setTagStatus(text) {
  // Status elements removed from UI - function kept for compatibility but does nothing
  refreshAccordionHeights();
}

function setSurveyStatus(text) {
  // Status elements removed from UI - function kept for compatibility but does nothing
  refreshAccordionHeights();
}

function setLogVisibility(visible) {
  logVisible = Boolean(visible);
  if (!logPanel) return;
  logPanel.classList.toggle('visible', logVisible);
  refreshAccordionHeights();
}

function setRailOpen(open) {
  railOpen = Boolean(open);
  document.body.classList.toggle('rail-open', railOpen);
  if (controlRail) {
    controlRail.classList.toggle('open', railOpen);
  }
  if (railToggle) {
    railToggle.setAttribute('aria-expanded', String(railOpen));
  }
  refreshAccordionHeights();
  scheduleOverlayLayoutUpdate({ immediate: true, trailing: true });
}

/**
 * Hides the control rail completely when present parameter is active
 * This provides a cleaner presentation view without controls
 * Note: The rail may already be hidden by inline script in HTML head to prevent flash
 */
function hideControlRail() {
  if (controlRail) {
    controlRail.style.display = 'none';
    controlRail.setAttribute('aria-hidden', 'true');
  }
  // Ensure rail-open class is removed so layout calculations don't account for rail width
  document.body.classList.remove('rail-open');
  // Set data attribute for CSS targeting (may already be set by inline script)
  document.documentElement.setAttribute('data-present-mode', 'true');
}

function timestamp() {
  const now = new Date();
  return now.toLocaleTimeString();
}


function initializeBehaviorLab() {
  if (!behaviorButtonList) return;
  behaviorButtonList.innerHTML = '';
  behaviorButtons.clear();
  if (behaviorStage) {
    scrollDepthEngine.retarget(behaviorStage);
  }
  const behaviors = TRIGGER_CONFIG.filter((trigger) => trigger.id !== 'present-selected');
  behaviors.forEach((trigger) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'behavior-button';
    button.textContent = trigger.label;
    button.dataset.behaviorId = trigger.id;
    button.addEventListener('click', () => triggerBehavior(trigger.id, { source: 'button' }));
    behaviorButtonList.appendChild(button);
    behaviorButtons.set(trigger.id, button);
  });

  renderBehaviorListenerControls();

  if (behaviorPresentBtn && !behaviorPresentBtn.dataset.bound) {
    behaviorPresentBtn.dataset.bound = 'true';
    behaviorPresentBtn.addEventListener('click', () => {
      if (!surveySelect || !surveySelect.value) return;
      presentSurvey(surveySelect.value, { force: true });
      showBehaviorOverlay();
      showBehaviorMessage('Presented survey manually.', 'present');
    });
  }

  behaviorScrollArmed = true;
  behaviorRageClicks = [];
  behaviorScrollProgress = 0;
  updateBehaviorSurveyLabel();
  showBehaviorMessage(DEFAULT_BEHAVIOR_MESSAGE);
  setupBehaviorDetectors();

  if (behaviorToggle && !behaviorToggle.dataset.bound) {
    behaviorToggle.dataset.bound = 'true';
    behaviorToggle.addEventListener('click', () => showBehaviorOverlay({ focusTarget: true }));
    behaviorToggle.addEventListener('keydown', (event) => {
      if (event.key === 'Enter' || event.key === ' ') {
        event.preventDefault();
        showBehaviorOverlay({ focusTarget: true });
      }
    });
  }

  if (behaviorCloseBtn && !behaviorCloseBtn.dataset.bound) {
    behaviorCloseBtn.dataset.bound = 'true';
    behaviorCloseBtn.addEventListener('click', () => {
      hideBehaviorOverlay();
      if (behaviorToggle) {
        behaviorToggle.focus();
      }
    });
  }

  if (behaviorLab && !behaviorLab.dataset.inactivityBound) {
    behaviorLab.dataset.inactivityBound = 'true';
    const keepAlive = () => keepBehaviorOverlayAlive();
    behaviorLab.addEventListener('pointerdown', keepAlive, true);
    behaviorLab.addEventListener('pointermove', keepAlive, true);
    behaviorLab.addEventListener('wheel', keepAlive, { passive: true });
    behaviorLab.addEventListener('keydown', keepAlive, true);
    behaviorLab.addEventListener('focusin', keepAlive);
    behaviorLab.addEventListener('mouseenter', keepAlive);
  }

  if (!behaviorEscBound) {
    document.addEventListener('keydown', (event) => {
      if (event.key === 'Escape' && behaviorOverlayVisible) {
        hideBehaviorOverlay();
        if (behaviorToggle) {
          behaviorToggle.focus();
        }
      }
    });
    behaviorEscBound = true;
  }

  setBehaviorToggleVisible(true);
  hideBehaviorOverlay();
  const activeListeners = Object.keys(behaviorListenerState)
    .filter((id) => behaviorListenerState[id])
    .map((id) => BEHAVIOR_LABELS[id] || id);
  logBehavior(`Behavior Lab ready. Active listeners: ${activeListeners.join(', ') || 'none'}.`);
}

function getTriggerById(triggerId) {
  return TRIGGER_CONFIG.find((trigger) => trigger.id === triggerId) || null;
}

function updateBehaviorSurveyLabel() {
  if (!behaviorSurveyLabel || !surveySelect) return;
  const optionId = surveySelect.value;
  if (!optionId) {
    behaviorSurveyLabel.textContent = 'Select a survey to begin.';
    return;
  }
  const record = findRecordByOptionId(optionId);
  if (record) {
    behaviorSurveyLabel.textContent = record.surveyName || `Survey ${record.surveyId}`;
    return;
  }
  const selectedOption = surveySelect.options[surveySelect.selectedIndex];
  behaviorSurveyLabel.textContent = selectedOption ? selectedOption.textContent : 'Selected survey';
}

/**
 * Handle a trigger action (used by Behavior Lab)
 * @param {string} triggerId - The ID of the trigger to handle
 * @returns {boolean} True if survey was presented, false otherwise
 */
function handleTrigger(triggerId) {
  switch (triggerId) {
    case 'present-selected':
      if (!surveySelect || !surveySelect.value) {
        addLog('Trigger cancelled: no survey selected.', 'warn');
        return false;
      }
      // Check for 403 error before presenting
      if (has403Error()) {
        addLog('Trigger cancelled: Background page has 403 error. Surveys cannot be displayed on blocked pages.', 'warn');
        return false;
      }
      addLog('Trigger: Present selected survey');
      presentSurvey(surveySelect.value, { force: true });
      return true;
    case 'exit-intent':
      simulateExitIntent();
      addLog('Trigger: Simulated exit intent');
      return false;
    case 'rage-click':
      simulateRageClick();
      addLog('Trigger: Simulated rage clicks');
      return false;
    case 'scroll-depth':
      simulateScrollDepth();
      addLog('Trigger: Simulated scroll depth');
      return false;
    case 'time-delay':
      simulateTimer();
      addLog('Trigger: Started timer');
      return false;
    case 'pageview':
      simulatePageview();
      addLog('Trigger: Incremented pageview');
      return false;
    default:
      addLog(`Unknown trigger "${triggerId}"`, 'warn');
      return false;
  }
}

/**
 * Trigger a behavior and optionally present survey
 * @param {string} triggerId - The ID of the trigger behavior
 * @param {Object} options - Trigger options
 * @param {string} options.source - Source of trigger ('button', 'detected', 'present')
 * @param {string} options.detail - Optional detail message
 */
function triggerBehavior(triggerId, { source = 'button', detail } = {}) {
  if (!triggerId) return;
  const trigger = getTriggerById(triggerId);
  if (!trigger) return;
  if (source === 'detected' && !isBehaviorListenerEnabled(triggerId)) {
    return;
  }
  if (source === 'button') {
    showBehaviorOverlay({ focusTarget: true });
  }
  // handleTrigger returns true if it already presented the survey
  const surveyPresented = handleTrigger(triggerId);
  highlightBehaviorButton(triggerId);
  highlightBehaviorStage();
  const prefix = source === 'detected' ? 'Detected' : source === 'present' ? 'Presented' : 'Simulated';
  const tone = source === 'detected' ? 'detected' : source === 'present' ? 'present' : 'simulated';
  const suffix = detail ? ` — ${detail}` : '';
  showBehaviorMessage(`${prefix}: ${trigger.label}${suffix}`, tone);
  if (source === 'detected') {
    const alertLabel = BEHAVIOR_LABELS[triggerId] || trigger.label || triggerId;
    showBehaviorBanner(`Detected ${alertLabel}`);
  }
  // Only present survey if handleTrigger didn't already do it
  // For detected behaviors, always present survey if not already presented
  // But skip if background page has 403 error
  if (!surveyPresented && surveySelect && surveySelect.value && !has403Error()) {
    presentSurvey(surveySelect.value, { allowDuplicate: true });
  } else if (has403Error() && !surveyPresented) {
    addLog('Behavior trigger cancelled: Background page has 403 error. Surveys cannot be displayed on blocked pages.', 'warn');
  }
  resetBehaviorIdleTimer();
}

function highlightBehaviorButton(triggerId) {
  const button = behaviorButtons.get(triggerId);
  if (!button) return;
  button.classList.add('is-active');
  clearTimeout(button._behaviorTimeout);
  button._behaviorTimeout = window.setTimeout(() => {
    button.classList.remove('is-active');
  }, 1500);
}

function highlightBehaviorStage() {
  if (!behaviorStage) return;
  behaviorStage.classList.add('is-active');
  clearTimeout(behaviorStageTimeout);
  behaviorStageTimeout = window.setTimeout(() => {
    behaviorStage.classList.remove('is-active');
  }, 1200);
}

function scheduleBehaviorOverlayAutoHide() {
  clearTimeout(behaviorOverlayHideTimeout);
  if (!behaviorOverlayVisible) return;
  behaviorOverlayHideTimeout = window.setTimeout(() => {
    hideBehaviorOverlay();
  }, BEHAVIOR_OVERLAY_AUTO_HIDE_MS);
}

function keepBehaviorOverlayAlive() {
  if (!behaviorOverlayVisible) return;
  clearTimeout(behaviorOverlayHideTimeout);
  behaviorOverlayHideTimeout = window.setTimeout(() => {
    hideBehaviorOverlay();
  }, BEHAVIOR_OVERLAY_AUTO_HIDE_MS);
}

function setBehaviorToggleVisible(visible) {
  if (!behaviorToggle) return;
  behaviorToggle.classList.toggle('is-hidden', !visible);
  behaviorToggle.setAttribute('aria-hidden', visible ? 'false' : 'true');
  behaviorToggle.tabIndex = visible ? 0 : -1;
}

function showBehaviorOverlay({ focusTarget = false } = {}) {
  if (!behaviorLab) return;
  behaviorOverlayVisible = true;
  behaviorLab.classList.add('is-active');
  behaviorLab.setAttribute('aria-hidden', 'false');
  setBehaviorToggleVisible(false);
  if (focusTarget) {
    const target = behaviorPresentBtn || behaviorLab;
    if (target && typeof target.focus === 'function') {
      target.focus({ preventScroll: true });
    }
  }
  scheduleBehaviorOverlayAutoHide();
}

function hideBehaviorOverlay() {
  if (!behaviorLab) return;
  if (!behaviorOverlayVisible) return;
  const activeElement = document.activeElement;
  const shouldReturnFocus =
    behaviorLab && activeElement && behaviorLab.contains(activeElement) && Boolean(behaviorToggle);
  behaviorOverlayVisible = false;
  behaviorLab.classList.remove('is-active');
  behaviorLab.setAttribute('aria-hidden', 'true');
  setBehaviorToggleVisible(true);
  clearTimeout(behaviorOverlayHideTimeout);
  if (behaviorStage) {
    behaviorStage.classList.remove('is-active');
  }
  if (shouldReturnFocus && behaviorToggle) {
    behaviorToggle.focus({ preventScroll: true });
  }
}

function showBehaviorMessage(message, tone = 'info') {
  if (!behaviorMessage) return;
  const content = message || DEFAULT_BEHAVIOR_MESSAGE;
  behaviorMessage.textContent = content;
  if (tone && tone !== 'info') {
    behaviorMessage.dataset.tone = tone;
  } else {
    delete behaviorMessage.dataset.tone;
  }
  clearTimeout(behaviorMessageTimeout);
  if (tone && tone !== 'info') {
    behaviorMessageTimeout = window.setTimeout(() => {
      if (!behaviorMessage) return;
      delete behaviorMessage.dataset.tone;
      behaviorMessage.textContent = DEFAULT_BEHAVIOR_MESSAGE;
    }, 5000);
  }
}

function setupBehaviorDetectors() {
  if (!behaviorStage) return;
  if (behaviorStage.dataset.bound === 'true') {
    resetBehaviorIdleTimer();
    return;
  }
  behaviorStage.dataset.bound = 'true';

  const handlePointerLeave = (event) => {
    if (isSimulatingBehavior) return;
    noteBehaviorActivity();
    if (event.pointerType && event.pointerType !== 'mouse') return;
    const rect = behaviorStage.getBoundingClientRect();
    if (event.clientY <= rect.top + 2) {
      if (!isBehaviorListenerEnabled('exit-intent')) return;
      logBehavior('Exit intent threshold reached (cursor left stage near top edge)');
      triggerBehavior('exit-intent', {
        source: 'detected',
        detail: 'Cursor moved toward the top edge'
      });
    }
  };

  const reportScrollCapacity = () => {
    const maxScroll = behaviorStage.scrollHeight - behaviorStage.clientHeight;
    if (maxScroll <= 0) {
      logBehavior('Scroll detector armed but stage has no overflow yet. Resize the window or add more content to test scroll depth.', 'warn');
    } else {
      logBehavior(`Scroll detector ready with ${Math.round(maxScroll)}px of scrollable range.`);
    }
  };

  const handleScroll = () => {
    if (isSimulatingBehavior) return;
    noteBehaviorActivity();
    if (!isBehaviorListenerEnabled('scroll-depth')) return;
    const maxScroll = behaviorStage.scrollHeight - behaviorStage.clientHeight;
    if (maxScroll <= 0) return;
    const percent = behaviorStage.scrollTop / maxScroll;
    const percentRounded = Math.min(100, Math.max(0, Math.round(percent * 100)));
    const bucket = Math.floor(percentRounded / 10) * 10;
    if (bucket >= behaviorScrollProgress + 10) {
      behaviorScrollProgress = bucket;
      logBehavior(`Scroll progress: ~${bucket}% (scrollTop ${Math.round(behaviorStage.scrollTop)} / ${Math.round(maxScroll)}).`);
    }
    if (behaviorScrollArmed && percent >= BEHAVIOR_SCROLL_TRIGGER) {
      behaviorScrollArmed = false;
      logBehavior(`Scroll-depth threshold reached (~${Math.round(percent * 100)}%)`);
      triggerBehavior('scroll-depth', {
        source: 'detected',
        detail: `~${Math.round(percent * 100)}% depth reached`
      });
    } else if (!behaviorScrollArmed && percent <= BEHAVIOR_SCROLL_RESET) {
      behaviorScrollArmed = true;
      behaviorScrollProgress = Math.min(behaviorScrollProgress, Math.floor(BEHAVIOR_SCROLL_RESET * 100));
      logBehavior('Scroll depth dropped below reset threshold; detector re-armed.');
    }
  };

  const handleRagePointer = (event) => {
    if (isSimulatingBehavior) return;
    if (event.type === 'pointerdown' && event.button !== 0) return;
    noteBehaviorActivity();
    if (!isBehaviorListenerEnabled('rage-click')) return;
    const now = Date.now();
    const point = { time: now, x: event.clientX, y: event.clientY };
    behaviorRageClicks = behaviorRageClicks.filter((entry) => now - entry.time <= BEHAVIOR_RAGE_WINDOW);
    behaviorRageClicks.push(point);
    const cluster = behaviorRageClicks.filter(
      (entry) => Math.hypot(entry.x - point.x, entry.y - point.y) <= BEHAVIOR_RAGE_DISTANCE
    );
    if (cluster.length >= BEHAVIOR_RAGE_THRESHOLD) {
      behaviorRageClicks = [];
      logBehavior(
        `Rage click detected (${cluster.length} clicks within ${BEHAVIOR_RAGE_WINDOW}ms, radius ${BEHAVIOR_RAGE_DISTANCE}px)`
      );
      triggerBehavior('rage-click', {
        source: 'detected',
        detail: 'Rapid clicks detected on the stage'
      });
    }
  };

  const handleKeydown = () => {
    noteBehaviorActivity();
  };

  behaviorStage.addEventListener('mouseenter', noteBehaviorActivity);
  behaviorStage.addEventListener('pointermove', noteBehaviorActivity, { passive: true });
  behaviorStage.addEventListener('pointerdown', (event) => {
    noteBehaviorActivity();
    handleRagePointer(event);
  });
  behaviorStage.addEventListener('pointerenter', noteBehaviorActivity);
  behaviorStage.addEventListener('pointerleave', handlePointerLeave);
  behaviorStage.addEventListener('scroll', handleScroll, { passive: true });
  behaviorStage.addEventListener(
    'wheel',
    () => {
      if (!isBehaviorListenerEnabled('scroll-depth')) return;
      logBehavior(`Wheel event captured (scrollTop ${Math.round(behaviorStage.scrollTop)})`);
    },
    { passive: true }
  );
  behaviorStage.addEventListener('click', handleRagePointer);
  behaviorStage.addEventListener('keydown', handleKeydown);
  behaviorStage.addEventListener('focus', noteBehaviorActivity);

  if (behaviorRageBtn) {
    behaviorRageBtn.addEventListener('click', noteBehaviorActivity);
  }

  resetBehaviorIdleTimer();
  reportScrollCapacity();
}

function noteBehaviorActivity() {
  if (isSimulatingBehavior) return;
  highlightBehaviorStage();
  resetBehaviorIdleTimer();
}

function resetBehaviorIdleTimer() {
  clearTimeout(behaviorIdleTimer);
  if (!isBehaviorListenerEnabled('time-delay')) {
    behaviorIdleTimer = null;
    return;
  }
  behaviorIdleTimer = window.setTimeout(() => {
    behaviorIdleTimer = null;
    logBehavior('Idle listener fired after 10 seconds of inactivity');
    triggerBehavior('time-delay', {
      source: 'detected',
      detail: 'No interaction for 10 seconds'
    });
  }, BEHAVIOR_IDLE_MS);
}


/**
 * Simulate exit intent behavior by dispatching a mouseout event
 * Sets isolation flag to prevent behavior detectors from processing the event
 */
function simulateExitIntent() {
  isSimulatingBehavior = true;
  logBehavior('Simulating exit intent (isolation mode active)');
  const event = new MouseEvent('mouseout', {
    bubbles: true,
    clientY: 0,
    relatedTarget: null
  });
  document.dispatchEvent(event);
  // Reset flag after event has propagated but before detectors process it
  setTimeout(() => {
    isSimulatingBehavior = false;
  }, 100);
}

/**
 * Simulate rage click behavior by dispatching multiple click events
 * Sets isolation flag to prevent behavior detectors from processing the events
 */
function simulateRageClick() {
  isSimulatingBehavior = true;
  logBehavior('Simulating rage click (isolation mode active)');
  // Use a safe target that won't trigger behaviorStage handlers
  const target = document.body || document.documentElement;
  for (let i = 0; i < 6; i += 1) {
    const event = new MouseEvent('click', {
      bubbles: true,
      clientX: 200 + i,
      clientY: 200
    });
    target.dispatchEvent(event);
  }
  // Reset flag after all events are dispatched
  setTimeout(() => {
    isSimulatingBehavior = false;
  }, 100);
}

/**
 * Simulate scroll depth behavior by scrolling the behaviorStage element
 * Sets isolation flag to prevent behavior detectors from processing the scroll event
 */
function simulateScrollDepth() {
  isSimulatingBehavior = true;
  logBehavior('Simulating scroll depth (isolation mode active)');
  // Scroll behaviorStage directly if it exists, otherwise scroll window
  if (behaviorStage) {
    const maxScroll = behaviorStage.scrollHeight - behaviorStage.clientHeight;
    if (maxScroll > 0) {
      behaviorStage.scrollTo({ top: maxScroll, behavior: 'auto' });
      // Trigger scroll event on behaviorStage
      behaviorStage.dispatchEvent(new Event('scroll', { bubbles: false }));
    }
  } else {
    window.scrollTo({ top: document.documentElement.scrollHeight, behavior: 'auto' });
    window.dispatchEvent(new Event('scroll'));
  }
  // Reset flag after scroll completes
  setTimeout(() => {
    isSimulatingBehavior = false;
  }, 100);
}

/**
 * Simulate timer behavior by dispatching a pulse-timer-complete event after delay
 * Note: This does not interfere with behavior detectors as there are no listeners for this event
 */
function simulateTimer() {
  logBehavior('Simulating timer (will complete in 1.5s)');
  setTimeout(() => {
    window.dispatchEvent(new CustomEvent('pulse-timer-complete'));
    addLog('Timer completed (simulated)');
  }, 1500);
}

function simulatePageview() {
  if (window.PulseInsightsObject && typeof window.PulseInsightsObject.incrementPageviews === 'function') {
    window.PulseInsightsObject.incrementPageviews();
    addLog('Pulse pageviews incremented (PulseInsightsObject).');
  } else if (typeof window.pi === 'function') {
    window.pi('command', ['incrementPageviews']);
    addLog('Requested pageview increment via pi().');
  } else {
    addLog('Pulse tag not ready – could not increment pageviews', 'warn');
  }
}

function setThemeStylesheet(href, source = 'generated', label) {
  const existing = document.getElementById('preview-theme-css');
  if (existing && existing.parentNode) {
    unregisterStylesheet(existing);
    existing.parentNode.removeChild(existing);
  }
  if (!href) {
    currentThemeHref = null;
    applyThemeToBackgroundFrame(null);
    surveyBridge.clearTheme();
    updateCssManifest();
    refreshAccordionHeights();
    return;
  }
  const link = document.createElement('link');
  link.rel = 'stylesheet';
  link.href = href;
  link.id = 'preview-theme-css';
  if (label) {
    link.dataset.appliedLabel = label;
  }
  registerStylesheet(link, source, label);
  document.head.appendChild(link);

  currentThemeHref = href;
  applyThemeToBackgroundFrame(href);
  surveyBridge.applyTheme(link.href);

  updateCssManifest();
  refreshAccordionHeights();
}

function updateCssManifest() {
  // Applied CSS Files section removed from UI - function kept for compatibility but does nothing
  return;

  // Remove entries that no longer exist in the DOM
  Array.from(stylesheetRegistry.keys()).forEach((node) => {
    if (!document.contains(node)) {
      stylesheetRegistry.delete(node);
    }
  });

  const entries = Array.from(stylesheetRegistry.entries())
    .map(([node, meta]) => ({
      node,
      meta,
      source: meta?.source || detectStylesheetSource(node),
      label: meta?.label || computeStylesheetLabel(node),
      removable: !(meta?.nonRemovable)
    }))
    .filter((entry) => entry.node instanceof HTMLLinkElement || entry.node instanceof HTMLStyleElement);

  if (!entries.length) {
    const li = document.createElement('li');
    li.dataset.source = 'default';
    li.textContent = 'No stylesheets detected.';
    appliedCssList.appendChild(li);
    return;
  }

  entries.forEach((entry, index) => {
    const { node, source, label: textLabel, removable, meta } = entry;
    const li = document.createElement('li');
    li.dataset.source = source;

    const checkbox = document.createElement('input');
    checkbox.type = 'checkbox';
    checkbox.checked = nodeIsEnabled(node);
    checkbox.disabled = !removable;
    if (checkbox.disabled) {
      checkbox.title = 'Required stylesheet';
    } else {
      checkbox.addEventListener('change', () => toggleStylesheet(node, checkbox.checked));
    }
    const checkboxId = `css-toggle-${index}`;
    checkbox.id = checkboxId;
    li.appendChild(checkbox);

    const labelSpan = document.createElement('label');
    labelSpan.setAttribute('for', checkboxId);
    labelSpan.textContent = textLabel;
    li.appendChild(labelSpan);

    appliedCssList.appendChild(li);
  });

  refreshAccordionHeights();
}

function computeStylesheetLabel(node) {
  if (!node) return 'stylesheet';
  if (node.dataset?.appliedLabel) return node.dataset.appliedLabel;
  if (node instanceof HTMLLinkElement) {
    const href = node.href || node.getAttribute('href') || '';
    if (!href) return 'stylesheet link';
    try {
      const url = new URL(href, window.location.href);
      return url.pathname + (url.search || '');
    } catch (error) {
      return href;
    }
  }
  if (node instanceof HTMLStyleElement) {
    if (node.dataset?.href) return node.dataset.href;
    if (node.id) return `inline style (#${node.id})`;
    return 'inline style';
  }
  return 'stylesheet';
}

function detectStylesheetSource(node) {
  if (!node) return 'default';
  if (typeof node === 'string') {
    return detectStylesheetSource({ href: node });
  }
  if (node.dataset?.source) return node.dataset.source;
  const href = node.href || node.getAttribute?.('href') || node.dataset?.href || '';
  if (!href) return 'default';
  const lower = href.toLowerCase();
  if (lower.startsWith('blob:')) return 'generated';
  if (lower.includes('/preview/styles/examples/generated/')) return 'generated';
  if (lower.includes('/preview/styles/examples/curated/')) return 'examples';
  if (lower.includes('/preview/styles/generator/')) return 'generator';
  // Theme generator moved to separate repository - paths no longer available
  if (lower.includes('/lipsum_local/')) return 'host';
  if (lower.includes('/preview/dist/')) return 'default';
  if (lower.includes('/preview/themes/')) return 'default';
  return 'default';
}

function nodeIsEnabled(node) {
  if (!node) return false;
  const meta = stylesheetRegistry.get(node);
  if (meta && typeof meta.disabled === 'boolean') {
    return !meta.disabled;
  }
  if (node instanceof HTMLLinkElement || node instanceof HTMLStyleElement) {
    return !node.disabled;
  }
  return true;
}

function toggleStylesheet(node, enable) {
  if (!node) return;
  if (!stylesheetRegistry.has(node)) {
    registerStylesheet(node);
  }
  const existing = stylesheetRegistry.get(node) || {};
  if (existing.nonRemovable && !enable) {
    addLog(`Cannot disable required stylesheet: ${existing.label || computeStylesheetLabel(node)}`);
    updateCssManifest();
    return;
  }
  const source = existing.source || detectStylesheetSource(node);
  const label = existing.label || computeStylesheetLabel(node);

  if (node instanceof HTMLLinkElement || node instanceof HTMLStyleElement) {
    try {
      if (node.sheet) {
        node.sheet.disabled = !enable;
      }
    } catch (error) {
      // Ignore cross-origin sheet access issues
    }
    node.disabled = !enable;
  }

  node.dataset.source = source;
  node.dataset.appliedLabel = label;

  stylesheetRegistry.set(node, {
    node,
    source,
    label,
    disabled: !enable,
    nonRemovable: existing.nonRemovable || false
  });

  addLog(`${enable ? 'Enabled' : 'Disabled'} stylesheet: ${label}`);
  updateCssManifest();
  refreshAccordionHeights();
}

function initializeStylesheetRegistry() {
  const nodes = Array.from(document.querySelectorAll('link[rel="stylesheet"]'));
  stylesheetRegistry.clear();
  nodes.forEach((node) => registerStylesheet(node));
  updateCssManifest();
}

function initializeAccordion() {
  if (!accordionRoot) return;
  const items = Array.from(accordionRoot.querySelectorAll('.accordion-item'));
  items.forEach((item) => {
    const toggle = item.querySelector('[data-accordion-toggle]');
    const body = item.querySelector('.accordion-body');
    if (!toggle || !body) return;

    const setState = (open) => {
      item.classList.toggle('open', open);
      toggle.setAttribute('aria-expanded', String(open));
      body.style.maxHeight = open ? `${body.scrollHeight}px` : '0px';
    };

    setState(item.classList.contains('open'));

    toggle.addEventListener('click', () => {
      const willOpen = !item.classList.contains('open');
      setState(willOpen);
      refreshAccordionHeights();
    });
  });

  refreshAccordionHeights();
}

function refreshAccordionHeights() {
  if (!accordionRoot) return;
  window.requestAnimationFrame(() => {
    const bodies = accordionRoot.querySelectorAll('.accordion-item.open .accordion-body');
    bodies.forEach((body) => {
      body.style.maxHeight = `${body.scrollHeight}px`;
    });
  });
}

window.addEventListener('resize', refreshAccordionHeights);
window.addEventListener('resize', () => scheduleOverlayLayoutUpdate({ immediate: true, trailing: true }));
window.addEventListener('scroll', () => scheduleOverlayLayoutUpdate({ immediate: true }), true);

function registerStylesheet(node, source, label) {
  if (!node) return;
  const resolvedSource = source || node.dataset?.source || detectStylesheetSource(node);
  const resolvedLabel = label || node.dataset?.appliedLabel || computeStylesheetLabel(node);
  const hrefLower = (node.href || node.getAttribute?.('href') || '').toLowerCase();
  const labelLower = (resolvedLabel || '').toLowerCase();
  const nonRemovable = Boolean(node.dataset?.nonRemovable === 'true' || labelLower.includes('/generator/basic.css') || hrefLower.includes('/generator/basic.css'));

  node.dataset.source = resolvedSource;
  if (resolvedLabel) {
    node.dataset.appliedLabel = resolvedLabel;
  }
  if (nonRemovable) {
    node.dataset.nonRemovable = 'true';
  } else if (node.dataset?.nonRemovable) {
    delete node.dataset.nonRemovable;
  }

  const isEnabled = nodeIsEnabled(node);

  stylesheetRegistry.set(node, {
    node,
    source: resolvedSource,
    label: resolvedLabel,
    disabled: !isEnabled,
    nonRemovable
  });
}

function unregisterStylesheet(node) {
  if (!node) return;
  stylesheetRegistry.delete(node);
  if (node.dataset) {
    delete node.dataset.source;
    delete node.dataset.appliedLabel;
  }
}
function handlePlayerReady(event) {
  surveyBridgeReady = true;
  addLog(
    'Survey player ready',
    'info',
    {
      operationId: activePresentOperation?.key || 'bridge-ready',
      account: event?.account,
      host: event?.host,
      mode: event?.mode
    }
  );
  playerMode = event?.mode === 'inline' ? 'inline' : 'overlay';
  if (playerMode === 'inline') {
    playerWidgetRect = null;
    playerViewportSize = { width: 0, height: 0 };
  }
  // Ensure iframe is marked as positioned and process any queued geometry updates
  if (playerFrameEl) {
    requestAnimationFrame(() => {
      iframePositioned = true;
      processPendingGeometryUpdates();
    });
  }
  updatePlayerOverlayLayout();
  const resolvedTheme = resolveThemeHref(currentThemeHref);
  if (resolvedTheme) {
    surveyBridge.applyTheme(resolvedTheme);
  }
  if (pendingPresent && pendingPresent.options) {
    const record = findRecordByOptionId(pendingPresent.optionId);
    if (record) {
      sendPresentForRecord(record, pendingPresent.options);
    }
    pendingPresent = null;
  }
}

function handleBridgeStateChange(change) {
  if (!change) return;
  const reason = change.reason ? ` (${change.reason})` : '';
  const tone = change.next === 'ERROR' ? 'error' : 'info';
  addLog(`Bridge ${change.prev} → ${change.next}${reason}`, tone);
}

function handlePlayerStatus(message) {
  if (!message || message.type !== 'player-status') return;
  const { status, surveyId, source } = message;
  switch (status) {
    case 'present-queued':
      console.log('[preview] survey queued', message);
      addLog(`Survey ${surveyId} queued until tag ready (source: ${source || 'unknown'}).`);
      break;
    case 'present-called':
      console.log('[preview] survey present called', message);
      addLog(`Survey ${surveyId} present command sent (source: ${source || 'unknown'}).`);
      break;
    case 'present-error':
      console.error('[preview] survey present error', message);
      addLog(
        `Survey ${surveyId} present failed: ${message.message || 'unknown error'} (source: ${
          source || 'unknown'
        }).`,
        'error'
      );
      break;
    case 'widget-check':
      console.log('[preview] survey widget check', message);
      if (message.delay >= 2000 && !message.present) {
        addLog(
          `Survey ${surveyId} widget not detected yet (2s check, source: ${source || 'unknown'}).`,
          'warn'
        );
      }
      if (message.present && message.delay === 0) {
        addLog(`Survey ${surveyId} widget detected (source: ${source || 'unknown'}).`);
      }
      break;
    case 'widget-geometry':
      updatePlayerWidgetGeometry(message);
      break;
    default:
      break;
  }
}

function registerPlayerFrame(frame) {
  if (playerFrameEl && playerFrameEl !== frame) {
    resetPlayerOverlayLayout(playerFrameEl);
  }
  playerFrameEl = frame || null;
  iframePositioned = false;
  if (playerFrameEl) {
    playerWidgetRect = null;
    playerViewportSize = { width: 0, height: 0 };
    playerFrameEl.style.position = 'absolute';
    playerFrameEl.style.top = '0';
    playerFrameEl.style.left = '0';
    playerFrameEl.style.width = '100%';
    playerFrameEl.style.height = '100%';
    playerFrameEl.style.pointerEvents = 'none';
    playerFrameEl.style.visibility = 'hidden';
    // Mark iframe as positioned after initial layout
    requestAnimationFrame(() => {
      iframePositioned = true;
      processPendingGeometryUpdates();
    });
  }
  updatePlayerOverlayLayout();
}

function resetPlayerOverlayLayout(frame) {
  overlayFallbackActive = false;
  overlayFallbackLogged = false;
  resetWidgetFallbackStyles();
  iframePositioned = false;
  geometryRetryCount = 0;
  if (geometryRetryTimeout) {
    clearTimeout(geometryRetryTimeout);
    geometryRetryTimeout = null;
  }
  if (overlayContainer) {
    overlayContainer.style.pointerEvents = 'none';
    overlayContainer.style.visibility = 'hidden';
    overlayContainer.style.opacity = '0';
    overlayContainer.style.clipPath = '';
    overlayContainer.style.webkitClipPath = '';
    overlayContainer.style.width = '';
    overlayContainer.style.height = '';
    overlayContainer.style.top = '';
    overlayContainer.style.left = '';
    overlayContainer.style.right = '';
    overlayContainer.style.bottom = '';
    overlayContainer.style.overflow = '';
    delete overlayContainer.dataset.fallbackPlacement;
  }
  if (!frame) return;
  frame.style.pointerEvents = 'none';
  frame.style.visibility = 'hidden';
  frame.style.top = '0';
  frame.style.left = '0';
  frame.style.width = '100%';
  frame.style.height = '100%';
  frame.style.clipPath = '';
  frame.style.webkitClipPath = '';
}

function applyOverlayFallbackRect() {
  if (!overlayContainer || !playerFrameEl) return;

  const viewport = resolveFallbackViewportSize();
  
  // Check if widget is mobile-enabled - mobile widgets need full viewport overlay
  const doc = getPlayerDocument();
  const isMobileEnabled = doc?.getElementById('_pi_surveyWidgetContainer')?.classList.contains('mobile-enabled') || false;

  let placement, metrics;
  
  if (isMobileEnabled) {
    // Mobile widgets: overlay covers full viewport for transparent background
    placement = 'MOBILE';
    if (!overlayFallbackActive && !overlayFallbackLogged) {
      addLog(
        'Widget geometry unavailable; using full viewport overlay for mobile widget.',
        'warn'
      );
      overlayFallbackLogged = true;
    }
    overlayFallbackActive = true;

    overlayContainer.style.position = 'fixed';
    overlayContainer.style.visibility = 'visible';
    overlayContainer.style.opacity = '1';
    overlayContainer.style.pointerEvents = 'auto';
    overlayContainer.style.overflow = 'hidden';
    overlayContainer.style.clipPath = '';
    overlayContainer.style.webkitClipPath = '';
    overlayContainer.style.width = `${viewport.width}px`;
    overlayContainer.style.height = `${viewport.height}px`;
    overlayContainer.style.top = '0';
    overlayContainer.style.left = '0';
    overlayContainer.style.right = '';
    overlayContainer.style.bottom = '';
    overlayContainer.dataset.fallbackPlacement = placement;
  } else {
    // Desktop widgets: use computed metrics for widget-sized overlay
    placement = resolveFallbackPlacement();
    metrics = computeOverlayFallbackMetrics({
      viewportWidth: viewport.width,
      viewportHeight: viewport.height,
      placement
    });
    
    // Adjust left position to account for rail width when centering
    if (viewport.railWidth > 0 && (placement === 'CENTER' || !metrics.left && !metrics.right)) {
      // When rail is open and we're centering, add rail width to left position
      // since overlay is position:fixed relative to viewport
      if (metrics.left != null) {
        metrics.left = metrics.left + viewport.railWidth;
      } else if (metrics.right != null) {
        // If using right, subtract rail width from right
        metrics.right = metrics.right + viewport.railWidth;
      }
    }

    if (!overlayFallbackActive && !overlayFallbackLogged) {
      addLog(
        `Widget geometry unavailable; approximating overlay placement (${placement}).`,
        'warn'
      );
      overlayFallbackLogged = true;
    }
    overlayFallbackActive = true;

    overlayContainer.style.position = 'fixed';
    overlayContainer.style.visibility = 'visible';
    overlayContainer.style.opacity = '1';
    overlayContainer.style.pointerEvents = 'auto';
    overlayContainer.style.overflow = 'hidden';
    overlayContainer.style.clipPath = '';
    overlayContainer.style.webkitClipPath = '';
    overlayContainer.style.width = `${metrics.width}px`;
    overlayContainer.style.height = `${metrics.height}px`;
    overlayContainer.style.top = metrics.top != null ? `${metrics.top}px` : '';
    overlayContainer.style.left = metrics.left != null ? `${metrics.left}px` : '';
    overlayContainer.style.right = metrics.right != null ? `${metrics.right}px` : '';
    overlayContainer.style.bottom = metrics.bottom != null ? `${metrics.bottom}px` : '';
    overlayContainer.dataset.fallbackPlacement = placement;
  }

  playerFrameEl.style.pointerEvents = 'auto';
  playerFrameEl.style.visibility = 'visible';
  playerFrameEl.style.position = 'absolute';
  
  if (isMobileEnabled) {
    // For mobile widgets, iframe should cover full viewport
    playerFrameEl.style.width = `${viewport.width}px`;
    playerFrameEl.style.height = `${viewport.height}px`;
    playerFrameEl.style.top = '0';
    playerFrameEl.style.left = '0';
  } else {
    // For desktop widgets, use computed metrics
    playerFrameEl.style.width = `${metrics.frameWidth}px`;
    playerFrameEl.style.height = `${metrics.frameHeight}px`;
    playerFrameEl.style.top = `${metrics.frameTop}px`;
    playerFrameEl.style.left = `${metrics.frameLeft}px`;
  }
  
  playerFrameEl.style.clipPath = '';
  playerFrameEl.style.webkitClipPath = '';

  // Only start widget fallback styles retry if not already in progress
  // This prevents resetting the retry counter on every layout update
  // Skip for mobile-enabled widgets as they use CSS positioning
  if (!widgetFallbackTimer && !widgetFallbackApplied && !isMobileEnabled && metrics) {
    applyWidgetFallbackStyles({ placement, metrics }, 0);
  }
}

function resolveFallbackViewportSize() {
  // Get the effective viewport size, accounting for the left rail if open
  const getRailWidth = () => {
    if (typeof window === 'undefined' || typeof document === 'undefined') return 0;
    const railOpen = document.body.classList.contains('rail-open');
    if (!railOpen) return 0;
    // Get rail width from CSS variable
    const rootStyles = getComputedStyle(document.documentElement);
    const railWidth = rootStyles.getPropertyValue('--rail-width-open').trim();
    const parsed = parseInt(railWidth, 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : 380; // fallback to 380px
  };
  
  const railWidth = getRailWidth();
  const fullViewportWidth = typeof window !== 'undefined' ? window.innerWidth : null;
  const effectiveViewportWidth = fullViewportWidth && railWidth > 0 
    ? fullViewportWidth - railWidth 
    : fullViewportWidth;
  
  const widthCandidates = [
    playerViewportSize?.width,
    effectiveViewportWidth,
    typeof document !== 'undefined' ? document.documentElement?.clientWidth : null,
    overlayContainer?.offsetWidth,
    1024
  ];
  const heightCandidates = [
    playerViewportSize?.height,
    typeof window !== 'undefined' ? window.innerHeight : null,
    typeof document !== 'undefined' ? document.documentElement?.clientHeight : null,
    overlayContainer?.offsetHeight,
    768
  ];

  const resolve = (candidates, fallback) => {
    for (const candidate of candidates) {
      const value = Number(candidate);
      if (Number.isFinite(value) && value > 0) {
        return value;
      }
    }
    return fallback;
  };

  return {
    width: Math.max(1, Math.round(resolve(widthCandidates, 1024))),
    height: Math.max(1, Math.round(resolve(heightCandidates, 768))),
    railWidth: railWidth
  };
}

function resolveFallbackPlacement() {
  const fromHint = normalizePlacementToken(overlayPlacementHint);
  if (fromHint && fromHint !== 'INLINE') {
    return fromHint;
  }
  const fromRecord = derivePlacementHintFromRecord(lastSurveyRecord);
  if (fromRecord && fromRecord !== 'INLINE') {
    return fromRecord;
  }
  return 'CENTER';
}

function processPendingGeometryUpdates() {
  if (!iframePositioned || !playerFrameEl || pendingGeometryUpdates.length === 0) {
    return;
  }
  const updates = pendingGeometryUpdates.splice(0);
  updates.forEach((message) => {
    updatePlayerWidgetGeometry(message);
  });
}

function updatePlayerWidgetGeometry(message) {
  // If iframe is not ready, queue the update
  if (!iframePositioned || !playerFrameEl) {
    if (pendingGeometryUpdates.length < 5) {
      pendingGeometryUpdates.push(message);
      console.debug('[preview] geometry update queued (iframe not ready)', {
        queued: pendingGeometryUpdates.length,
        message
      });
    } else {
      console.warn('[preview] geometry update queue full, dropping update', message);
    }
    return;
  }

  const incomingMode = message?.mode === 'inline' ? 'inline' : 'overlay';
  if (incomingMode !== playerMode) {
    playerMode = incomingMode;
  }
  const placement = normalizePlacementToken(message?.placement);
  if (placement) {
    overlayPlacementHint = placement;
  }
  playerViewportSize = normalizeViewport(message?.viewport);
  const rect = normalizeWidgetRect(message?.rect);
  const hadRect = !!playerWidgetRect;
  const wasInFallback = overlayFallbackActive;
  
  // Validate geometry: if rect is invalid or missing, schedule retry
  if (!rect && playerMode === 'overlay' && !hadRect) {
    // No geometry received, schedule retry if we haven't exceeded max retries
    if (geometryRetryCount < MAX_GEOMETRY_RETRIES) {
      const retryDelay = GEOMETRY_RETRY_DELAYS[geometryRetryCount] || 2000;
      geometryRetryCount++;
      console.debug('[preview] geometry update missing rect, scheduling retry', {
        attempt: geometryRetryCount,
        delay: retryDelay,
        message
      });
      
      if (geometryRetryTimeout) {
        clearTimeout(geometryRetryTimeout);
      }
      geometryRetryTimeout = window.setTimeout(() => {
        geometryRetryTimeout = null;
        // Request geometry refresh from player
        if (surveyBridge && typeof surveyBridge.sendTrigger === 'function') {
          surveyBridge.sendTrigger('ping');
        }
        // Also retry processing this message
        updatePlayerWidgetGeometry(message);
      }, retryDelay);
      return;
    } else {
      console.warn('[preview] geometry update failed after max retries', {
        retries: geometryRetryCount,
        message
      });
      geometryRetryCount = 0;
    }
  } else if (rect) {
    // Valid geometry received, reset retry counter
    geometryRetryCount = 0;
    if (geometryRetryTimeout) {
      clearTimeout(geometryRetryTimeout);
      geometryRetryTimeout = null;
    }
  }
  
  playerWidgetRect = rect;
  if (rect) {
    overlayFallbackActive = false;
    overlayFallbackLogged = false;
    resetWidgetFallbackStyles();
    if (overlayContainer) {
      delete overlayContainer.dataset.fallbackPlacement;
    }
    // If visibility check is pending and we just got geometry, trigger immediate check
    if (monitorWidgetVisibility.timeout && rect.width > 0 && rect.height > 0) {
      clearTimeout(monitorWidgetVisibility.timeout);
      monitorWidgetVisibility.timeout = null;
      console.debug('[preview] widget geometry detected immediately', rect);
    }
  }
  // If we just got geometry after fallback was active, ensure fallback styles are applied
  // This handles the case where widget becomes available but fallback styles weren't applied yet
  if (rect && wasInFallback && !hadRect) {
    const fallbackPlacement = resolveFallbackPlacement();
    const metrics = computeOverlayFallbackMetrics({
      viewportWidth: playerViewportSize?.width || window.innerWidth,
      viewportHeight: playerViewportSize?.height || window.innerHeight,
      placement: fallbackPlacement
    });
    applyWidgetFallbackStyles({ placement: fallbackPlacement, metrics }, 0);
  }
  scheduleOverlayLayoutUpdate({ immediate: true, trailing: true, geometryUpdate: true });
}

function normalizeWidgetRect(rect) {
  if (!rect || typeof rect !== 'object') return null;
  const top = Number(rect.top);
  const left = Number(rect.left);
  const width = Number(rect.width);
  const height = Number(rect.height);
  if (![top, left, width, height].every((value) => Number.isFinite(value))) return null;
  if (width <= 0 || height <= 0) return null;
  return { top, left, width, height };
}

function normalizeViewport(viewport) {
  if (!viewport || typeof viewport !== 'object') {
    return { width: window.innerWidth, height: window.innerHeight };
  }
  const width = Number(viewport.width);
  const height = Number(viewport.height);
  return {
    width: Number.isFinite(width) && width > 0 ? width : window.innerWidth,
    height: Number.isFinite(height) && height > 0 ? height : window.innerHeight
  };
}

function derivePlacementHintFromRecord(record) {
  if (!record) return '';
  if (record.inlineTargetSelector && normalizeInlineSelector(record.inlineTargetSelector)) {
    return 'INLINE';
  }
  const candidates = [
    record.placement,
    record.surveyPlacement,
    record.surveyTypeName,
    record.surveyType,
    record.surveyTags,
    record.surveyName,
    record.demoFor,
    record.demoCode
  ];
  for (const candidate of candidates) {
    const normalized = normalizePlacementToken(candidate);
    if (normalized) {
      return normalized;
    }
  }
  return '';
}

function normalizePlacementToken(value) {
  if (value === undefined || value === null) return '';
  const raw = String(value).trim();
  if (!raw) return '';
  const upper = raw.toUpperCase();
  if (upper === 'BR' || (upper.includes('BOTTOM') && upper.includes('RIGHT'))) return 'BR';
  if (upper === 'BL' || (upper.includes('BOTTOM') && upper.includes('LEFT'))) return 'BL';
  if (upper === 'TR' || (upper.includes('TOP') && upper.includes('RIGHT'))) return 'TR';
  if (upper === 'TL' || (upper.includes('TOP') && upper.includes('LEFT'))) return 'TL';
  if (upper === 'BOTTOM') return 'BOTTOM';
  if (upper === 'TOP') return 'TOP';
  if (upper === 'CENTER' || upper === 'CENTRE' || upper === 'MIDDLE') return 'CENTER';
  const sanitized = upper.replace(/[^A-Z0-9]+/g, ' ');
  const parts = sanitized.split(/\s+/).filter(Boolean);
  const has = (keyword) => parts.includes(keyword);
  const contains = (keyword) => upper.includes(keyword);
  const bottom = has('BOTTOM') || contains('BOTTOM');
  const top = has('TOP') || contains('TOP');
  const left = has('LEFT') || contains('LEFT');
  const right = has('RIGHT') || contains('RIGHT');
  const centre = has('CENTER') || has('CENTRE') || has('MIDDLE');
  const dock = contains('DOCK');
  const bar = has('BAR');
  const overlay = has('OVERLAY') || contains('MODAL') || contains('LIGHTBOX');
  const inline = has('INLINE') || contains('INLINE');

  if (bottom && right) return 'BR';
  if (bottom && left) return 'BL';
  if (top && right) return 'TR';
  if (top && left) return 'TL';
  if (inline) return 'INLINE';
  if (dock) return 'BR';
  if (bar && bottom) return 'BOTTOM';
  if (bar && top) return 'TOP';
  if (bottom) return 'BOTTOM';
  if (top) return 'TOP';
  if (overlay) return 'CENTER';
  if (centre) return 'CENTER';
  return '';
}

function computeOverlayFallbackMetrics({ viewportWidth, viewportHeight, placement }) {
  const margin = clamp(Math.round(Math.min(viewportWidth, viewportHeight) * 0.04), 16, 48);
  const maxWidth = Math.max(260, viewportWidth - margin * 2);
  const baseWidth = Math.round(viewportWidth * 0.36);
  const width = clamp(baseWidth, Math.min(300, maxWidth), Math.min(420, maxWidth));

  const maxHeight = Math.max(360, viewportHeight - margin * 2);
  const baseHeight = Math.round(viewportHeight * 0.68);
  const height = clamp(baseHeight, Math.min(420, maxHeight), maxHeight);

  const placementToken = placement || 'CENTER';
  const alignBottom = placementToken === 'BR' || placementToken === 'BL' || placementToken === 'BOTTOM';
  const alignTop = placementToken === 'TR' || placementToken === 'TL' || placementToken === 'TOP';
  const alignRight = placementToken === 'BR' || placementToken === 'TR';
  const alignLeft = placementToken === 'BL' || placementToken === 'TL';
  const horizontalCenter =
    placementToken === 'CENTER' || placementToken === 'BOTTOM' || placementToken === 'TOP';
  const verticalCenter = placementToken === 'CENTER';

  let top = null;
  let bottom = null;
  let left = null;
  let right = null;

  if (alignBottom) {
    bottom = margin;
  } else if (alignTop) {
    top = margin;
  } else if (verticalCenter) {
    top = computeCenteredOffset(viewportHeight, height, margin);
  } else {
    bottom = margin;
  }

  if (alignRight) {
    right = margin;
  } else if (alignLeft) {
    left = margin;
  } else if (horizontalCenter) {
    left = computeCenteredOffset(viewportWidth, width, margin);
  } else {
    right = margin;
  }

  const frameWidth = Math.max(width, viewportWidth);
  const frameHeight = Math.max(height, viewportHeight);

  let frameTop;
  if (alignBottom) {
    frameTop = height - frameHeight;
  } else if (alignTop) {
    frameTop = 0;
  } else if (verticalCenter) {
    frameTop = (height - frameHeight) / 2;
  } else {
    frameTop = height - frameHeight;
  }

  let frameLeft;
  if (alignRight) {
    frameLeft = width - frameWidth;
  } else if (alignLeft) {
    frameLeft = 0;
  } else if (horizontalCenter) {
    frameLeft = (width - frameWidth) / 2;
  } else {
    frameLeft = width - frameWidth;
  }

  return {
    width: Math.max(1, Math.round(width)),
    height: Math.max(1, Math.round(height)),
    top,
    bottom,
    left,
    right,
    frameWidth: Math.max(1, Math.round(frameWidth)),
    frameHeight: Math.max(1, Math.round(frameHeight)),
    frameTop: Math.round(Math.min(0, frameTop)),
    frameLeft: Math.round(Math.min(0, frameLeft)),
    placement: placementToken
  };
}

function computeCenteredOffset(total, size, margin) {
  if (!Number.isFinite(total) || !Number.isFinite(size)) return margin;
  if (total <= size) {
    return Math.max(0, Math.round((total - size) / 2));
  }
  const ideal = Math.round((total - size) / 2);
  const minOffset = Math.max(0, margin);
  const maxOffset = Math.max(minOffset, total - size - margin);
  return clamp(ideal, minOffset, maxOffset);
}

function clamp(value, min, max) {
  const number = Number.isFinite(value) ? value : Number(min);
  let lower = Number.isFinite(min) ? min : number;
  let upper = Number.isFinite(max) ? max : number;
  if (lower > upper) {
    const temp = lower;
    lower = upper;
    upper = temp;
  }
  return Math.min(Math.max(number, lower), upper);
}

function getPlayerDocument() {
  if (!playerFrameEl) return null;
  try {
    return playerFrameEl.contentDocument || playerFrameEl.contentWindow?.document || null;
  } catch (error) {
    // Only log CORS errors once to reduce console noise
    if (!corsErrorLogged && error.name === 'SecurityError') {
      corsErrorLogged = true;
      console.warn('[preview] Unable to access player document for fallback styles (CORS blocked)', error);
    }
    return null;
  }
}

function applyWidgetFallbackStyles(context, attempt = 0) {
  if (!context || !playerFrameEl) return;
  const { placement, metrics } = context;
  const doc = getPlayerDocument();
  if (!doc) {
    // If CORS error was detected, stop retrying after a few attempts (won't resolve)
    if (corsErrorLogged && attempt >= 3) {
      return;
    }
    // Only log first 3 attempts to reduce noise
    if (attempt < 3) {
      try {
        console.debug('[preview] widget fallback waiting for player document', { attempt });
      } catch (_error) {
        /* ignore */
      }
    }
    scheduleWidgetFallbackRetry(context, attempt);
    return;
  }
  const container = doc.getElementById('_pi_surveyWidgetContainer');
  const widget = doc.getElementById('_pi_surveyWidget');
  if (!container || !widget) {
    // Only log first 3 attempts to reduce noise
    if (attempt < 3) {
      try {
        console.debug('[preview] widget fallback waiting for widget', { attempt });
      } catch (_error) {
        /* ignore */
      }
    }
    scheduleWidgetFallbackRetry(context, attempt);
    return;
  }

  // Check if mobile-enabled - skip fallback styles for mobile widgets
  // Mobile widgets use CSS positioning (top: 0, left: 0, right: 0, bottom: 0)
  // and should not have fallback styles applied that override their positioning
  const isMobileEnabled = container.classList.contains('mobile-enabled');
  if (isMobileEnabled) {
    // Mobile widgets rely on CSS for full-viewport positioning
    // Applying fallback styles would override the mobile-specific CSS
    if (attempt === 0) {
      try {
        console.debug('[preview] skipping widget fallback styles for mobile-enabled container');
      } catch (_error) {
        /* ignore */
      }
    }
    return;
  }

  if (widgetFallbackTimer) {
    clearTimeout(widgetFallbackTimer);
    widgetFallbackTimer = null;
  }

  widgetFallbackApplied = true;
  container.dataset.piFallbackPlacement = placement;
  try {
    setImportantStyle(container, 'position', 'fixed');
    setImportantStyle(container, 'top', metrics.top != null ? `${metrics.top}px` : 'auto');
    setImportantStyle(container, 'bottom', metrics.bottom != null ? `${metrics.bottom}px` : 'auto');
    setImportantStyle(container, 'left', metrics.left != null ? `${metrics.left}px` : 'auto');
    setImportantStyle(container, 'right', metrics.right != null ? `${metrics.right}px` : 'auto');
    setImportantStyle(container, 'width', `${metrics.width}px`);
    setImportantStyle(container, 'min-width', `${metrics.width}px`);
    setImportantStyle(container, 'max-width', `${metrics.width}px`);
    setImportantStyle(container, 'max-height', `${metrics.height}px`);
    setImportantStyle(container, 'margin', '0');
    setImportantStyle(container, 'padding', '0');
    setImportantStyle(container, 'display', 'flex');
    setImportantStyle(container, 'flex-direction', 'column');
    setImportantStyle(container, 'justify-content', 'flex-start');
    setImportantStyle(container, 'align-items', 'stretch');
    setImportantStyle(container, 'box-sizing', 'border-box');
    setImportantStyle(container, 'z-index', '2147483647');
    setImportantStyle(container, 'transform', 'none');
    setImportantStyle(container, 'pointer-events', 'auto');
    setImportantStyle(container, 'opacity', '1');
  } catch (error) {
    console.warn('[preview] Failed to apply widget fallback container styles', error);
  }

  try {
    setImportantStyle(widget, 'width', '100%');
    setImportantStyle(widget, 'max-width', '100%');
    setImportantStyle(widget, 'margin', '0');
    setImportantStyle(widget, 'position', 'relative');
  } catch (error) {
    console.warn('[preview] Failed to apply widget fallback styles', error);
  }

  try {
    if (doc.body) {
      setImportantStyle(doc.body, 'margin', '0');
      setImportantStyle(doc.body, 'padding', '0');
      setImportantStyle(doc.body, 'overflow', 'hidden');
      doc.body.dataset.piFallbackPlacement = placement;
    }
    if (doc.documentElement) {
      setImportantStyle(doc.documentElement, 'overflow', 'hidden');
    }
  } catch (error) {
    console.warn('[preview] Failed to apply fallback document styles', error);
  }

  try {
    console.debug('[preview] widget fallback styles applied', { placement, width: metrics.width, height: metrics.height });
  } catch (_error) {
    /* ignore */
  }
}

function scheduleWidgetFallbackRetry(context, attempt) {
  if (attempt >= 60) {
    try {
      console.warn('[preview] widget fallback retry limit reached', { context });
    } catch (_error) {
      /* ignore */
    }
    return;
  }
  if (widgetFallbackTimer) {
    clearTimeout(widgetFallbackTimer);
  }
  // Exponential backoff: start at 80ms, increase by 40ms each attempt, max 480ms
  const delay = Math.min(480, 80 + attempt * 40);
  widgetFallbackTimer = window.setTimeout(() => {
    widgetFallbackTimer = null;
    applyWidgetFallbackStyles(context, attempt + 1);
  }, delay);
}

function resetWidgetFallbackStyles() {
  if (widgetFallbackTimer) {
    clearTimeout(widgetFallbackTimer);
    widgetFallbackTimer = null;
  }
  if (!widgetFallbackApplied) return;
  widgetFallbackApplied = false;
  corsErrorLogged = false; // Reset CORS error flag when resetting fallback styles

  const doc = getPlayerDocument();
  if (!doc) return;
  const container = doc.getElementById('_pi_surveyWidgetContainer');
  const widget = doc.getElementById('_pi_surveyWidget');

  if (container) {
    [
      'position',
      'top',
      'bottom',
      'left',
      'right',
      'width',
      'minWidth',
      'maxWidth',
      'height',
      'maxHeight',
      'margin',
      'padding',
      'display',
      'flexDirection',
      'justifyContent',
      'alignItems',
      'boxSizing',
      'zIndex',
      'transform',
      'pointerEvents',
      'opacity'
    ].forEach((prop) => {
      clearImportantStyle(container, prop);
    });
    delete container.dataset.piFallbackPlacement;
  }

  if (widget) {
    ['width', 'max-width', 'margin', 'position'].forEach((prop) => {
      clearImportantStyle(widget, prop);
    });
  }

  if (doc.body) {
    try {
      ['margin', 'padding', 'overflow'].forEach((prop) => clearImportantStyle(doc.body, prop));
      delete doc.body.dataset?.piFallbackPlacement;
    } catch (_error) {
      /* ignore */
    }
  }
  if (doc.documentElement) {
    try {
      clearImportantStyle(doc.documentElement, 'overflow');
    } catch (_error) {
      /* ignore */
    }
  }
}

function setImportantStyle(element, property, value) {
  if (!element || !element.style) return;
  try {
    element.style.setProperty(property, value, 'important');
  } catch (_error) {
    /* ignore */
  }
}

function clearImportantStyle(element, property) {
  if (!element || !element.style) return;
  try {
    element.style.removeProperty(property);
  } catch (_error) {
    /* ignore */
  }
}

function scheduleOverlayLayoutUpdate({ immediate = false, trailing = false, delay = 280, geometryUpdate = false } = {}) {
  // For geometry updates, skip debouncing and update immediately
  if (geometryUpdate) {
    updatePlayerOverlayLayout();
    return;
  }
  if (immediate) {
    updatePlayerOverlayLayout();
  }
  if (typeof window !== 'undefined' && typeof window.requestAnimationFrame === 'function') {
    if (overlayLayoutRaf === null) {
      overlayLayoutRaf = window.requestAnimationFrame(() => {
        overlayLayoutRaf = null;
        updatePlayerOverlayLayout();
      });
    }
  }
  if (trailing) {
    overlayLayoutTimeout = window.setTimeout(() => {
      overlayLayoutTimeout = null;
      updatePlayerOverlayLayout();
    }, delay);
  }
}

function updatePlayerOverlayLayout() {
  // Align the player iframe to the reported widget bounds so only the survey area is interactive.
  if (!overlayContainer || !playerFrameEl) return;

  if (!playerWidgetRect || playerMode === 'inline') {
    const reason = !playerWidgetRect ? 'no-geometry' : 'inline-mode';
    // Suppress debug log for overlay layout reset to reduce console noise
    // console.debug('[preview] overlay layout reset', { reason, mode: playerMode });
    if (!playerWidgetRect && playerMode === 'overlay') {
      applyOverlayFallbackRect();
    } else {
      resetPlayerOverlayLayout(playerFrameEl);
    }
    return;
  }

  overlayFallbackActive = false;
  overlayFallbackLogged = false;
  if (overlayContainer) {
    delete overlayContainer.dataset.fallbackPlacement;
  }

  const rootRect =
    siteRoot?.getBoundingClientRect?.() || {
      top: 0,
      left: 0,
      width: overlayContainer.offsetWidth || 0,
      height: overlayContainer.offsetHeight || 0
    };

  const viewportWidth = Math.max(
    playerViewportSize.width || 0,
    rootRect.width || 0,
    playerFrameEl.offsetWidth || 0
  );
  const viewportHeight = Math.max(
    playerViewportSize.height || 0,
    rootRect.height || 0,
    playerFrameEl.offsetHeight || 0
  );

  if (viewportWidth <= 0 || viewportHeight <= 0) {
    // Suppress debug log for invalid viewport to reduce console noise
    // console.debug('[preview] overlay layout reset', {
    //   reason: 'invalid-viewport',
    //   viewportWidth,
    //   viewportHeight
    // });
    resetPlayerOverlayLayout(playerFrameEl);
    return;
  }

  const marginTop = Math.min(PLAYER_FRAME_MARGIN, playerWidgetRect.top);
  const marginLeft = Math.min(PLAYER_FRAME_MARGIN, playerWidgetRect.left);
  const marginBottom = Math.min(
    PLAYER_FRAME_MARGIN,
    Math.max(0, viewportHeight - (playerWidgetRect.top + playerWidgetRect.height))
  );
  const marginRight = Math.min(
    PLAYER_FRAME_MARGIN,
    Math.max(0, viewportWidth - (playerWidgetRect.left + playerWidgetRect.width))
  );

  // Get iframe position relative to viewport to convert widget coordinates
  // Note: This gets the iframe's current position in the main viewport
  // Since the iframe is initially positioned at (0,0) relative to overlayContainer,
  // and overlayContainer is position:fixed, iframeRect.top/left gives us overlayContainer's current position
  // Guard: Ensure iframe is positioned before using its coordinates
  if (!iframePositioned) {
    // Iframe not positioned yet, schedule retry on next frame
    console.debug('[preview] iframe not positioned yet, deferring layout update', {
      hasWidgetRect: !!playerWidgetRect,
      hasFrame: !!playerFrameEl
    });
    requestAnimationFrame(() => {
      if (playerWidgetRect && playerFrameEl) {
        updatePlayerOverlayLayout();
      }
    });
    return;
  }
  const iframeRect = playerFrameEl.getBoundingClientRect();
  
  // Validate iframe rect is valid
  if (!iframeRect || iframeRect.width === 0 || iframeRect.height === 0) {
    console.warn('[preview] invalid iframe rect, deferring layout update', {
      iframeRect,
      hasWidgetRect: !!playerWidgetRect
    });
    requestAnimationFrame(() => {
      if (playerWidgetRect && playerFrameEl) {
        updatePlayerOverlayLayout();
      }
    });
    return;
  }
  
  // Check if widget is mobile-enabled - mobile widgets need full viewport overlay
  const doc = getPlayerDocument();
  const isMobileEnabled = doc?.getElementById('_pi_surveyWidgetContainer')?.classList.contains('mobile-enabled') || false;

  // For mobile-enabled widgets, overlay should cover full viewport
  // For desktop widgets, overlay covers widget area with margins
  let containerWidth, containerHeight, containerTop, containerLeft;
  // Initialize widget viewport variables for use in debug logging
  let widgetTopViewport = 0;
  let widgetLeftViewport = 0;
  
  if (isMobileEnabled) {
    // Mobile widgets: overlay covers full viewport for transparent background
    containerWidth = viewportWidth;
    containerHeight = viewportHeight;
    containerTop = 0;
    containerLeft = 0;
  } else {
    // Desktop widgets: overlay covers widget area with margins
    // playerWidgetRect contains coordinates relative to the iframe's content viewport (0,0 at top-left of iframe content)
    // These coordinates come from getBoundingClientRect() called inside the iframe, which returns
    // coordinates relative to the iframe's viewport (the content area)
    // 
    // To get widget position in main viewport:
    // widget position in viewport = iframe position in viewport + widget position within iframe
    // getBoundingClientRect() always returns coordinates relative to the viewport, accounting for
    // all transforms and positioning contexts, so this calculation is correct.
    widgetTopViewport = iframeRect.top + playerWidgetRect.top;
    widgetLeftViewport = iframeRect.left + playerWidgetRect.left;
    
    const clippedTop = widgetTopViewport - marginTop;
    const clippedLeft = widgetLeftViewport - marginLeft;
    const clippedWidth = playerWidgetRect.width + marginLeft + marginRight;
    const clippedHeight = playerWidgetRect.height + marginTop + marginBottom;

    containerWidth = Math.max(1, Math.round(clippedWidth));
    containerHeight = Math.max(1, Math.round(clippedHeight));
    // overlayContainer is position:fixed, so positions are relative to viewport
    containerTop = Math.round(clippedTop);
    containerLeft = Math.round(clippedLeft);
  }

  overlayContainer.style.visibility = 'visible';
  overlayContainer.style.opacity = '1';
  overlayContainer.style.pointerEvents = 'auto';
  overlayContainer.style.overflow = 'hidden';
  overlayContainer.style.clipPath = '';
  overlayContainer.style.webkitClipPath = '';

  overlayContainer.style.width = `${containerWidth}px`;
  overlayContainer.style.height = `${containerHeight}px`;
  overlayContainer.style.top = `${containerTop}px`;
  overlayContainer.style.left = `${containerLeft}px`;
  overlayContainer.style.right = '';
  overlayContainer.style.bottom = '';

  playerFrameEl.style.pointerEvents = 'auto';
  playerFrameEl.style.clipPath = '';
  playerFrameEl.style.webkitClipPath = '';
  playerFrameEl.style.position = 'absolute';
  playerFrameEl.style.visibility = 'visible';
  // For the iframe, we need positions relative to overlayContainer
  // The widget is at (playerWidgetRect.left, playerWidgetRect.top) within the iframe's content
  // overlayContainer is positioned at (containerTop, containerLeft) to cover the widget area including margins
  // 
  // To align the widget correctly:
  // - overlayContainer's visible area starts at (marginTop, marginLeft) relative to its top-left
  // - Widget should appear at this visible area's top-left
  // - Widget is at (playerWidgetRect.top, playerWidgetRect.left) within iframe
  // - So iframe offset = -(playerWidgetRect.top - marginTop, playerWidgetRect.left - marginLeft)
  // This moves the iframe so the widget aligns with the visible area's top-left corner
  const iframeOffsetTop = -(playerWidgetRect.top - marginTop);
  const iframeOffsetLeft = -(playerWidgetRect.left - marginLeft);
  playerFrameEl.style.top = `${Math.round(iframeOffsetTop)}px`;
  playerFrameEl.style.left = `${Math.round(iframeOffsetLeft)}px`;
  playerFrameEl.style.width = `${Math.max(1, Math.round(viewportWidth))}px`;
  playerFrameEl.style.height = `${Math.max(1, Math.round(viewportHeight))}px`;

  console.debug('[preview] overlay layout applied', {
    widget: playerWidgetRect,
    iframeRect: {
      top: iframeRect.top,
      left: iframeRect.left,
      width: iframeRect.width,
      height: iframeRect.height
    },
    rootRect: {
      top: rootRect.top,
      left: rootRect.left,
      width: rootRect.width,
      height: rootRect.height
    },
    widgetViewport: {
      top: widgetTopViewport,
      left: widgetLeftViewport
    },
    container: {
      width: containerWidth,
      height: containerHeight,
      top: containerTop,
      left: containerLeft
    },
    iframeOffset: {
      top: iframeOffsetTop,
      left: iframeOffsetLeft
    },
    viewport: playerViewportSize,
    mode: playerMode,
    iframePositioned,
    geometryRetryCount,
    pendingGeometryUpdates: pendingGeometryUpdates.length
  });
  playerViewportSize = {
    width: viewportWidth,
    height: viewportHeight
  };
}
