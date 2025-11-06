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
const toggleLogBtn = document.getElementById('toggle-log-btn');
const closeLogBtn = document.getElementById('close-log-btn');
const tagStatusEl = document.getElementById('tag-status');
const surveyStatusEl = document.getElementById('survey-status');
const surveySelect = document.getElementById('survey-select');
const presentBtn = document.getElementById('present-btn');
const controlRail = document.getElementById('control-rail');
const railToggle = document.getElementById('rail-toggle');
const demoSubtitle = document.getElementById('demo-subtitle');
const industrySelect = document.getElementById('industry-select');
const themeSelect = document.getElementById('theme-select');
const triggerButtons = document.getElementById('trigger-buttons');
const accordionRoot = document.getElementById('rail-accordion');
const appliedCssList = document.getElementById('applied-css-list');
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
const demoDirectoryButton = document.getElementById('demo-directory-button');
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

const LATEST_THEME_MANIFEST_URL = '/preview/styles/examples/generated/themes.json';
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
let latestThemes = [];
let currentIndustry = '__all';
let themeEntryById = new Map();

const params = new URLSearchParams(window.location.search);
const demoCodeFilter = (params.get('demo') || params.get('demo_code') || '').trim().toLowerCase();
const demoForFilterRaw = (params.get('demo_for') || '').trim();
const demoForFilterParam = demoForFilterRaw ? demoForFilterRaw.toLowerCase() : '';
const demoDismissed = params.get('demo_dismissed') === 'true';
const demoForFilter = demoDismissed ? '' : demoForFilterParam;

const loadedAssets = new Set();
let tagReady = false;
let pendingPresent = null;
let lastPresentedOptionId = null;
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
  const requestedHost = hasDemoFilter ? surveyInfo?.backgroundUrl || '' : '';
  const hostToLoad = requestedHost || DEFAULT_HOST_URL;
  if (!hasDemoFilter) {
    addLog(`No demo parameter detected; defaulting host to ${DEFAULT_HOST_URL}.`);
  } else if (!requestedHost) {
    addLog(`Demo parameter provided but no background URL found; falling back to ${DEFAULT_HOST_URL}.`, 'warn');
  }

  let hostLoaded = false;
  hostLoaded = await loadHostPage(hostToLoad);
  if (hostLoaded && hostToLoad) {
    currentBackgroundUrl = normalizeBackgroundUrl(hostToLoad) || hostToLoad;
    if (backgroundInput) {
      backgroundInput.value = currentBackgroundUrl;
    }
  }

  await initializeThemeSelect();
  await bootPulseTag();
  wireUi();
  setRailOpen(false);
  setLogVisibility(false);

  const initialOptionId = surveyInfo?.initialOptionId || surveySelect.value;
  if (initialOptionId) {
    surveySelect.value = initialOptionId;
    updateBehaviorSurveyLabel();
  }

  // Surface the demo directory so presenters can pick the correct demo before interacting.
  if (demoDirectoryOptions.length && !demoForFilterParam && !demoDismissed) {
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
    if (railOpen) {
      setRailOpen(false);
    }
    await presentSurvey(surveySelect.value, { force: true });
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

  if (toggleLogBtn) {
    toggleLogBtn.addEventListener('click', () => {
      if (!railOpen) {
        setRailOpen(true);
      }
      setLogVisibility(!logVisible);
    });
  }

  if (closeLogBtn) {
    closeLogBtn.addEventListener('click', () => {
      setLogVisibility(false);
    });
  }

  if (industrySelect) {
    industrySelect.addEventListener('change', () => {
      currentIndustry = industrySelect.value || '__all';
      renderThemeOptions();
      const activeTheme = themeSelect?.value;
      if (activeTheme) {
        applyThemeById(activeTheme);
      }
    });
  }

  if (themeSelect) {
    themeSelect.addEventListener('change', () => {
      applyThemeById(themeSelect.value);
    });
  }

  if (demoDirectoryButton) {
    demoDirectoryButton.addEventListener('click', (event) => {
      event.preventDefault();
      openDemoDirectory();
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
  initializeTriggers();
  initializeBehaviorLab();
  updateCssManifest();
  refreshAccordionHeights();
}

async function loadHostPage(url) {
  const playerFrame = surveyBridge.load({
    account: DEFAULT_IDENTIFIER,
    host: DEFAULT_PULSE_HOST,
    themeCss: resolveThemeHref(currentThemeHref) || undefined,
    tagSrc: resolveProxyUrl(DEFAULT_TAG_SRC),
    proxyOrigin: getProxyOrigin()
  });
  registerPlayerFrame(playerFrame);

  const target = (url || '').trim();
  if (!target) {
    return await loadLipsumSite();
  }

  addLog(`Loading host page ${target}`);
  if (overlayContainer && overlayContainer.parentNode === siteRoot) {
    siteRoot.removeChild(overlayContainer);
  }
  siteRoot.innerHTML = '';
  siteRoot.classList.remove('loaded-site');

  const frame = document.createElement('iframe');
  frame.className = 'background-frame';
  const frameSrc = buildProxySrc(target);
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
    frame.addEventListener('load', () => finish(true), { once: true });
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

async function bootPulseTag() {
  if (window.__pulsePreviewBooted) {
    addLog('Pulse tag already booted.');
    return;
  }
  window.__pulsePreviewBooted = true;

  if (!window.PULSE_TAG_SRC) {
    window.PULSE_TAG_SRC = resolveProxyUrl(DEFAULT_TAG_SRC);
  } else {
    window.PULSE_TAG_SRC = resolveProxyUrl(window.PULSE_TAG_SRC);
  }

  addLog('Loading official Pulse tag…');
  await injectScript('/preview/scripts/pulse-insights-official-tag.js');
  addLog('Pulse tag script loaded; waiting for initialization…');

  waitForOfficialTag()
    .then(() => {
      tagReady = true;
      setTagStatus('Tag: ready');
      addLog('PulseInsightsObject and pi() are ready.');
      clearPresentCommands({ log: true });
      applyPendingIdentifier({ reason: 'ready' });
      if (pendingPresent && pendingPresent.optionId) {
        const record = findRecordByOptionId(pendingPresent.optionId);
        if (record) {
          sendPresentForRecord(record, pendingPresent.options);
        }
        pendingPresent = null;
      }
    })
    .catch((error) => {
      setTagStatus('Tag: failed');
      addLog(`Pulse tag failed to initialize: ${error.message}`, 'error');
    });
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
  placeholderOption.textContent = 'Select a demo survey…';
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
    initialOptionId: firstRecord?.__optionId || null,
    initialSurveyId: firstRecord?.surveyId || null,
    backgroundUrl: firstRecord?.backgroundUrl || '',
    identifier: resolveIdentifier(firstRecord)
  };
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

function waitForOfficialTag(timeoutMs = 10000) {
  const start = Date.now();
  return new Promise((resolve, reject) => {
    (function poll() {
      const hasPi = typeof window.pi === 'function';
      const hasPulse = typeof window.PulseInsightsObject === 'object' && window.PulseInsightsObject;
      if (hasPi && hasPulse) {
        resolve();
        return;
      }
      if (Date.now() - start >= timeoutMs) {
        reject(new Error('PulseInsightsObject / pi() not available'));
        return;
      }
      setTimeout(poll, 100);
    })();
  });
}

async function presentSurvey(optionId, options = {}) {
  try {
    const key = String(optionId || '').trim();
    if (!key) {
      addLog('No survey id selected.', 'warn');
      return;
    }

    const record = findRecordByOptionId(key);
    if (!record) {
      addLog(`No survey record found for option ${key}`, 'warn');
      setSurveyStatus('Survey: idle');
      return;
    }

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

    await ensureBackgroundForRecord(record, { force: Boolean(force) });
    const ensureResult = ensurePlayerLoadedForRecord(record, {
      forceReload: Boolean(forceReload || force)
    });
    const trimmedQueue = (window.pi && Array.isArray(window.pi.commands)) ? window.pi.commands.map((args) => args[0]) : [];
    addLog(`pi queue snapshot: ${trimmedQueue.join(', ') || 'empty'}`);
    applyIdentifier(resolveIdentifier(record));

    if (!tagReady || typeof window.pi !== 'function') {
      pendingPresent = {
        optionId: key,
        options: { force, forceReload, allowDuplicate }
      };
      const queuedLabel = record.surveyId || record.surveyName || key;
      addLog(`Tag not ready yet; waiting to present ${queuedLabel}.`, 'warn');
      setSurveyStatus(`Survey: queued ${queuedLabel}`);
      return;
    }

    sendPresentForRecord(record, { force, forceReload, allowDuplicate }, ensureResult);
  } catch (error) {
    addLog(`Present failed: ${error.message}`, 'error');
  }
}

function sendPresentForRecord(record, { force = false, forceReload = false, allowDuplicate = false } = {}, ensured = null) {
  if (!record) return;
  pendingPresent = null;
  const optionId = record.__optionId || String(record.surveyId || '');
  const surveyId = record.surveyId;
  const label = String(surveyId || record.surveyName || optionId);

  lastSurveyRecord = record;
  const placementHint = derivePlacementHintFromRecord(record);
  if (placementHint) {
    overlayPlacementHint = placementHint;
  }

  if (!surveyId) {
    addLog(`Survey record ${label} is missing a surveyId; skipping present.`, 'warn');
    return;
  }

  const ensureResult =
    ensured && ensured.config
      ? ensured
      : ensurePlayerLoadedForRecord(record, { forceReload: Boolean(force || forceReload) });
  const reloaded = Boolean(ensureResult && ensureResult.reloaded);

  if (!force && !forceReload && !allowDuplicate && !reloaded && lastPresentedOptionId === optionId) {
    addLog(`pi('present', ${label}) already sent; skipping duplicate.`);
    setSurveyStatus(`Survey: already presenting ${label}`);
    return;
  }

  clearPresentCommands({ log: true });
  blockAutoPresent = false;
  stopPresentGuard();
  const modeNote = forceReload || force ? ' (reload)' : allowDuplicate ? ' (duplicate)' : '';
  addLog(`Calling pi('present', ${label})${modeNote}`);
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

function buildPlayerConfigForRecord(record) {
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
    present: record.surveyId ? [String(record.surveyId)] : []
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

function ensurePlayerLoadedForRecord(record, { forceReload = false } = {}) {
  if (!record || !surveyBridge || typeof surveyBridge.load !== 'function') {
    return { reloaded: false, config: null };
  }

  const config = buildPlayerConfigForRecord(record);
  if (!config) {
    return { reloaded: false, config: null };
  }

  const currentConfig =
    typeof surveyBridge.getConfig === 'function' ? surveyBridge.getConfig() : null;
  const shouldReload = forceReload || !playerConfigsEqual(currentConfig, config);

  if (shouldReload) {
    const frame = surveyBridge.load(config);
    registerPlayerFrame(frame || null);
    playerMode = config.mode === 'inline' ? 'inline' : 'overlay';
    updatePlayerOverlayLayout();
    scheduleOverlayLayoutUpdate({ immediate: true, trailing: true });
    const presentLabel =
      config.present && config.present[0] ? ` (present ${config.present[0]})` : '';
    const modeLabel = config.mode === 'inline' ? ' in inline mode' : '';
    addLog(`Survey player configured for ${config.account}${presentLabel}${modeLabel}.`);
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
  }, 2600);
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
  if (demoDirectoryButton) {
    demoDirectoryButton.hidden = demoDirectoryOptions.length === 0;
  }

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

async function ensureBackgroundForRecord(record, { force = false } = {}) {
  const raw = resolveRecordBackgroundUrl(record);
  const normalized = normalizeBackgroundUrl(raw);

  if (!normalized) {
    if (force && currentBackgroundUrl !== DEFAULT_HOST_URL) {
      const success = await loadHostPage(DEFAULT_HOST_URL);
      if (success) {
        currentBackgroundUrl = DEFAULT_HOST_URL;
        if (backgroundInput) {
          backgroundInput.value = DEFAULT_HOST_URL;
        }
        addLog(`Background ready: ${DEFAULT_HOST_URL}`);
      }
    }
    return;
  }

  if (!force && normalized === currentBackgroundUrl) {
    return;
  }

  const success = await loadHostPage(normalized);
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


function addLog(message, level = 'info') {
  const li = document.createElement('li');
  li.textContent = `${timestamp()} — ${message}`;
  li.dataset.level = level;
  logList.appendChild(li);
  logList.scrollTop = logList.scrollHeight;
  if (level === 'error') {
    console.error('[preview]', message);
  } else if (level === 'warn') {
    console.warn('[preview]', message);
  } else {
    console.info('[preview]', message);
  }
}

function setTagStatus(text) {
  tagStatusEl.textContent = text;
  refreshAccordionHeights();
}

function setSurveyStatus(text) {
  surveyStatusEl.textContent = text;
  refreshAccordionHeights();
}

function setLogVisibility(visible) {
  logVisible = Boolean(visible);
  if (!logPanel) return;
  logPanel.classList.toggle('visible', logVisible);
  if (toggleLogBtn) {
    toggleLogBtn.textContent = logVisible ? 'Hide Status Log' : 'Show Status Log';
  }
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

function timestamp() {
  const now = new Date();
  return now.toLocaleTimeString();
}

async function initializeThemeSelect() {
  if (!themeSelect) return;
  latestThemes = [];
  currentIndustry = '__all';
  populateIndustrySelect([]);
  renderThemeOptions();
  refreshAccordionHeights();

  try {
    latestThemes = await fetchLatestThemes();
    populateIndustrySelect(latestThemes);
    if (latestThemes.length) {
      renderThemeOptions(currentThemeId || null);
      refreshAccordionHeights();
      addLog(`Loaded ${latestThemes.length} latest example themes.`);
    }
  } catch (error) {
    addLog(`Failed to load latest themes: ${error.message}`, 'warn');
  }
}

function renderThemeOptions(selectedId) {
  if (!themeSelect) return;
  const previousValue = selectedId !== undefined ? selectedId : themeSelect.value;
  const entries = new Map();
  themeSelect.innerHTML = '';

  const placeholderOption = document.createElement('option');
  placeholderOption.value = '';
  placeholderOption.textContent = '-- Select theme --';
  placeholderOption.disabled = true;
  placeholderOption.selected = true;
  themeSelect.appendChild(placeholderOption);

  const appendThemeOption = (container, item) => {
    if (!item || !item.id) return;
    const option = document.createElement('option');
    option.value = item.id;
    option.textContent = item.label;
    container.appendChild(option);
    entries.set(item.id, item);
  };

  appendThemeOption(themeSelect, {
    id: 'none',
    label: 'No theme override (widget default)',
    href: null,
    source: 'default',
    manifestLabel: 'Widget defaults (no override)'
  });

  const filteredThemes =
    currentIndustry === '__all'
      ? latestThemes
      : latestThemes.filter((theme) => (theme.industry || 'Other') === currentIndustry);

  const accountGroups = buildAccountGroups(filteredThemes);
  accountGroups.forEach((group) => {
    if (!group.items.length) return;
    const groupEl = document.createElement('optgroup');
    groupEl.label = group.label;
    group.items.forEach((item) => appendThemeOption(groupEl, item));
    themeSelect.appendChild(groupEl);
  });

  themeEntryById = entries;

  const hasPrevious = previousValue && entries.has(previousValue);
  if (hasPrevious) {
    themeSelect.value = previousValue;
    placeholderOption.selected = false;
  } else {
    themeSelect.selectedIndex = 0;
    placeholderOption.selected = true;
  }
  refreshAccordionHeights();
}

async function fetchLatestThemes() {
  const response = await fetch(LATEST_THEME_MANIFEST_URL, { cache: 'no-cache' });
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }
  const data = await response.json();
  if (!data || !Array.isArray(data.themes)) return [];

  return data.themes.map((theme) => {
    return {
      id: `latest-${theme.id}`,
      label: theme.name || theme.id,
      href: theme.cssPath,
      account: theme.account || null,
      accountGroup: theme.accountGroup || null,
      industry: theme.industry || null,
      identifier: theme.identifier || null
    };
  });
}

function applyThemeById(themeId) {
  if (!themeSelect) return;
  const entry = themeEntryById.get(themeId);
  const normalizedId = entry ? entry.id : 'none';
  if (currentThemeId === normalizedId) return;

  if (!entry || !entry.href) {
    setThemeStylesheet(null, 'default');
    currentThemeId = 'none';
    addLog('Cleared theme override; using widget defaults.');
    return;
  }

  currentThemeId = entry.id;
  setThemeStylesheet(entry.href, entry.source || 'examples', entry.manifestLabel || entry.label || entry.href);
  addLog(`Applied theme override: ${entry.label}`);
}

function populateIndustrySelect(themes) {
  if (!industrySelect) return;
  const previousValue = currentIndustry;
  industrySelect.innerHTML = '';

  const allOption = document.createElement('option');
  allOption.value = '__all';
  allOption.textContent = 'All industries';
  industrySelect.appendChild(allOption);

  const uniqueIndustries = Array.from(
    new Set(
      themes
        .map((theme) => theme.industry || 'Other')
        .filter(Boolean)
    )
  ).sort((a, b) => a.localeCompare(b, undefined, { sensitivity: 'base' }));

  uniqueIndustries.forEach((industry) => {
    const option = document.createElement('option');
    option.value = industry;
    option.textContent = industry;
    industrySelect.appendChild(option);
  });

  if (previousValue && (previousValue === '__all' || uniqueIndustries.includes(previousValue))) {
    currentIndustry = previousValue;
  } else {
    currentIndustry = '__all';
  }

  industrySelect.value = currentIndustry;
  refreshAccordionHeights();
}

function buildAccountGroups(themes) {
  const groupMap = new Map();

  themes.forEach((theme) => {
    if (!theme || !theme.id) return;
    const groupLabel = theme.accountGroup || theme.account || theme.identifier || 'Other Accounts';
    if (!groupMap.has(groupLabel)) {
      groupMap.set(groupLabel, []);
    }
    const displayLabel = theme.account ? `${theme.account} — ${theme.label}` : theme.label;
    groupMap.get(groupLabel).push({
      id: theme.id,
      label: displayLabel,
      href: theme.href,
      source: 'examples',
      manifestLabel: displayLabel
    });
  });

  return Array.from(groupMap.entries())
    .map(([label, items]) => ({
      label,
      items: items.sort((a, b) => (a.label || '').localeCompare(b.label || '', undefined, { sensitivity: 'base' }))
    }))
    .sort((a, b) => a.label.localeCompare(b.label, undefined, { sensitivity: 'base' }));
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
  handleTrigger(triggerId);
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
  if (surveySelect && surveySelect.value) {
    presentSurvey(surveySelect.value, { allowDuplicate: true });
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

function initializeTriggers() {
  if (!triggerButtons) return;
  triggerButtons.innerHTML = '';
  TRIGGER_CONFIG.forEach((trigger) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'button-secondary';
    button.textContent = trigger.label;
    button.dataset.triggerId = trigger.id;
    button.addEventListener('click', () => handleTrigger(trigger.id));
    triggerButtons.appendChild(button);
  });
  refreshAccordionHeights();
}

function handleTrigger(triggerId) {
  switch (triggerId) {
    case 'present-selected':
      if (!surveySelect.value) {
        addLog('Trigger cancelled: no survey selected.', 'warn');
        return;
      }
      addLog('Trigger: Present selected survey');
      presentSurvey(surveySelect.value, { force: true });
      break;
    case 'exit-intent':
      simulateExitIntent();
      addLog('Trigger: Simulated exit intent');
      break;
    case 'rage-click':
      simulateRageClick();
      addLog('Trigger: Simulated rage clicks');
      break;
    case 'scroll-depth':
      simulateScrollDepth();
      addLog('Trigger: Simulated scroll depth');
      break;
    case 'time-delay':
      simulateTimer();
      addLog('Trigger: Started timer');
      break;
    case 'pageview':
      simulatePageview();
      addLog('Trigger: Incremented pageview');
      break;
    default:
      addLog(`Unknown trigger "${triggerId}"`, 'warn');
  }
}

function simulateExitIntent() {
  const event = new MouseEvent('mouseout', {
    bubbles: true,
    clientY: 0,
    relatedTarget: null
  });
  document.dispatchEvent(event);
}

function simulateRageClick() {
  const target = document.body || document.documentElement;
  for (let i = 0; i < 6; i += 1) {
    const event = new MouseEvent('click', {
      bubbles: true,
      clientX: 200 + i,
      clientY: 200
    });
    target.dispatchEvent(event);
  }
}

function simulateScrollDepth() {
  window.scrollTo({ top: document.documentElement.scrollHeight, behavior: 'auto' });
  window.dispatchEvent(new Event('scroll'));
}

function simulateTimer() {
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
  if (!appliedCssList) return;
  appliedCssList.innerHTML = '';

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
  if (lower.includes('/theme-generator/output/examples/')) return 'examples';
  if (lower.includes('/theme-generator/output/client-themes/')) return 'examples';
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
  addLog('Survey player ready');
  playerMode = event?.mode === 'inline' ? 'inline' : 'overlay';
  if (playerMode === 'inline') {
    playerWidgetRect = null;
    playerViewportSize = { width: 0, height: 0 };
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
  }
  updatePlayerOverlayLayout();
}

function resetPlayerOverlayLayout(frame) {
  overlayFallbackActive = false;
  overlayFallbackLogged = false;
  resetWidgetFallbackStyles();
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
  const placement = resolveFallbackPlacement();
  const metrics = computeOverlayFallbackMetrics({
    viewportWidth: viewport.width,
    viewportHeight: viewport.height,
    placement
  });

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

  playerFrameEl.style.pointerEvents = 'auto';
  playerFrameEl.style.visibility = 'visible';
  playerFrameEl.style.position = 'absolute';
  playerFrameEl.style.width = `${metrics.frameWidth}px`;
  playerFrameEl.style.height = `${metrics.frameHeight}px`;
  playerFrameEl.style.top = `${metrics.frameTop}px`;
  playerFrameEl.style.left = `${metrics.frameLeft}px`;
  playerFrameEl.style.clipPath = '';
  playerFrameEl.style.webkitClipPath = '';

  // Only start widget fallback styles retry if not already in progress
  // This prevents resetting the retry counter on every layout update
  if (!widgetFallbackTimer && !widgetFallbackApplied) {
    applyWidgetFallbackStyles({ placement, metrics }, 0);
  }
}

function resolveFallbackViewportSize() {
  const widthCandidates = [
    playerViewportSize?.width,
    typeof window !== 'undefined' ? window.innerWidth : null,
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
    height: Math.max(1, Math.round(resolve(heightCandidates, 768)))
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

function updatePlayerWidgetGeometry(message) {
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
  playerWidgetRect = rect;
  if (rect) {
    overlayFallbackActive = false;
    overlayFallbackLogged = false;
    resetWidgetFallbackStyles();
    if (overlayContainer) {
      delete overlayContainer.dataset.fallbackPlacement;
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
  updatePlayerOverlayLayout();
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

function scheduleOverlayLayoutUpdate({ immediate = false, trailing = false, delay = 280 } = {}) {
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

  const clippedTop = playerWidgetRect.top - marginTop;
  const clippedLeft = playerWidgetRect.left - marginLeft;
  const clippedWidth = playerWidgetRect.width + marginLeft + marginRight;
  const clippedHeight = playerWidgetRect.height + marginTop + marginBottom;

  overlayContainer.style.visibility = 'visible';
  overlayContainer.style.opacity = '1';
  overlayContainer.style.pointerEvents = 'auto';
  overlayContainer.style.overflow = 'hidden';
  overlayContainer.style.clipPath = '';
  overlayContainer.style.webkitClipPath = '';
  const containerWidth = Math.max(1, Math.round(clippedWidth));
  const containerHeight = Math.max(1, Math.round(clippedHeight));
  const containerTop = Math.round(clippedTop - rootRect.top);
  const containerLeft = Math.round(clippedLeft - rootRect.left);

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
  playerFrameEl.style.top = `${-Math.round(clippedTop)}px`;
  playerFrameEl.style.left = `${-Math.round(clippedLeft)}px`;
  playerFrameEl.style.width = `${Math.max(1, Math.round(viewportWidth))}px`;
  playerFrameEl.style.height = `${Math.max(1, Math.round(viewportHeight))}px`;

  console.debug('[preview] overlay layout applied', {
    widget: playerWidgetRect,
    container: {
      width: containerWidth,
      height: containerHeight,
      top: containerTop,
      left: containerLeft
    },
    viewport: playerViewportSize,
    mode: playerMode
  });
  playerViewportSize = {
    width: viewportWidth,
    height: viewportHeight
  };
}
