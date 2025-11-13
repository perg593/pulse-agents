import { resolveProxyUrl } from '../services/proxy.js';
import { ensureInlineTarget } from './inlineTarget.js';

const PLAYER_VERSION = '2025-10-09-01';
const PLAYER_BUILD_STAMP = '2025-02-15T17:30:00Z';
const PROTOCOL_SUPPORTS = [
  'present',
  'dismiss',
  'applyTheme',
  'trigger',
  'setPlacement',
  'setTokens',
  'ping'
];

const params = new URLSearchParams(window.location.search);
const protocolDebug = ['1', 'true'].includes((params.get('playerProtocolDebug') || '').toLowerCase());

try {
  console.log('[player] bootstrap', {
    href: window.location.href,
    version: PLAYER_VERSION,
    protocolDebug,
    buildStamp: PLAYER_BUILD_STAMP
  });
} catch (_error) {
  /* ignore */
}

const account = params.get('account') || 'PI-81598442';
const host = params.get('host') || 'survey.pulseinsights.com';
const presentIds = params.getAll('present');
const presentHistory = [...presentIds];
const themeCss = params.get('themeCss');
const manualCss = params.get('manualCss');
let inlineSelector = params.get('inlineSelector') || '#inline-target';
const tagSrc = params.get('tagSrc');
const mode = (params.get('mode') || 'overlay').toLowerCase();
const DEFAULT_TAG_SRC = 'https://js.pulseinsights.com/surveys.js';
const proxyOriginParam = params.get('proxyOrigin');

if (proxyOriginParam && proxyOriginParam.trim()) {
  window.__PI_PROXY_ORIGIN__ = proxyOriginParam.trim();
}

const INLINE_HOST = document.getElementById('inline-host');
const INLINE_TARGET = document.getElementById('inline-target');
const MODE_INDICATOR = document.getElementById('player-mode');
const ACCOUNT_INDICATOR = document.getElementById('player-account');

MODE_INDICATOR.textContent = mode === 'inline' ? 'Inline' : 'Overlay';
ACCOUNT_INDICATOR.textContent = account;

if (mode === 'inline') {
  INLINE_HOST.classList.add('active');
  inlineSelector = ensureInlineTarget(inlineSelector, { document, placeholder: INLINE_TARGET });
}

window.PULSE_TAG_ACCOUNT = account;
window.PULSE_TAG_HOST = host;
const requestedTagSrc = tagSrc && tagSrc.trim() ? tagSrc : DEFAULT_TAG_SRC;
window.PULSE_TAG_SRC = resolveProxyUrl(requestedTagSrc);
window.PULSE_TAG_PRESENT_IDS = presentHistory;
window.PULSE_TAG_MODE = mode;
window.PULSE_TAG_INLINE_SELECTOR = mode === 'inline' ? inlineSelector : null;

const bootCommands = [];
if (mode === 'inline') {
  bootCommands.push(['set', 'renderInline', true]);
}
window.PULSE_TAG_BOOT_COMMANDS = bootCommands;

loadTag();

let tagReady = false;
let pendingTheme = themeCss || null;
let pendingManualCss = manualCss || null;
const pendingPresents = [];
let bridgeOrigin = resolveBridgeOrigin();
let pendingReadyAckId;
let protocolOnline = false;
let lastStatusPayload = null;
let currentPlacement = mode === 'inline' ? 'INLINE' : 'BR';
let currentTokens = {};
let geometryTarget = null;
let geometryResizeObserver = null;
let geometryIntersectionObserver = null;
let geometryMutationObserver = null;
let geometryStateSignature = '';
let lastViewportSize = { width: 0, height: 0 };
let currentGeometryState = createHiddenGeometryState();
const geometryWaiters = new Set();
let geometryTransitionHandler = null;

startGeometryTracking();
refreshGeometryState();

document.addEventListener('visibilitychange', () => {
  if (!document.hidden) {
    lastPolledViewport = { width: window.innerWidth, height: window.innerHeight };
    startViewportPolling();
    refreshGeometryState();
  } else {
    stopViewportPolling();
  }
});

window.addEventListener('resize', () => {
  refreshGeometryState();
});

// DevTools-aware viewport change detection
// DevTools opening/closing may not always trigger resize events reliably
let viewportPollInterval = null;
let lastPolledViewport = { width: window.innerWidth, height: window.innerHeight };

function startViewportPolling() {
  if (viewportPollInterval) return;
  viewportPollInterval = window.setInterval(() => {
    const currentViewport = { width: window.innerWidth, height: window.innerHeight };
    const viewportChanged = 
      Math.abs(currentViewport.width - lastPolledViewport.width) > 50 ||
      Math.abs(currentViewport.height - lastPolledViewport.height) > 50;
    
    if (viewportChanged) {
      lastPolledViewport = currentViewport;
      refreshGeometryState();
    }
  }, 500);
}

function stopViewportPolling() {
  if (viewportPollInterval) {
    clearInterval(viewportPollInterval);
    viewportPollInterval = null;
  }
}

// Start polling on load
if (!document.hidden) {
  startViewportPolling();
}

// Use ResizeObserver if available for more reliable viewport change detection
if (typeof window.ResizeObserver === 'function') {
  const viewportResizeObserver = new ResizeObserver(() => {
    refreshGeometryState();
  });
  viewportResizeObserver.observe(document.documentElement);
}

window.addEventListener('pulseinsights:ready', (event) => {
  tagReady = true;
  try {
    console.log('[player] pulseinsights ready', event?.detail);
  } catch (_error) {
    /* ignore */
  }
  if (pendingTheme) {
    applyThemeStylesheet(pendingTheme).catch(() => {});
  }
  if (pendingManualCss) {
    applyManualStylesheet(pendingManualCss).catch(() => {});
  }
  flushPendingPresents();
  // Setup link handling when Pulse Insights is ready (widgets may be rendered)
  setupCustomContentLinkHandling();
  // Setup timer-based redirect handling when Pulse Insights is ready
  try {
    setupCustomContentRedirectTimers();
  } catch (error) {
    try {
      console.error('[player] ERROR calling setupCustomContentRedirectTimers', error);
    } catch (_error) {
      /* ignore */
    }
  }
  postLegacyMessage({
    type: 'player-ready',
    account,
    host,
    mode,
    inlineSelector
  });
  if (!protocolOnline) {
    sendProtocolReady(pendingReadyAckId);
  } else {
    broadcastStatus();
  }
});

window.addEventListener('message', (event) => {
  const { data } = event;
  if (!data || typeof data !== 'object') return;
  if (data.v === 1) {
    handleProtocolMessage(event);
    return;
  }
  handleLegacyMessage(data);
});

sendProtocolHello();

function handleProtocolMessage(event) {
  const { data } = event;
  if (!data || data.v !== 1) return;

  if (bridgeOrigin && event.origin !== bridgeOrigin) {
    if (protocolDebug) {
      try {
        console.warn('[player] rejecting protocol message from unexpected origin', event.origin, bridgeOrigin);
      } catch (_error) {
        /* ignore */
      }
    }
    return;
  }

  if (!bridgeOrigin) {
    bridgeOrigin = event.origin;
  }

  if (protocolDebug) {
    try {
      console.debug('[player <-]', data);
    } catch (_error) {
      /* ignore */
    }
  }

  const { type, id, payload } = data;
  switch (type) {
    case 'init':
      handleProtocolInit(id, payload);
      break;
    case 'present':
      handleProtocolPresent(id, payload);
      break;
    case 'dismiss':
      handleProtocolDismiss(id);
      break;
    case 'applyTheme':
      handleProtocolApplyTheme(id, payload);
      break;
    case 'trigger':
      handleProtocolTrigger(id, payload);
      break;
    case 'setPlacement':
      handleProtocolSetPlacement(id, payload);
      break;
    case 'setTokens':
      handleProtocolSetTokens(id, payload);
      break;
    case 'ping':
      respondToPing(id);
      break;
    default:
      if (id) {
        sendError(id, {
          code: 'unknown_cmd',
          message: `Unsupported command "${type}"`,
          recoverable: false
        });
      }
      break;
  }
}

function handleLegacyMessage(data) {
  const { type } = data;
  switch (type) {
    case 'present': {
      if (data.surveyId) {
        const idString = String(data.surveyId);
        presentHistory.push(idString);
        window.PULSE_TAG_PRESENT_IDS = presentHistory;
        queuePresentCommand(idString, 'message');
      }
      break;
    }
    case 'command':
      if (Array.isArray(data.command) && typeof window.pi === 'function') {
        try {
          window.pi.apply(null, data.command);
        } catch (error) {
          try {
            console.error('[player] legacy command failed', data.command, error);
          } catch (_error) {
            /* ignore */
          }
        }
      }
      break;
    case 'apply-theme':
      applyThemeStylesheet(data.themeCss).catch(() => {});
      break;
    case 'clear-theme':
      applyThemeStylesheet(null).catch(() => {});
      break;
    case 'apply-manual-css':
      applyManualStylesheet(data.manualCss).catch(() => {});
      break;
    case 'clear-manual-css':
      applyManualStylesheet(null).catch(() => {});
      break;
    case 'trigger':
      if (data.triggerId) {
        try {
          runTrigger(data.triggerId);
          postLegacyStatus('trigger-fired', { triggerId: data.triggerId });
        } catch (error) {
          try {
            console.error('[player] trigger failed', data.triggerId, error);
          } catch (_error) {
            /* ignore */
          }
        }
      }
      break;
    case 'cleanup-timers':
      // Clean up redirect timers when requested by bridge
      cleanupRedirectTimers();
      break;
    default:
      break;
  }
}

function handleProtocolInit(id, payload = {}) {
  if (typeof payload.placement === 'string' && payload.placement.trim()) {
    currentPlacement = payload.placement.trim().toUpperCase();
  }
  if (typeof payload.density === 'number') {
    currentTokens.density = payload.density;
  }
  if (payload.tokens && typeof payload.tokens === 'object') {
    currentTokens = { ...currentTokens, ...sanitizeTokens(payload.tokens) };
  }
  if (id) {
    sendAckStatus(id, { capabilities: PROTOCOL_SUPPORTS, event: 'init-applied', ok: true }, { includeGeometry: false });
  }
  if (typeof id === 'string' && id) {
    pendingReadyAckId = id;
  }
  sendProtocolReady(pendingReadyAckId);
}

function handleProtocolPresent(id, payload = {}) {
  if (!id) return;
  const surveyIdRaw = payload.surveyId;
  if (!surveyIdRaw && surveyIdRaw !== 0) {
    sendError(id, {
      code: 'bad_payload',
      message: 'Missing surveyId',
      recoverable: false
    });
    return;
  }
  const surveyId = String(surveyIdRaw).trim();
  if (!surveyId) {
    sendError(id, {
      code: 'bad_payload',
      message: 'Empty surveyId',
      recoverable: false
    });
    return;
  }
  presentHistory.push(surveyId);
  window.PULSE_TAG_PRESENT_IDS = presentHistory;
  queuePresentCommand(surveyId, 'protocol', { ackId: id, force: Boolean(payload.force) });
}

function handleProtocolDismiss(id) {
  if (!id) return;
  // Clean up redirect timers when survey is dismissed
  cleanupRedirectTimers();
  
  let dismissed = false;
  if (typeof window.pi === 'function') {
    try {
      window.pi('dismiss');
      dismissed = true;
    } catch (_error) {
      // Tag may not support dismiss; fall through to DOM cleanup.
    }
  }
  if (!dismissed) {
    const widget = document.getElementById('_pi_surveyWidgetContainer');
    if (widget) {
      widget.style.display = 'none';
      dismissed = true;
    }
  }
  if (dismissed) {
    const payload = { ok: true, event: 'dismiss-called' };
    sendAckStatus(id, payload);
    broadcastStatus(payload);
  } else {
    sendError(id, {
      code: 'present_fail',
      message: 'Unable to dismiss survey',
      recoverable: true,
      hint: 'Widget may not be mounted'
    });
  }
}

function handleProtocolApplyTheme(id, payload = {}) {
  if (!id) return;
  const tasks = [];
  if (Object.prototype.hasOwnProperty.call(payload, 'href')) {
    tasks.push(applyThemeStylesheet(payload.href || null));
  }
  if (Object.prototype.hasOwnProperty.call(payload, 'css')) {
    tasks.push(applyManualStylesheet(payload.css || null));
  }
  if (payload.tokens && typeof payload.tokens === 'object') {
    currentTokens = { ...currentTokens, ...sanitizeTokens(payload.tokens) };
  }
  if (!tasks.length) {
    tasks.push(Promise.resolve());
  }
  Promise.all(tasks)
    .then(() => {
      const payload = { event: 'apply-theme-applied', ok: true };
      sendAckStatus(id, payload);
      broadcastStatus(payload);
    })
    .catch((error) => {
      sendError(id, {
        code: 'gen_fail',
        message: error?.message || 'Unable to apply theme',
        recoverable: true,
        hint: 'Verify theme asset and CSS payload'
      });
    });
}

function handleProtocolTrigger(id, payload = {}) {
  if (!id) return;
  const command = typeof payload.command === 'string' ? payload.command : '';
  if (!command) {
    sendError(id, {
      code: 'bad_payload',
      message: 'Missing command',
      recoverable: true
    });
    return;
  }
  try {
    runTrigger(command, Array.isArray(payload.args) ? payload.args : []);
    postLegacyStatus('trigger-fired', { triggerId: command });
    sendAckStatus(id, { event: `trigger-${command}`, ok: true }, { includeGeometry: false });
  } catch (error) {
    sendError(id, {
      code: 'unknown_cmd',
      message: error?.message || 'Trigger failed',
      recoverable: true
    });
  }
}

function handleProtocolSetPlacement(id, payload = {}) {
  if (!id) return;
  const placement = typeof payload.placement === 'string' ? payload.placement.trim().toUpperCase() : '';
  if (!placement) {
    sendError(id, {
      code: 'bad_payload',
      message: 'placement is required',
      recoverable: true
    });
    return;
  }
  currentPlacement = placement;
  const state = captureWidgetGeometryState();
  const payloadOut = { placement, event: 'set-placement', ok: true };
  sendAckStatus(id, payloadOut, { geometryOverride: state });
  broadcastStatus(payloadOut, { geometryOverride: state });
}

function handleProtocolSetTokens(id, payload = {}) {
  if (!id) return;
  currentTokens = { ...currentTokens, ...sanitizeTokens(payload) };
  sendAckStatus(id, { event: 'set-tokens', ok: true }, { includeGeometry: false });
}

function queuePresentCommand(id, source = 'unknown', options = {}) {
  if (!id) return;
  const entry = { id, source, options };
  if (!tagReady || typeof window.pi !== 'function') {
    pendingPresents.push(entry);
    reportPresentQueued(id, source);
    return;
  }
  executePresent(entry);
}

function flushPendingPresents() {
  if (!pendingPresents.length) return;
  const batch = pendingPresents.splice(0, pendingPresents.length);
  batch.forEach((entry) => executePresent(entry));
}

function executePresent(entry) {
  const { id, source, options = {} } = entry;
  const ackId = options.ackId;
  try {
    window.pi('present', id);
    reportPresentCalled(id, source, ackId);
  } catch (error) {
    reportPresentError(id, source, error, ackId);
  }
}

function reportPresentQueued(id, source) {
  try {
    console.log('[player] present queued', { id, source });
  } catch (_error) {
    /* ignore console issues */
  }
  postLegacyStatus('present-queued', { surveyId: id, source });
}

function reportPresentCalled(id, source, ackId) {
  try {
    console.log('[player] present called', { id, source });
  } catch (_error) {
    /* ignore console issues */
  }
  postLegacyStatus('present-called', { surveyId: id, source });
      scheduleWidgetCheck(id, source, 0);
      scheduleWidgetCheck(id, source, 800);
      scheduleWidgetCheck(id, source, 2000);
      finalizePresentAck(ackId, { event: 'present-called', surveyId: id, ok: true });
}

function reportPresentError(id, source, error, ackId) {
  const message = error && error.message ? error.message : String(error);
  try {
    console.error('[player] present error', { id, source, error });
  } catch (_error) {
    /* ignore console issues */
  }
  postLegacyStatus('present-error', { surveyId: id, source, message });
  if (ackId) {
    sendError(ackId, {
      code: 'present_fail',
      message,
      recoverable: true,
      hint: 'Check survey configuration'
    });
  }
}

function finalizePresentAck(ackId, extra = {}) {
  if (!ackId) {
    broadcastStatus(extra);
    return;
  }
  // Adaptive timeout: increase if page seems slow or DevTools might be open
  // Base timeout increased from 2400ms to 4000ms for better reliability
  let timeoutMs = 4000;
  
  // Detect slow rendering: if page load took long, extend timeout
  if (typeof window.performance !== 'undefined' && window.performance.timing) {
    const loadTime = window.performance.timing.loadEventEnd - window.performance.timing.navigationStart;
    if (loadTime > 3000) {
      timeoutMs = 6000; // Extend timeout for slow pages
    }
  }
  
  // Detect potential DevTools: if outerHeight significantly different from innerHeight
  // This suggests DevTools might be open (though not always reliable)
  if (typeof window.outerHeight !== 'undefined' && window.outerHeight > 0) {
    const heightDiff = window.outerHeight - window.innerHeight;
    if (heightDiff > 200 || heightDiff < -200) {
      timeoutMs = Math.max(timeoutMs, 5000); // Extend timeout if DevTools might be affecting layout
    }
  }
  
  waitForVisibleGeometry(timeoutMs).then((geometryState) => {
    const snapshot = geometryState || captureWidgetGeometryState();
    const payload = { ok: true, ...extra };
    sendAckStatus(ackId, payload, { geometryOverride: snapshot });
    broadcastStatus(payload, { geometryOverride: snapshot });
  });
}

function runTrigger(triggerId, args = []) {
  const handlers = {
    'present-selected': () => {
      if (presentHistory.length > 0) {
        const recent = presentHistory[presentHistory.length - 1];
        queuePresentCommand(recent, 'trigger');
      }
    },
    'exit-intent': simulateExitIntent,
    'rage-click': simulateRageClick,
    'scroll-depth': simulateScrollDepth,
    'time-delay': simulateTimer,
    'pageview': simulatePageview,
    simulateExitIntent,
    simulateRageClick,
    simulateScrollDepth,
    simulateIdle,
    simulateTimer,
    simulatePageview,
    simulateCheckoutAbandon,
    simulateReturningVisitor,
    simulatePricingHesitation,
    simulateSupportFrustration
  };

  const handler = handlers[triggerId];
  if (handler) {
    const callArgs = Array.isArray(args) ? args : [args];
    handler(...callArgs);
    return;
  }
  if (typeof window.pi === 'function') {
    const callArgs = Array.isArray(args) ? args : [args];
    window.pi(triggerId, ...callArgs);
    return;
  }
  throw new Error(`Trigger "${triggerId}" not supported`);
}

function simulateExitIntent() {
  const event = new MouseEvent('mouseout', {
    bubbles: true,
    clientY: 0,
    relatedTarget: null
  });
  document.dispatchEvent(event);
  postLegacyStatus('exit-intent-simulated', {});
}

function simulateRageClick() {
  const target = document.body;
  for (let i = 0; i < 6; i += 1) {
    const event = new MouseEvent('click', {
      bubbles: true,
      clientX: 200 + i,
      clientY: 200
    });
    target.dispatchEvent(event);
  }
  postLegacyStatus('rage-click-simulated', { clicks: 6 });
}

function simulateScrollDepth(options = {}) {
  const percent = normalizePercent(options, 60);
  const doc = document.documentElement;
  const scrollable = Math.max(0, doc.scrollHeight - window.innerHeight);
  const target = Math.round((percent / 100) * scrollable);
  window.scrollTo({ top: target, behavior: 'auto' });
  window.dispatchEvent(new Event('scroll'));
  postLegacyStatus('scroll-depth-hit', { percent, offset: target });
}

function simulateTimer(options = {}) {
  const config = normalizeTimerConfig(options, 1500);
  if (!config.silent) {
    postLegacyStatus('timer-start', { duration: config.duration, label: config.label || null });
  }
  setTimeout(() => {
    postLegacyStatus('timer-complete', { duration: config.duration, label: config.label || null });
  }, config.duration);
}

function simulateIdle(options = {}) {
  const config = normalizeTimerConfig(options, 10000);
  const seconds = Math.round(config.duration / 100) / 10;
  postLegacyStatus('idle-start', { seconds, declared: config.declaredSeconds ?? null });
  simulateTimer({ ...config, label: 'Idle detector', silent: true });
  setTimeout(() => {
    postLegacyStatus('idle-complete', { seconds, declared: config.declaredSeconds ?? null });
    if (!config.silent) {
      postLegacyStatus('timer-complete', { duration: config.duration, label: 'Idle detector' });
    }
  }, config.duration);
}

function simulatePageview() {
  if (window.PulseInsightsObject && typeof window.PulseInsightsObject.incrementPageviews === 'function') {
    window.PulseInsightsObject.incrementPageviews();
  }
  postLegacyStatus('pageview-increment', {});
}

function simulateCheckoutAbandon() {
  const scenario = 'checkout_abandon';
  runScenarioTimeline(scenario, [
    {
      delay: 0,
      status: 'scenario-progress',
      data: { step: 'cart_add', detail: { items: 3, subtotal: 248 } }
    },
    {
      delay: 420,
      status: 'scenario-progress',
      data: { step: 'checkout_shipping', detail: { method: 'Express', completion: 'shipping' } }
    },
    {
      delay: 920,
      status: 'scenario-progress',
      data: { step: 'payment_idle', detail: { idleSeconds: 12 } },
      action: () => simulateTimer({ seconds: 12, silent: true, label: 'Payment focus' })
    },
    {
      delay: 1360,
      status: 'scenario-progress',
      data: { step: 'exit_intent', detail: { location: 'payment' } },
      action: () => simulateExitIntent()
    },
    {
      delay: 1760,
      status: 'scenario-qualified',
      data: { rule: 'checkout_abandonment', confidence: 0.88 }
    },
    {
      delay: 2040,
      action: () => {
        const presented = presentMostRecentSurvey('scenario:checkout_abandon');
        postScenarioStatus('scenario-action', scenario, {
          action: 'present',
          success: presented,
          detail: presented
            ? 'Auto-presented most recent survey.'
            : 'No recent present — launch an agent, then rerun.'
        });
      }
    }
  ]);
}

function simulateReturningVisitor() {
  const scenario = 'returning_visitor';
  runScenarioTimeline(scenario, [
    {
      delay: 0,
      status: 'scenario-progress',
      data: { step: 'session_summary', detail: { visitsLast7Days: 3, totalPageviews: 11 } },
      action: () => simulatePageview()
    },
    {
      delay: 480,
      status: 'scenario-progress',
      data: { step: 'pricing_dwell', detail: { seconds: 18 } },
      action: () => simulateScrollDepth({ percent: 82 })
    },
    {
      delay: 980,
      status: 'scenario-progress',
      data: { step: 'account_match', detail: { plan: 'scale', seats: 45 } }
    },
    {
      delay: 1480,
      status: 'scenario-qualified',
      data: { rule: 'returning_high_intent', confidence: 0.92 }
    },
    {
      delay: 1880,
      action: () => {
        const presented = presentMostRecentSurvey('scenario:returning_visitor');
        postScenarioStatus('scenario-action', scenario, {
          action: 'present',
          success: presented,
          detail: presented
            ? 'Re-engagement survey presented automatically.'
            : 'Select and present an agent, then rerun to auto-fire.'
        });
      }
    }
  ]);
}

function simulatePricingHesitation() {
  const scenario = 'pricing_hesitation';
  runScenarioTimeline(scenario, [
    {
      delay: 0,
      status: 'scenario-progress',
      data: { step: 'switch_plan', detail: { from: 'Growth', to: 'Enterprise' } }
    },
    {
      delay: 420,
      status: 'scenario-progress',
      data: { step: 'billing_toggle', detail: { billing: 'annual' } }
    },
    {
      delay: 880,
      status: 'scenario-progress',
      data: { step: 'hover_comparison', detail: { modulesOpened: 3 } },
      action: () => simulateScrollDepth({ percent: 75 })
    },
    {
      delay: 1320,
      status: 'scenario-progress',
      data: { step: 'pause_on_cta', detail: { idleSeconds: 8 } },
      action: () => simulateIdle({ seconds: 8, silent: true })
    },
    {
      delay: 1740,
      status: 'scenario-qualified',
      data: { rule: 'pricing_hesitation', confidence: 0.86 }
    },
    {
      delay: 2060,
      action: () => {
        const presented = presentMostRecentSurvey('scenario:pricing_hesitation');
        postScenarioStatus('scenario-action', scenario, {
          action: 'present',
          success: presented,
          detail: presented
            ? 'Decision support survey presented.'
            : 'Trigger a survey manually once, then rerun to auto-present.'
        });
      }
    }
  ]);
}

function simulateSupportFrustration() {
  const scenario = 'support_struggle';
  runScenarioTimeline(scenario, [
    {
      delay: 0,
      status: 'scenario-progress',
      data: { step: 'search', detail: { query: 'cancel account', results: 0 } }
    },
    {
      delay: 520,
      status: 'scenario-progress',
      data: { step: 'search', detail: { query: 'downgrade plan', results: 0 } }
    },
    {
      delay: 980,
      status: 'scenario-progress',
      data: { step: 'rage_click', detail: { element: 'contact link' } },
      action: () => simulateRageClick()
    },
    {
      delay: 1420,
      status: 'scenario-qualified',
      data: { rule: 'support_escalation', confidence: 0.9 }
    },
    {
      delay: 1760,
      action: () => {
        const presented = presentMostRecentSurvey('scenario:support_struggle');
        postScenarioStatus('scenario-action', scenario, {
          action: 'present',
          success: presented,
          detail: presented
            ? 'Concierge assist survey presented.'
            : 'Present a survey once to seed the scenario auto-fire.'
        });
      }
    }
  ]);
}

function runScenarioTimeline(scenarioId, steps = []) {
  let elapsed = 0;
  steps.forEach((step) => {
    const delay = typeof step.delay === 'number' && Number.isFinite(step.delay) ? Math.max(0, step.delay) : 0;
    elapsed += delay;
    window.setTimeout(() => {
      if (step.status) {
        postScenarioStatus(step.status, scenarioId, step.data || {});
      }
      if (typeof step.action === 'function') {
        try {
          step.action();
        } catch (_error) {
          /* ignore */
        }
      }
    }, elapsed);
  });
}

function postScenarioStatus(status, scenarioId, data = {}) {
  postLegacyStatus(status, { scenarioId, ...data });
}

function presentMostRecentSurvey(source = 'scenario') {
  if (!presentHistory.length) return false;
  const recent = presentHistory[presentHistory.length - 1];
  if (!recent) return false;
  queuePresentCommand(recent, source);
  return true;
}

function normalizePercent(input, fallback = 60) {
  const clamp = (value) => Math.min(100, Math.max(5, value));
  if (Array.isArray(input) && input.length > 0) {
    return normalizePercent(input[0], fallback);
  }
  if (typeof input === 'number' && Number.isFinite(input)) {
    return clamp(input);
  }
  if (typeof input === 'string' && input.trim()) {
    const parsed = Number.parseFloat(input.trim());
    if (Number.isFinite(parsed)) {
      return clamp(parsed);
    }
  }
  if (input && typeof input === 'object') {
    if (typeof input.percent === 'number' && Number.isFinite(input.percent)) {
      return clamp(input.percent);
    }
    if (typeof input[0] === 'number' && Number.isFinite(input[0])) {
      return clamp(input[0]);
    }
  }
  return clamp(fallback);
}

function normalizeTimerConfig(input, fallbackMs) {
  const clamp = (value) => Math.max(250, Math.min(value, 4000));
  let source = input;
  if (Array.isArray(source) && source.length > 0) {
    source = source[0];
  }
  let duration = fallbackMs;
  let label = null;
  let silent = false;
  let declaredSeconds = null;

  if (typeof source === 'number' && Number.isFinite(source)) {
    duration = source;
  } else if (source && typeof source === 'object') {
    if (typeof source.milliseconds === 'number' && Number.isFinite(source.milliseconds)) {
      duration = source.milliseconds;
    } else if (typeof source.seconds === 'number' && Number.isFinite(source.seconds)) {
      declaredSeconds = source.seconds;
      duration = source.seconds * 1000;
    } else if (typeof source.duration === 'number' && Number.isFinite(source.duration)) {
      duration = source.duration;
    }
    if (typeof source.label === 'string' && source.label.trim()) {
      label = source.label.trim();
    }
    if (Object.prototype.hasOwnProperty.call(source, 'silent')) {
      silent = Boolean(source.silent);
    }
  }

  if (typeof source === 'string' && source.trim()) {
    const parsed = Number.parseFloat(source.trim());
    if (Number.isFinite(parsed)) {
      duration = parsed;
    }
  }

  return {
    duration: clamp(duration || fallbackMs || 1500),
    label,
    silent,
    declaredSeconds
  };
}

function sendProtocolHello() {
  if (!ensureBridgeOrigin()) {
    window.setTimeout(sendProtocolHello, 16);
    return;
  }
  postProtocolMessage('hello', {
    playerVersion: PLAYER_VERSION,
    supports: PROTOCOL_SUPPORTS
  });
}

function sendProtocolReady(initId) {
  if (protocolOnline) return;
  protocolOnline = true;
  const readyId = typeof initId === 'string' && initId ? initId : undefined;
  pendingReadyAckId = undefined;
  postProtocolMessage('ready', { playerVersion: PLAYER_VERSION }, readyId);
  broadcastStatus({ event: 'player-ready', ok: true }, { includeGeometry: false });
}

function sendAckStatus(id, extra = {}, options = {}) {
  if (!id) return;
  const payload = composeStatusPayload(extra, options);
  postProtocolMessage('status', payload, id);
  lastStatusPayload = payload;
}

function broadcastStatus(extra = {}, options = {}) {
  const payload = composeStatusPayload(extra, options);
  postProtocolMessage('status', payload);
  lastStatusPayload = payload;
}

function sendError(id, detail = {}) {
  if (!id) return;
  const payload = {
    code: detail.code || 'unknown_cmd',
    message: detail.message || 'Unexpected error',
    recoverable: detail.recoverable,
    hint: detail.hint
  };
  postProtocolMessage('error', payload, id);
}

function respondToPing(id) {
  if (!id) return;
  sendAckStatus(id, { ok: true, event: 'pong-ack' }, { includeGeometry: false });
  postProtocolMessage('pong', {}, id);
}

function composeStatusPayload(extra = {}, options = {}) {
  const payload = { ok: true, ...extra };
  const includeGeometry = options.includeGeometry !== false;
  let geometry = options.geometryOverride;
  if (!geometry && includeGeometry) {
    geometry = captureWidgetGeometryState();
  } else if (!includeGeometry && !geometry) {
    geometry = { placement: currentPlacement };
  }
  if (geometry && geometry.widget && payload.widget === undefined) {
    payload.widget = geometry.widget;
  }
  if (geometry && geometry.placement && payload.placement === undefined) {
    payload.placement = geometry.placement;
  }
  return payload;
}

function captureWidgetGeometryState() {
  return cloneGeometryState(currentGeometryState);
}

function detectPlacement(widget) {
  if (!widget) return currentPlacement;
  const datasetPlacement =
    (widget.dataset && (widget.dataset.piPlacement || widget.dataset.piPosition)) || widget.getAttribute('data-pi-placement');
  if (datasetPlacement && datasetPlacement.trim()) {
    return datasetPlacement.trim().toUpperCase();
  }
  const className = widget.className || '';
  if (/\bpi-widget--position-br\b/i.test(className)) return 'BR';
  if (/\bpi-widget--position-bl\b/i.test(className)) return 'BL';
  if (/\bpi-widget--position-tr\b/i.test(className)) return 'TR';
  if (/\bpi-widget--position-tl\b/i.test(className)) return 'TL';
  return currentPlacement;
}

function sanitizeTokens(tokens) {
  const result = {};
  if (!tokens || typeof tokens !== 'object') {
    return result;
  }
  if (typeof tokens.brand === 'string') result.brand = tokens.brand;
  if (typeof tokens.radius === 'number') result.radius = tokens.radius;
  if (typeof tokens.density === 'number') result.density = tokens.density;
  return result;
}

function startGeometryTracking() {
  if (geometryMutationObserver) return;
  geometryMutationObserver = new MutationObserver(() => {
    refreshGeometryTarget();
  });
  geometryMutationObserver.observe(document.body, { childList: true, subtree: true });
  window.addEventListener('scroll', () => refreshGeometryState(), true);
  refreshGeometryTarget();
}

function findPreferredGeometryNode() {
  const candidates = [];
  const container = document.getElementById('_pi_surveyWidgetContainer');
  const primaryIds = [
    '_pi_surveyWidget',
    '_pi_surveyWidgetCustom',
    '_pi_modalWidgetContainer',
    '_pi_inlineWidget',
    '_pi_surveyInvite'
  ];

  primaryIds.forEach((id) => {
    const node = document.getElementById(id);
    if (node && document.body.contains(node)) {
      candidates.push(node);
    }
  });

  const attributeCandidates = document.querySelectorAll(
    '[data-pi-widget-root], [data-pi-widget], .pi-widget-inline, .pi-widget-modal, .pi-widget-docked'
  );
  attributeCandidates.forEach((node) => {
    if (node && document.body.contains(node)) {
      candidates.push(node);
    }
  });

  if (container && document.body.contains(container)) {
    const nested = container.querySelector(
      '#_pi_surveyWidget, #_pi_surveyWidgetCustom, [data-pi-widget-root], .pi-widget-inline, .pi-widget-modal'
    );
    if (nested && document.body.contains(nested)) {
      candidates.push(nested);
    }
    candidates.push(container);
  }

  let fallback = null;
  for (const node of candidates) {
    if (!node) continue;
    if (!document.body.contains(node)) continue;
    if (isMeasurableGeometryNode(node)) {
      return node;
    }
    fallback = fallback || node;
  }
  return fallback;
}

function isMeasurableGeometryNode(node) {
  if (!node) return false;
  try {
    const rect = node.getBoundingClientRect();
    if (rect && rect.width > 1 && rect.height > 1) {
      return true;
    }
    if (rect && rect.width > 0 && rect.height > 0) {
      const style = window.getComputedStyle(node);
      if (!style) return true;
      if (style.display !== 'none' && style.visibility !== 'hidden' && style.visibility !== 'collapse') {
        const opacity = Number.parseFloat(style.opacity || '1');
        return opacity > 0.01;
      }
    }
  } catch (_error) {
    // ignore measurement errors; fall back to style inspection below
  }
  try {
    const style = window.getComputedStyle(node);
    if (!style) return false;
    if (style.display === 'none') return false;
    if (style.visibility === 'hidden' || style.visibility === 'collapse') return false;
    const opacity = Number.parseFloat(style.opacity || '1');
    return opacity > 0.01;
  } catch (_error) {
    // if computed styles are inaccessible, err on the side of measuring
  }
  return false;
}

function refreshGeometryTarget() {
  const widget = findPreferredGeometryNode();
  if (!widget) {
    detachGeometryObservers();
    updateGeometryState(createHiddenGeometryState());
    return;
  }
  if (geometryTarget === widget) {
    refreshGeometryState(widget);
    return;
  }
  attachGeometryObservers(widget);
}

function attachGeometryObservers(widget) {
  detachGeometryObservers();
  geometryTarget = widget;

  if (typeof window.ResizeObserver === 'function') {
    geometryResizeObserver = new window.ResizeObserver(() => {
      refreshGeometryState(widget);
    });
    geometryResizeObserver.observe(widget);
  } else {
    geometryResizeObserver = null;
  }

  if (typeof window.IntersectionObserver === 'function') {
    geometryIntersectionObserver = new window.IntersectionObserver(
      (entries) => {
        const entry = entries && entries[0];
        refreshGeometryState(widget, entry);
      },
      { threshold: [0, 0.01, 0.1, 0.25, 0.5, 0.75, 1] }
    );
    geometryIntersectionObserver.observe(widget);
  } else {
    geometryIntersectionObserver = null;
  }

  geometryTransitionHandler = () => refreshGeometryState(widget);
  widget.addEventListener('transitionend', geometryTransitionHandler, true);
  refreshGeometryState(widget);
}

function detachGeometryObservers() {
  if (geometryResizeObserver) {
    geometryResizeObserver.disconnect();
    geometryResizeObserver = null;
  }
  if (geometryIntersectionObserver) {
    geometryIntersectionObserver.disconnect();
    geometryIntersectionObserver = null;
  }
  if (geometryTarget && geometryTransitionHandler) {
    geometryTarget.removeEventListener('transitionend', geometryTransitionHandler, true);
  }
  geometryTransitionHandler = null;
  geometryTarget = null;
}

function refreshGeometryState(target = geometryTarget, intersectionEntry = null) {
  if (!target || !document.body.contains(target)) {
    console.debug('[player] geometry target missing or detached, creating hidden state');
    updateGeometryState(createHiddenGeometryState());
    return;
  }
  const rect = target.getBoundingClientRect();
  const computed = window.getComputedStyle(target);
  const area = rect.width * rect.height;
  const visibility = computed.visibility;
  const display = computed.display;
  const opacity = Number.parseFloat(computed.opacity || '1');
  let isVisible =
    area > 0 &&
    visibility !== 'hidden' &&
    visibility !== 'collapse' &&
    display !== 'none' &&
    opacity > 0.01;
  if (intersectionEntry) {
    isVisible = isVisible && intersectionEntry.isIntersecting && intersectionEntry.intersectionRatio > 0;
  }
  const placement = detectPlacement(target);
  const state = {
    widget: isVisible
      ? {
          visible: true,
          bounds: {
            x: round(rect.left),
            y: round(rect.top),
            w: round(rect.width),
            h: round(rect.height)
          }
        }
      : { visible: false },
    placement
  };
  
  // Log visibility determination for debugging
  if (!isVisible && area > 0) {
    console.debug('[player] widget not visible despite area', {
      area,
      visibility,
      display,
      opacity,
      isIntersecting: intersectionEntry?.isIntersecting,
      intersectionRatio: intersectionEntry?.intersectionRatio
    });
  }
  
  updateGeometryState(state);
}

function updateGeometryState(state) {
  const currentViewport = {
    width: window.innerWidth || 0,
    height: window.innerHeight || 0
  };
  const viewportChanged = 
    Math.abs(currentViewport.width - lastViewportSize.width) > 1 ||
    Math.abs(currentViewport.height - lastViewportSize.height) > 1;
  
  const signature = computeGeometrySignature(state.widget, currentViewport);
  const signatureMatches = signature === geometryStateSignature;
  
  // Force update if viewport changed, even if widget coordinates are the same
  if (signatureMatches && !viewportChanged) {
    return;
  }
  
  // Log geometry state changes for debugging
  if (viewportChanged) {
    console.debug('[player] viewport size changed, forcing geometry update', {
      previous: lastViewportSize,
      current: currentViewport,
      widgetVisible: state.widget?.visible
    });
  }
  
  geometryStateSignature = signature;
  lastViewportSize = currentViewport;
  currentGeometryState = cloneGeometryState(state);
  
  console.debug('[player] geometry state updated', {
    widgetVisible: state.widget?.visible,
    widgetBounds: state.widget?.bounds,
    placement: state.placement,
    viewport: currentViewport,
    signature
  });
  
  broadcastStatus({}, { geometryOverride: currentGeometryState });
  postLegacyStatus('widget-geometry', buildLegacyGeometryPayload(currentGeometryState));
  resolveGeometryWaiters(currentGeometryState);
}

function computeGeometrySignature(widgetState, viewport = null) {
  if (!widgetState || !widgetState.visible) return 'hidden';
  const bounds = widgetState.bounds;
  if (!bounds) return 'hidden';
  const viewportPart = viewport 
    ? `${round(viewport.width)}|${round(viewport.height)}`
    : `${round(window.innerWidth)}|${round(window.innerHeight)}`;
  return `${round(bounds.x)}|${round(bounds.y)}|${round(bounds.w)}|${round(bounds.h)}|${viewportPart}`;
}

function cloneGeometryState(state) {
  if (!state) {
    return createHiddenGeometryState();
  }
  const widget = state.widget
    ? {
        visible: Boolean(state.widget.visible),
        bounds: state.widget.bounds
          ? {
              x: round(state.widget.bounds.x),
              y: round(state.widget.bounds.y),
              w: round(state.widget.bounds.w),
              h: round(state.widget.bounds.h)
            }
          : undefined
      }
    : undefined;
  return {
    widget: widget || { visible: false },
    placement: state.placement || currentPlacement
  };
}

function createHiddenGeometryState() {
  return {
    widget: { visible: false },
    placement: currentPlacement
  };
}

function resolveGeometryWaiters(state) {
  if (!geometryWaiters.size) return;
  const snapshot = cloneGeometryState(state);
  const visible = Boolean(snapshot?.widget?.visible);
  for (const waiter of Array.from(geometryWaiters)) {
    if (waiter.requireVisible && !visible) {
      continue;
    }
    geometryWaiters.delete(waiter);
    if (waiter.timer) {
      window.clearTimeout(waiter.timer);
    }
    try {
      waiter.resolve(snapshot);
    } catch (_error) {
      /* ignore waiter errors */
    }
  }
}

function waitForVisibleGeometry(timeoutMs = 4000) {
  const current = captureWidgetGeometryState();
  if (current?.widget?.visible) {
    return Promise.resolve(current);
  }
  return new Promise((resolve) => {
    const waiter = {
      requireVisible: true,
      resolve,
      timer: window.setTimeout(() => {
        geometryWaiters.delete(waiter);
        resolve(captureWidgetGeometryState());
      }, timeoutMs)
    };
    geometryWaiters.add(waiter);
  });
}

function buildLegacyGeometryPayload(state) {
  const rect =
    state.widget && state.widget.visible && state.widget.bounds
      ? {
          top: round(state.widget.bounds.y),
          left: round(state.widget.bounds.x),
          width: round(state.widget.bounds.w),
          height: round(state.widget.bounds.h)
        }
      : null;
  return {
    rect,
    mode,
    viewport: {
      width: round(window.innerWidth),
      height: round(window.innerHeight)
    }
  };
}

function applyThemeStylesheet(href) {
  pendingTheme = href || null;
  removeStylesheet('pi-theme-css');
  if (!href) return Promise.resolve();
  return new Promise((resolve, reject) => {
    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = href;
    link.id = 'pi-theme-css';
    link.onload = () => resolve();
    link.onerror = (event) => {
      reject(new Error(`Theme stylesheet failed to load: ${href}`));
      try {
        console.error('[player] theme load failed', { href, event });
      } catch (_error) {
        /* ignore */
      }
    };
    document.head.appendChild(link);
  });
}

function applyManualStylesheet(css) {
  pendingManualCss = typeof css === 'string' ? css : null;
  removeStylesheet('pi-manual-css');
  if (!css) return Promise.resolve();
  const style = document.createElement('style');
  style.id = 'pi-manual-css';
  style.textContent = css;
  document.head.appendChild(style);
  return Promise.resolve();
}

function removeStylesheet(id) {
  const existing = document.getElementById(id);
  if (existing && existing.parentNode) {
    existing.parentNode.removeChild(existing);
  }
}

function postProtocolMessage(type, payload, id) {
  if (!ensureBridgeOrigin()) return;
  const message = { v: 1, type, origin: 'player' };
  if (id) message.id = id;
  if (payload !== undefined) message.payload = payload;
  if (protocolDebug) {
    try {
      console.debug('[player ->]', message);
    } catch (_error) {
      /* ignore */
    }
  }
  window.parent.postMessage(message, bridgeOrigin);
}

function postLegacyStatus(status, data = {}) {
  postLegacyMessage({
    type: 'player-status',
    status,
    ...data
  });
}

function postLegacyMessage(message) {
  if (!ensureBridgeOrigin()) return;
  window.parent.postMessage(message, bridgeOrigin);
}

function ensureBridgeOrigin() {
  if (bridgeOrigin) return true;
  bridgeOrigin = resolveBridgeOrigin();
  return Boolean(bridgeOrigin);
}

function resolveBridgeOrigin() {
  try {
    if (window.location.ancestorOrigins && window.location.ancestorOrigins.length > 0) {
      const origin = window.location.ancestorOrigins[0];
      if (origin) return origin;
    }
  } catch (_error) {
    /* ignore */
  }
  if (document.referrer) {
    try {
      return new URL(document.referrer).origin;
    } catch (_error) {
      /* ignore */
    }
  }
  return window.location.origin;
}

function loadTag() {
  const script = document.createElement('script');
  script.src = `../../scripts/surveys-tag.js?ver=${PLAYER_VERSION}`;
  script.defer = true;
  try {
    console.log('[player] injecting surveys-tag', { src: script.src });
  } catch (_error) {
    /* ignore */
  }
  script.onload = () => {
    try {
      console.log('[player] surveys-tag loaded');
    } catch (_error) {
      /* ignore */
    }
    // Setup link click handling after tag loads
    setupCustomContentLinkHandling();
  };
  script.onerror = (event) => {
    try {
      console.error('[player] surveys-tag failed', event);
    } catch (_error) {
      /* ignore */
    }
  };
  document.head.appendChild(script);
}

let linkHandlerContainer = null;

function setupCustomContentLinkHandling() {
  // Use event delegation to handle dynamically added links
  const container = document.getElementById('_pi_surveyWidgetContainer');
  if (container && container !== linkHandlerContainer) {
    attachLinkHandlers(container);
    linkHandlerContainer = container;
  }
  
  // Watch for widget container being added dynamically or recreated
  if (!linkHandlerContainer || !document.body.contains(linkHandlerContainer)) {
    const observer = new MutationObserver(() => {
      const widgetContainer = document.getElementById('_pi_surveyWidgetContainer');
      if (widgetContainer && widgetContainer !== linkHandlerContainer) {
        attachLinkHandlers(widgetContainer);
        linkHandlerContainer = widgetContainer;
        observer.disconnect();
      }
    });
    observer.observe(document.body, { childList: true, subtree: true });
  }
}

function attachLinkHandlers(container) {
  // Use event delegation - attach once to container, handles all links
  container.addEventListener('click', handleCustomContentLinkClick, true);
}

function handleCustomContentLinkClick(event) {
  // Find the clicked link element
  let link = event.target;
  while (link && link.tagName !== 'A') {
    link = link.parentElement;
  }
  
  if (!link || link.tagName !== 'A') {
    return; // Not a link click
  }
  
  // Check if link is within a custom content question
  const customContentQuestion = link.closest('._pi_question_custom_content_question');
  if (!customContentQuestion) {
    return; // Not in custom content question, let default behavior handle it
  }
  
  const href = link.getAttribute('href');
  if (!href || href.trim() === '' || href.startsWith('javascript:')) {
    return; // No href, empty href, or JavaScript link - let default behavior handle
  }
  
  const target = link.getAttribute('target') || '_self';
  
  // Prevent default link behavior
  event.preventDefault();
  event.stopPropagation();
  
  // Send message to parent window to open link
  postLegacyMessage({
    type: 'link-click',
    href: href.trim(),
    target: target
  });
  
  try {
    console.log('[player] link click intercepted', { href, target });
  } catch (_error) {
    /* ignore */
  }
}

const activeRedirectTimers = new Map();
const pendingRedirectTimers = new Set(); // Track timers being set up to prevent duplicates

// Custom content redirect constants
const AUTOREDIRECT_ENABLED = 't';
const AUTOREDIRECT_DISABLED = 'f';
const QUESTION_TYPE_CUSTOM_CONTENT = 'custom_content_question';
const DEFAULT_REDIRECT_DELAY_MS = 2000;
const PULSEINSIGHTS_CHECK_INTERVAL_MS = 50;
const PULSEINSIGHTS_CHECK_TIMEOUT_MS = 10000;

/**
 * Disables autoredirect in PulseInsightsObject questions to prevent surveys.js
 * from setting up redirect timers. Sets a flag so we know to handle redirects ourselves.
 * 
 * This function modifies questions in-place by setting `autoredirect_enabled` to 'f'
 * and adding `_autoredirect_disabled_by_player` flag.
 * 
 * @returns {void}
 */
function disableAutoredirectInPulseInsightsObject() {
  if (!window.PulseInsightsObject || !window.PulseInsightsObject.survey || 
      !Array.isArray(window.PulseInsightsObject.survey.questions)) {
    return;
  }
  
  const questions = window.PulseInsightsObject.survey.questions;
  questions.forEach((question) => {
    if (question && 
        question.question_type === QUESTION_TYPE_CUSTOM_CONTENT && 
        question.autoredirect_enabled === AUTOREDIRECT_ENABLED &&
        question.autoredirect_url) {
      // Disable autoredirect to prevent surveys.js from redirecting
      // Store flag indicating we disabled it so we know to handle redirect ourselves
      question.autoredirect_enabled = AUTOREDIRECT_DISABLED;
      question._autoredirect_disabled_by_player = true;
      
      try {
        console.log('[player] Disabled autoredirect in PulseInsightsObject for question', question.id);
      } catch (_error) {
        /* ignore */
      }
    }
  });
}

// Intercept PulseInsightsObject creation to disable autoredirect immediately
// This ensures we disable autoredirect before surveys.js reads it
(function setupPulseInsightsObjectInterceptor() {
  const checkInterval = setInterval(() => {
    if (window.PulseInsightsObject && window.PulseInsightsObject.survey && 
        Array.isArray(window.PulseInsightsObject.survey.questions)) {
      clearInterval(checkInterval);
      disableAutoredirectInPulseInsightsObject();
    }
  }, PULSEINSIGHTS_CHECK_INTERVAL_MS); // Check every 50ms for fast detection
  
  // Stop checking after 10 seconds
  setTimeout(() => {
    clearInterval(checkInterval);
  }, PULSEINSIGHTS_CHECK_TIMEOUT_MS);
})();

function setupCustomContentRedirectTimers() {
  try {
    console.log('[player] setupCustomContentRedirectTimers called');
  } catch (_error) {
    /* ignore */
  }
  
  // Check if PulseInsightsObject is available
  if (!window.PulseInsightsObject || !window.PulseInsightsObject.survey || !Array.isArray(window.PulseInsightsObject.survey.questions)) {
    try {
      console.log('[player] setupCustomContentRedirectTimers: PulseInsightsObject not ready, polling...');
    } catch (_error) {
      /* ignore */
    }
    // Wait for PulseInsightsObject to be available
    const checkInterval = setInterval(() => {
      if (window.PulseInsightsObject && window.PulseInsightsObject.survey && Array.isArray(window.PulseInsightsObject.survey.questions)) {
        clearInterval(checkInterval);
        try {
          console.log('[player] setupCustomContentRedirectTimers: PulseInsightsObject ready, detecting timers');
        } catch (_error) {
          /* ignore */
        }
        detectAndStartRedirectTimers();
      }
    }, 100);
    
    // Stop checking after 10 seconds
    setTimeout(() => {
      clearInterval(checkInterval);
    }, PULSEINSIGHTS_CHECK_TIMEOUT_MS);
    return;
  }
  
  // PulseInsightsObject is ready, try to detect timers
  // But widget container might not exist yet, so also set up observer
  detectAndStartRedirectTimers();
  
  // Also watch for widget container being added dynamically
  const container = document.getElementById('_pi_surveyWidgetContainer');
  if (!container || !document.body.contains(container)) {
    try {
      console.log('[player] setupCustomContentRedirectTimers: widget container not present, watching for it...');
    } catch (_error) {
      /* ignore */
    }
    const widgetObserver = new MutationObserver(() => {
      const widgetContainer = document.getElementById('_pi_surveyWidgetContainer');
      if (widgetContainer && document.body.contains(widgetContainer)) {
        try {
          console.log('[player] setupCustomContentRedirectTimers: widget container appeared, detecting timers');
        } catch (_error) {
          /* ignore */
        }
        detectAndStartRedirectTimers();
        widgetObserver.disconnect();
      }
    });
    widgetObserver.observe(document.body, { childList: true, subtree: true });
    
    // Stop watching after 10 seconds
    setTimeout(() => {
      widgetObserver.disconnect();
    }, 10000);
  }
}

/**
 * Detects custom content questions with autoredirect enabled and starts redirect timers.
 * Prevents surveys.js from redirecting by disabling autoredirect in PulseInsightsObject first.
 * 
 * This function:
 * - Disables autoredirect in PulseInsightsObject before processing
 * - Finds all custom content question elements in the DOM
 * - Starts redirect timers for questions with autoredirect enabled
 * - Prevents duplicate timers using pendingRedirectTimers Set
 * 
 * @returns {void}
 */
function detectAndStartRedirectTimers() {
  try {
    console.log('[player] detectAndStartRedirectTimers called');
  } catch (_error) {
    /* ignore */
  }
  
  // Ensure widget container exists and PulseInsightsObject is available
  const container = document.getElementById('_pi_surveyWidgetContainer');
  if (!container || !document.body.contains(container)) {
    try {
      console.log('[player] detectAndStartRedirectTimers: widget container not present');
    } catch (_error) {
      /* ignore */
    }
    return; // Widget container not present
  }
  
  if (!window.PulseInsightsObject || !window.PulseInsightsObject.survey || !Array.isArray(window.PulseInsightsObject.survey.questions)) {
    try {
      console.log('[player] detectAndStartRedirectTimers: PulseInsightsObject not ready', {
        hasObject: !!window.PulseInsightsObject,
        hasSurvey: !!(window.PulseInsightsObject && window.PulseInsightsObject.survey),
        hasQuestions: !!(window.PulseInsightsObject && window.PulseInsightsObject.survey && Array.isArray(window.PulseInsightsObject.survey.questions))
      });
    } catch (_error) {
      /* ignore */
    }
    return; // PulseInsightsObject not ready
  }
  
  // CRITICAL: Disable autoredirect BEFORE processing questions
  // This prevents surveys.js from setting up its redirect timer
  disableAutoredirectInPulseInsightsObject();
  
  // Find all custom content question elements
  const customContentQuestions = document.querySelectorAll('._pi_question_custom_content_question');
  
  try {
    console.log('[player] detectAndStartRedirectTimers: found', customContentQuestions.length, 'custom content questions');
  } catch (_error) {
    /* ignore */
  }
  
  if (customContentQuestions.length === 0) {
    return; // No custom content questions found
  }
  
  customContentQuestions.forEach((questionElement) => {
    const questionId = getQuestionIdFromElement(questionElement);
    if (!questionId) {
      try {
        console.log('[player] detectAndStartRedirectTimers: could not get questionId from element');
      } catch (_error) {
        /* ignore */
      }
      return;
    }
    
    // Check if timer already running or pending for this question
    if (activeRedirectTimers.has(questionId) || pendingRedirectTimers.has(questionId)) {
      try {
        console.log('[player] detectAndStartRedirectTimers: timer already running or pending for question', questionId);
      } catch (_error) {
        /* ignore */
      }
      return; // Timer already running or being set up
    }
    
    const question = getQuestionFromPulseInsightsObject(questionId);
    if (!question) {
      try {
        console.log('[player] detectAndStartRedirectTimers: question not found in PulseInsightsObject', questionId);
      } catch (_error) {
        /* ignore */
      }
      return; // Question not found in PulseInsightsObject
    }
    
    try {
      console.log('[player] detectAndStartRedirectTimers: checking question', questionId, {
        question_type: question.question_type,
        autoredirect_enabled: question.autoredirect_enabled,
        autoredirect_delay: question.autoredirect_delay,
        autoredirect_url: question.autoredirect_url
      });
    } catch (_error) {
      /* ignore */
    }
    
    // Check if auto-redirect is enabled
    // Note: autoredirect_enabled may be 'f' because we disabled it to prevent surveys.js redirect
    // Check for _autoredirect_disabled_by_player flag OR original 't' value
    const wasAutoredirectEnabled = question.autoredirect_enabled === AUTOREDIRECT_ENABLED || question._autoredirect_disabled_by_player === true;
    
    if (question.question_type === QUESTION_TYPE_CUSTOM_CONTENT && wasAutoredirectEnabled && question.autoredirect_url) {
      const delay = parseRedirectDelay(question.autoredirect_delay);
      const url = question.autoredirect_url;
      
      if (url && typeof url === 'string' && url.trim()) {
        // Mark as pending immediately to prevent duplicate setups
        pendingRedirectTimers.add(questionId);
        
        try {
          startRedirectTimer(questionId, url.trim(), delay);
        } catch (error) {
          // If timer setup fails, remove from pending set
          pendingRedirectTimers.delete(questionId);
          try {
            console.error('[player] failed to start redirect timer', questionId, error);
          } catch (_error) {
            /* ignore */
          }
        }
      } else {
        try {
          console.warn('[player] autoredirect_url missing or invalid for question', questionId);
        } catch (_error) {
          /* ignore */
        }
      }
    }
  });
}

function getQuestionIdFromElement(element) {
  // Try data-question-id attribute first
  const dataQuestionId = element.getAttribute('data-question-id');
  if (dataQuestionId) {
    const parsed = parseInt(dataQuestionId, 10);
    if (!isNaN(parsed)) {
      return parsed;
    }
  }
  
  // Fallback: extract from id attribute (e.g., _pi_question_27161 -> 27161)
  const id = element.getAttribute('id');
  if (id) {
    const match = id.match(/_pi_question_(\d+)$/);
    if (match && match[1]) {
      const parsed = parseInt(match[1], 10);
      if (!isNaN(parsed)) {
        return parsed;
      }
    }
  }
  
  return null;
}

function getQuestionFromPulseInsightsObject(questionId) {
  if (!window.PulseInsightsObject || !window.PulseInsightsObject.survey || !Array.isArray(window.PulseInsightsObject.survey.questions)) {
    return null;
  }
  
  // Normalize questionId to string for consistent comparison
  const normalizedId = String(questionId);
  const questions = window.PulseInsightsObject.survey.questions;
  
  for (let i = 0; i < questions.length; i++) {
    const question = questions[i];
    if (question && String(question.id) === normalizedId) {
      return question;
    }
  }
  
  return null;
}

/**
 * Parses redirect delay from question configuration.
 * Converts seconds (string or number) to milliseconds.
 * 
 * @param {string|number} delay - Delay value from question config
 * @returns {number} Delay in milliseconds (defaults to 2000ms if invalid)
 */
function parseRedirectDelay(delay) {
  // autoredirect_delay is stored in seconds, convert to milliseconds
  if (typeof delay === 'number' && !isNaN(delay) && delay > 0) {
    return Math.max(0, Math.floor(delay * 1000));
  }
  
  if (typeof delay === 'string' && delay.trim()) {
    const parsed = parseFloat(delay.trim());
    if (!isNaN(parsed) && parsed > 0) {
      return Math.max(0, Math.floor(parsed * 1000));
    }
  }
  
  // Default to 2000ms (2 seconds) if missing or invalid
  return DEFAULT_REDIRECT_DELAY_MS;
}

/**
 * Starts a redirect timer for a custom content question.
 * Timer will send a redirect message to the bridge when it expires.
 * 
 * @param {string|number} questionId - The question ID
 * @param {string} url - The URL to redirect to
 * @param {number} delay - Delay in milliseconds before redirect
 * @returns {void}
 */
function startRedirectTimer(questionId, url, delay) {
  // Clear any existing timer for this question
  cleanupRedirectTimer(questionId);
  
  const timerId = setTimeout(() => {
    // Timer expired, send redirect message
    try {
      postLegacyMessage({
        type: 'redirect',
        url: url
      });
      try {
        console.log('[player] redirect message sent', { questionId, url });
      } catch (_error) {
        /* ignore */
      }
    } catch (sendError) {
      try {
        const errorLog = `[${new Date().toISOString()}] redirect message FAILED - ${sendError.message}`;
        localStorage.setItem('pi_redirect_error', errorLog);
        console.error('[player] redirect message FAILED', sendError);
      } catch (_error) {
        /* ignore */
      }
    }
    
    // Clean up timer reference
    activeRedirectTimers.delete(questionId);
  }, delay);
  
  // Store timer reference
  activeRedirectTimers.set(questionId, timerId);
  // Remove from pending set now that timer is active
  pendingRedirectTimers.delete(questionId);
  
  try {
    console.log('[player] redirect timer started', { questionId, url, delay });
  } catch (_error) {
    /* ignore */
  }
}

/**
 * Cleans up a single redirect timer for a specific question.
 * 
 * @param {string|number} questionId - The question ID to clean up
 * @returns {void}
 */
function cleanupRedirectTimer(questionId) {
  const timerId = activeRedirectTimers.get(questionId);
  if (timerId) {
    clearTimeout(timerId);
    activeRedirectTimers.delete(questionId);
  }
  // Also remove from pending set if present
  pendingRedirectTimers.delete(questionId);
}

/**
 * Cleans up all active redirect timers.
 * Called when survey is dismissed or page is unloaded.
 * 
 * @returns {void}
 */
function cleanupRedirectTimers() {
  // Clear all active timers
  activeRedirectTimers.forEach((timerId, questionId) => {
    clearTimeout(timerId);
  });
  activeRedirectTimers.clear();
  // Also clear pending set
  pendingRedirectTimers.clear();
}

// Watch for custom content questions being added/removed
let redirectTimerObserver = null;

function setupRedirectTimerObserver() {
  if (redirectTimerObserver) {
    return; // Already set up
  }
  
  redirectTimerObserver = new MutationObserver(() => {
    // Clean up timers for removed questions
    const existingQuestionIds = new Set();
    document.querySelectorAll('._pi_question_custom_content_question').forEach((element) => {
      const questionId = getQuestionIdFromElement(element);
      if (questionId) {
        existingQuestionIds.add(questionId);
      }
    });
    
    // Remove timers for questions that no longer exist in DOM
    activeRedirectTimers.forEach((timerId, questionId) => {
      if (!existingQuestionIds.has(questionId)) {
        cleanupRedirectTimer(questionId);
      }
    });
    
    // Detect and start new timers
    if (window.PulseInsightsObject && window.PulseInsightsObject.survey && Array.isArray(window.PulseInsightsObject.survey.questions)) {
      detectAndStartRedirectTimers();
    }
  });
  
  redirectTimerObserver.observe(document.body, { childList: true, subtree: true });
}

// Setup observer when Pulse Insights is ready
window.addEventListener('pulseinsights:ready', () => {
  try {
    console.log('[player] pulseinsights:ready event - setting up redirect timers');
  } catch (_error) {
    /* ignore */
  }
  setupRedirectTimerObserver();
  // Also check for existing questions immediately
  detectAndStartRedirectTimers();
});

// Clean up timers when widget container is removed
const widgetCleanupObserver = new MutationObserver(() => {
  const container = document.getElementById('_pi_surveyWidgetContainer');
  if (!container || !document.body.contains(container)) {
    // Widget container removed, clean up all timers
    cleanupRedirectTimers();
  }
});
widgetCleanupObserver.observe(document.body, { childList: true, subtree: true });

// Clean up timers when page/iframe is about to be unloaded
// This prevents timers from firing after iframe context is destroyed
window.addEventListener('beforeunload', () => {
  cleanupRedirectTimers();
});

window.addEventListener('pagehide', () => {
  cleanupRedirectTimers();
});

function scheduleWidgetCheck(id, source, delay) {
  setTimeout(() => {
    const widget = document.getElementById('_pi_surveyWidgetContainer');
    try {
      console.log('[player] widget check', {
        id,
        source,
        delay,
        present: Boolean(widget)
      });
    } catch (_error) {
      /* ignore */
    }
    postLegacyStatus('widget-check', {
      surveyId: id,
      source,
      delay,
      present: Boolean(widget)
    });
  }, delay);
}

function round(value) {
  const number = Number(value);
  if (!Number.isFinite(number)) return 0;
  return Math.round(number * 100) / 100;
}
