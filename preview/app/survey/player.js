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
let currentGeometryState = createHiddenGeometryState();
const geometryWaiters = new Set();
let geometryTransitionHandler = null;

startGeometryTracking();
refreshGeometryState();

document.addEventListener('visibilitychange', () => {
  if (!document.hidden) {
    refreshGeometryState();
  }
});

window.addEventListener('resize', () => {
  refreshGeometryState();
});

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
  waitForVisibleGeometry(2400).then((geometryState) => {
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
  updateGeometryState(state);
}

function updateGeometryState(state) {
  const signature = computeGeometrySignature(state.widget);
  if (signature === geometryStateSignature) {
    return;
  }
  geometryStateSignature = signature;
  currentGeometryState = cloneGeometryState(state);
  broadcastStatus({}, { geometryOverride: currentGeometryState });
  postLegacyStatus('widget-geometry', buildLegacyGeometryPayload(currentGeometryState));
  resolveGeometryWaiters(currentGeometryState);
}

function computeGeometrySignature(widgetState) {
  if (!widgetState || !widgetState.visible) return 'hidden';
  const bounds = widgetState.bounds;
  if (!bounds) return 'hidden';
  return `${round(bounds.x)}|${round(bounds.y)}|${round(bounds.w)}|${round(bounds.h)}`;
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

function waitForVisibleGeometry(timeoutMs = 2400) {
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
