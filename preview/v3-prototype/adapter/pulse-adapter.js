import { createSurveyBridge } from '../../app/survey/bridge.js';
import { resolveProxyUrl, getProxyOrigin } from '../../app/services/proxy.js';
import { store, setState } from '../v3.js';
import { log } from '../ui/log.js';
import { emit } from '../ui/events.js';

const DEFAULT_ACCOUNT = 'PI-81598442';
const DEFAULT_HOST = 'survey.pulseinsights.com';
const DEFAULT_TAG_SRC = 'https://js.pulseinsights.com/surveys.js';

let bridge = null;
let currentConfig = {
  account: DEFAULT_ACCOUNT,
  host: DEFAULT_HOST,
  present: [],
  inlineSelector: null,
  mode: 'overlay',
  themeCss: null,
  manualCss: null,
  tagSrc: resolveProxyUrl(DEFAULT_TAG_SRC),
  proxyOrigin: getProxyOrigin()
};

let readinessTimer = null;

export function initPulseAdapter(container) {
  bridge = createSurveyBridge({
    container,
    onReady: handleReady,
    onStatus: handleStatus,
    onStateChange: handleBridgeStateChange,
    onError: handleBridgeError,
    onClose: handleBridgeClose
  });
  return bridge;
}

export async function bootTag(config = {}) {
  if (!bridge) throw new Error('Pulse adapter not initialized');
  const resolvedTagSrc =
    typeof config.tagSrc === 'string' && config.tagSrc.trim()
      ? resolveProxyUrl(config.tagSrc)
      : resolveProxyUrl(DEFAULT_TAG_SRC);
  const resolvedProxyOrigin = config.proxyOrigin || getProxyOrigin();
  const merged = {
    ...currentConfig,
    ...config,
    account: config.account || currentConfig.account || DEFAULT_ACCOUNT,
    host: config.host || currentConfig.host || DEFAULT_HOST,
    present: [],
    tagSrc: resolvedTagSrc,
    proxyOrigin: resolvedProxyOrigin
  };
  currentConfig = merged;
  setState({ tagReady: false });
  bridge.load(currentConfig);
  if (readinessTimer) {
    clearTimeout(readinessTimer);
  }
  readinessTimer = setTimeout(() => {
    if (!store.tagReady) {
      emit({ type: 'tag_ready', ts: Date.now(), ready: false });
    }
  }, 3000);
}

export function applyIdentifier(identifier) {
  if (!identifier || typeof window.pi !== 'function') return;
  try {
    window.pi('identify', identifier);
    log('tag', 'event', `Applied identifier ${identifier}`);
  } catch (error) {
    log('tag', 'error', 'Failed to apply identifier', { error: String(error) });
  }
}

export function presentSurvey(agent, options = {}) {
  const survey = normalizeAgent(agent);
  if (!survey) return;
  const targetAccount = survey.identifier || DEFAULT_ACCOUNT;
  const requiresReload =
    !store.tagReady ||
    !currentConfig ||
    targetAccount !== currentConfig.account;

  if (requiresReload) {
    currentConfig = {
      ...currentConfig,
      account: targetAccount,
      host: currentConfig.host || DEFAULT_HOST,
      present: [survey.id]
    };
    setState({
      tagReady: false,
      pendingSurveyId: survey.id,
      selectedAgent: survey
    });
    bridge.load(currentConfig);
    emit({
      type: 'error',
      ts: Date.now(),
      code: 'not_ready',
      message: 'Tag not ready — queued',
      data: { id: survey.id }
    });
    return;
  }

  if (!options.force && store.lastPresentedId === survey.id) {
    return;
  }

  try {
    bridge.present(survey.id);
    setState({
      lastPresentedId: survey.id,
      agentStatus: 'Presenting',
      selectedAgent: survey
    });
    emit({
      type: 'present',
      ts: Date.now(),
      surveyId: survey.id,
      force: !!options.force
    });
  } catch (error) {
    emit({
      type: 'error',
      ts: Date.now(),
      code: 'present_fail',
      message: 'Present failed',
      data: { id: survey.id, error: String(error) }
    });
  }
}

export function resetAgent() {
  setState({
    pendingSurveyId: undefined,
    lastPresentedId: undefined,
    agentStatus: 'Idle'
  });
}

export function sendTrigger(command) {
  if (!bridge || !command) return;
  try {
    if (Array.isArray(command)) {
      bridge.sendCommand(command);
    } else {
      bridge.sendTrigger(command);
    }
  } catch (error) {
    emit({
      type: 'error',
      ts: Date.now(),
      code: 'trigger_fail',
      message: 'Trigger failed',
      data: { command, error: String(error) }
    });
  }
}

export function applyThemeHref(href) {
  if (!bridge || !href) return;
  bridge.applyTheme(href);
}

export function clearThemeHref() {
  if (!bridge) return;
  bridge.clearTheme();
}

export function applyManualCssHref(href) {
  if (!bridge || !href) return;
  bridge.applyManualCss(href);
}

export function clearManualCss() {
  if (!bridge) return;
  bridge.clearManualCss();
}

function handleReady() {
  const pendingId = store.pendingSurveyId;
  setState({
    tagReady: true,
    agentStatus: pendingId ? 'Presenting' : 'Idle'
  });
  emit({ type: 'tag_ready', ts: Date.now(), ready: true });
  if (readinessTimer) {
    clearTimeout(readinessTimer);
    readinessTimer = null;
  }
  if (!pendingId) return;

  setState({ pendingSurveyId: undefined });

  const finalizePendingPresent = () => {
    currentConfig = { ...currentConfig, present: [] };
    setState({ lastPresentedId: pendingId });
    emit({ type: 'present', ts: Date.now(), surveyId: pendingId });
  };

  const reportPresentFailure = (error) => {
    emit({
      type: 'error',
      ts: Date.now(),
      code: 'present_fail',
      message: 'Present failed',
      data: { id: pendingId, error: String(error) }
    });
    setState({ agentStatus: 'Error' });
  };

  if (!bridge || typeof bridge.present !== 'function') {
    reportPresentFailure(new Error('Bridge not ready'));
    return;
  }

  try {
    const result = bridge.present(pendingId);
    if (result && typeof result.then === 'function') {
      result.then(
        () => finalizePendingPresent(),
        (error) => reportPresentFailure(error)
      );
    } else {
      finalizePendingPresent();
    }
  } catch (error) {
    reportPresentFailure(error);
  }
}

function handleStatus(message) {
  if (!message) return;

  if (message.type === 'player-status') {
    if (message.triggerId) {
      log('trigger', 'event', `Trigger handled ${message.triggerId}`);
    }
    const status = message.status;
    const durationLabel = (ms) => {
      if (typeof ms !== 'number' || Number.isNaN(ms)) return null;
      if (ms >= 1000) return `${(ms / 1000).toFixed(1)}s`;
      return `${ms}ms`;
    };
    const scenarioLabel = (id) => {
      if (!id) return 'Scenario';
      return id
        .toString()
        .replace(/[_-]/g, ' ')
        .replace(/\b\w/g, (char) => char.toUpperCase());
    };

    switch (status) {
      case 'timer-start': {
        const duration = durationLabel(message.duration);
        const label = message.label ? `${message.label}` : 'Timer started';
        log('trigger', 'event', duration ? `${label} (${duration})` : label);
        break;
      }
      case 'timer-complete': {
        const duration = durationLabel(message.duration);
        const label = message.label ? `${message.label} complete` : 'Timer complete';
        log('trigger', 'event', duration ? `${label} (${duration})` : label);
        break;
      }
      case 'idle-start': {
        const seconds = typeof message.seconds === 'number' ? message.seconds : message.declared;
        log(
          'trigger',
          'event',
          seconds ? `Idle detector armed (${seconds}s)` : 'Idle detector armed'
        );
        break;
      }
      case 'idle-complete': {
        const seconds = typeof message.seconds === 'number' ? message.seconds : message.declared;
        log(
          'trigger',
          'event',
          seconds ? `Idle complete after ${seconds}s` : 'Idle period complete'
        );
        break;
      }
      case 'scroll-depth-hit': {
        const percent = typeof message.percent === 'number' ? message.percent : null;
        log(
          'trigger',
          'event',
          percent ? `Scroll depth reached ${Math.round(percent)}%` : 'Scroll depth trigger fired'
        );
        break;
      }
      case 'exit-intent-simulated':
        log('trigger', 'event', 'Exit intent simulated');
        break;
      case 'rage-click-simulated': {
        const clicks = typeof message.clicks === 'number' ? message.clicks : 6;
        log('trigger', 'event', `Rage click simulated (${clicks} clicks)`);
        break;
      }
      case 'pageview-increment':
        log('trigger', 'event', 'Simulated additional page view');
        break;
      case 'scenario-progress': {
        const label = scenarioLabel(message.scenarioId);
        const step = message.step ? message.step.replace(/[_-]/g, ' ') : 'progress';
        log('trigger', 'event', `[${label}] ${step}`, message.detail || null);
        break;
      }
      case 'scenario-qualified': {
        const label = scenarioLabel(message.scenarioId);
        const confidence =
          typeof message.confidence === 'number'
            ? ` (confidence ${(message.confidence * 100).toFixed(0)}%)`
            : '';
        log('trigger', 'event', `[${label}] Qualified${confidence}`, message.detail || null);
        break;
      }
      case 'scenario-action': {
        const label = scenarioLabel(message.scenarioId);
        const action = message.action || 'action';
        const outcome = message.success ? 'completed' : 'skipped';
        log(
          'trigger',
          message.success ? 'event' : 'warn',
          `[${label}] ${action} ${outcome}`,
          message.detail ? { detail: message.detail } : null
        );
        break;
      }
      default:
        break;
    }
  }

  const label = message?.event || message?.payload?.event;
  if (label) {
    emit({ type: 'bridge_event', ts: Date.now(), event: label, data: message });
  }
  if (label === 'present-called') {
    setState({ agentStatus: 'Presented' });
  }
  if (label === 'player-inactive') {
    setState({ agentStatus: 'Idle' });
  }
}

function handleBridgeStateChange(change) {
  if (!change) return;
  emit({
    type: 'bridge_state',
    ts: typeof change.ts === 'number' ? change.ts : Date.now(),
    prev: change.prev,
    next: change.next,
    reason: change.reason,
    data: change.data
  });

  switch (change.reason) {
    case 'present-start':
      setState({ agentStatus: 'Presenting' });
      break;
    case 'present-complete':
    case 'implicit-ack':
      setState({ agentStatus: 'Presented' });
      break;
    case 'present-cancelled':
      setState({ agentStatus: 'Idle' });
      break;
    case 'dismiss-complete':
      setState({ agentStatus: 'Idle' });
      break;
    case 'heartbeat-missed-2':
      setState({ agentStatus: 'Idle' });
      break;
    case 'ack-timeout':
    case 'present-failed':
    case 'dismiss-failed':
      setState({ agentStatus: 'Error' });
      break;
    default:
      if (change.next === 'ERROR') {
        setState({ agentStatus: 'Error' });
      } else if (change.next === 'UNMOUNTED') {
        setState({ agentStatus: 'Idle' });
      }
      break;
  }
}

function handleBridgeError(payload) {
  if (!payload) return;
  emit({
    type: 'error',
    ts: Date.now(),
    code: payload.code || 'bridge_error',
    message: payload.message || 'Bridge error',
    data: payload
  });
}

function handleBridgeClose() {
  setState({ agentStatus: 'Idle' });
}

function normalizeAgent(input) {
  if (!input) return null;
  if (typeof input === 'string') {
    return {
      id: input,
      label: input
    };
  }
  if (typeof input === 'object' && input.id) {
    return {
      id: String(input.id),
      label: input.label || input.id,
      identifier: input.identifier,
      backgroundUrl: input.backgroundUrl
    };
  }
  return null;
}
