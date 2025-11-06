import { UI, aliasDom, N } from './ui/selectors.js';
import { configureLog, log } from './ui/log.js';
import { Theme } from './ui/theme.js';
import { emit } from './ui/events.js';
import { loadSurveys } from './services/surveys.js';
import {
  loadExampleThemes,
  applyThemeByHref,
  removeTheme,
  generateFromUrl,
  applyGeneratedTheme,
  revokeGeneratedAssets
} from './services/themes.js';
import {
  initPulseAdapter,
  bootTag,
  presentSurvey as adapterPresent,
  applyIdentifier,
  sendTrigger,
  resetAgent
} from './adapter/pulse-adapter.js';
import { TRIGGER_CONFIG, findTrigger } from './triggers/config.js';
import { initBehaviorDetectors } from './behaviors/detector.js';

aliasDom();

const PROXY_ORIGIN = (window.__PI_PROXY_ORIGIN__ || '').trim();

export const store = {
  url: 'https://example.com',
  device: 'Desktop',
  placement: 'BR',
  safeArea: true,
  tagReady: false,
  agentStatus: 'Idle',
  lastPresentedId: undefined,
  pendingSurveyId: undefined,
  agents: [],
  selectedAgent: undefined,
  stylesheetRegistry: new Map(),
  generatedThemeAssets: [],
  activeThemeId: undefined,
  logs: [],
  themeMode: 'dark',
  brandColor: '#7c5cff',
  radius: 8,
  density: 0
};

export const bus = new EventTarget();

export function setState(patch = {}) {
  Object.assign(store, patch);
  bus.dispatchEvent(new Event('state'));
}

configureLog(
  () => store,
  () => bus.dispatchEvent(new Event('state'))
);

const els = {};
let curatedThemes = [];
let generatedThemes = [];
const agentLookup = new Map();
const behaviorButtons = new Map();
let behaviorMessageTimer = null;
let behaviorStageTimer = null;
let detachBehaviorWatcher = null;
const PERFORMABLE_BEHAVIORS = new Set(['exit_intent', 'scroll_60', 'idle_10s', 'rage_click']);

document.addEventListener('DOMContentLoaded', init);

async function init() {
  cacheElements();
  buildBehaviorList();
  attachBehaviorOverlayControls();
  if (els.previewUrlInput) {
    els.previewUrlInput.value = store.url;
  }
  const mode = Theme.initFromStorage() || 'dark';
  store.themeMode = mode;
  Theme.applyQuickKnobs({
    brand: store.brandColor,
    radius: store.radius,
    density: store.density
  });
  const root = document.querySelector('.pi-v3');
  if (root) {
    root.setAttribute('data-density', String(store.density));
  }
  attachAccordion();
  attachToolbar();
  attachPlacementControls();
  attachAgentControls();
  attachThemeControls();
  attachTriggerControls();
  attachExampleControls();
  attachToolsControls();
  attachThemeModeControls();
  attachLogControls();

  render();
  bus.addEventListener('state', render);

  if (els.agentOverlay) {
    initPulseAdapter(els.agentOverlay);
    els.agentOverlay.dataset.placement = store.placement;
  }

  bootTag();

  const agents = await loadSurveys();
  setState({ agents });
  populateAgentOptions();
  selectDefaultAgentIfNeeded();

  curatedThemes = await loadExampleThemes();
  populateThemePreset();

  emit({ type: 'init', ts: Date.now(), data: { agents: agents.length, themes: curatedThemes.length } });
}

function cacheElements() {
  els.accordionItems = Array.from(document.querySelectorAll('.pi-v3__accordion-item'));
  els.accordionToggles = Array.from(document.querySelectorAll('[data-accordion-toggle]'));
  els.previewUrlInput = UI(N.previewUrl);
  els.urlField = els.previewUrlInput?.closest('.pi-v3__toolbar-group');
  els.urlMessage = null;
  els.safeAreaToggle = UI(N.safeArea);
  els.reloadBtn = UI(N.reload);
  els.deviceButtons = [
    UI(N.deviceDesktop),
    UI(N.deviceTablet),
    UI(N.deviceMobile)
  ].filter(Boolean);
  els.toolbarPlacementButtons = [
    UI(N.placementBR),
    UI(N.placementBL),
    UI(N.placementTR),
    UI(N.placementTL)
  ].filter(Boolean);
  els.agentPlacementGroup = UI(N.agentPlacement);
  els.agentPlacementButtons = Array.from(
    els.agentPlacementGroup?.querySelectorAll('[data-placement]') || []
  );
  els.agentInput = UI(N.agentSelect);
  if (els.agentInput) {
    let list = document.getElementById('pi-v3-agent-options');
    if (!list) {
      list = document.createElement('datalist');
      list.id = 'pi-v3-agent-options';
      document.body.appendChild(list);
    }
    els.agentInput.setAttribute('list', list.id);
    els.agentOptions = list;
  }
  els.launchAgent = UI(N.launchAgent);
  els.variantSelect = UI(N.agentVariant);
  els.embedLink = UI(N.codeSnippet);
  els.themeTabs = UI(N.themeMode);
  els.tabButtons = Array.from(els.themeTabs?.querySelectorAll('[data-tab]') || []);
  els.tabPanels = Array.from(document.querySelectorAll('.pi-v3__tab-panel'));
  els.themeSourceUrl = UI(N.themeSourceUrl);
  els.generateThemeBtn = UI(N.generateTheme);
  els.themeSuggestions = UI(N.generatedThemes);
  els.themePresetSelect = UI(N.themePreset);
  els.applyThemeBtn = document.getElementById('pi-v3-apply-theme');
  els.appliedStyles = document.getElementById('pi-v3-applied-styles');
  els.brandColor = UI(N.brandColor);
  els.cornerRadius = UI(N.cornerRadius);
  els.density = UI(N.density);
  els.themeModeButtons = Array.from(
    document.querySelectorAll('#pi-v3-theme-mode [data-theme-mode]')
  );
  els.triggerPresent = UI(N.triggerPresent);
  els.behaviorOverlay = document.getElementById('pi-v3-behavior-overlay');
  els.behaviorSurvey = document.getElementById('pi-v3-behavior-survey');
  els.behaviorList = document.getElementById('pi-v3-behavior-list');
  els.behaviorMessage = document.getElementById('pi-v3-behavior-message');
  els.behaviorStage = document.getElementById('pi-v3-behavior-stage');
  els.behaviorPresent = document.getElementById('pi-v3-behavior-present');
  els.exampleIndustry = UI(N.industry);
  els.exampleUsecase = UI(N.example);
  els.exampleChip = document.getElementById('pi-v3-example-chip');
  els.tagStatus = UI(N.tagStatus);
  els.agentStatus = UI(N.agentStatus);
  els.showLogBtn = UI(N.showLog);
  els.closeLogBtn = document.getElementById('pi-v3-close-log');
  els.logPanel = UI(N.logPanel);
  els.logList = document.getElementById('pi-v3-log-list');
  els.resetBtn = UI(N.resetDemo);
  els.frameWrapper = document.querySelector('.pi-v3__frame-wrapper');
  els.iframe = document.getElementById('pi-v3-frame');
  els.safeOutline = document.querySelector('.pi-v3__safe-outline');
  els.ghostAgent = document.querySelector('.pi-v3__ghost-agent');
  els.agentOverlay = document.getElementById('pi-v3-agent-overlay');
  els.appearanceHint = document.querySelector('[data-panel="auto"] .pi-v3__hint');
}

function buildBehaviorList() {
  if (!els.behaviorList) return;
  behaviorButtons.clear();
  els.behaviorList.innerHTML = '';

  const performableSpecs = TRIGGER_CONFIG.filter(
    (spec) => spec.type !== 'present' && PERFORMABLE_BEHAVIORS.has(spec.id)
  );
  const simulatedSpecs = TRIGGER_CONFIG.filter(
    (spec) => spec.type !== 'present' && !PERFORMABLE_BEHAVIORS.has(spec.id)
  );

  if (performableSpecs.length) {
    const performable = createBehaviorSection('Perform these behaviors', performableSpecs);
    els.behaviorList.appendChild(performable);
  }
  if (simulatedSpecs.length) {
    const simulated = createBehaviorSection(
      simulatedSpecs.length === 1 ? 'Simulate a journey' : 'Simulate journeys',
      simulatedSpecs
    );
    els.behaviorList.appendChild(simulated);
  }
}

function createBehaviorSection(title, specs) {
  const wrapper = document.createElement('div');
  wrapper.className = 'pi-v3__behavior-group';

  const heading = document.createElement('h4');
  heading.textContent = title;
  wrapper.appendChild(heading);

  const list = document.createElement('div');
  list.className = 'pi-v3__behavior-buttons';
  specs.forEach((spec) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'pi-v3__behavior-button';
    button.dataset.behaviorId = spec.id;
    button.title = spec.description || spec.label;

    const label = document.createElement('span');
    label.className = 'pi-v3__trigger-label';
    label.textContent = spec.label;
    button.appendChild(label);

    if (spec.description) {
      const detail = document.createElement('span');
      detail.textContent = spec.description;
      button.appendChild(detail);
    }

    button.addEventListener('click', () => {
      fireTrigger(spec, { source: 'overlay', announce: true });
    });
    behaviorButtons.set(spec.id, button);
    list.appendChild(button);
  });

  wrapper.appendChild(list);
  return wrapper;
}

function fireTrigger(spec, { source = 'grid', announce = false, detail } = {}) {
  if (!spec) return;
  try {
    if (Array.isArray(spec.command)) {
      sendTrigger(spec.command);
    } else {
      sendTrigger(spec.id);
    }
  } catch (_error) {
    /* sendTrigger already reports failures */
  }
  emit({ type: 'trigger', ts: Date.now(), triggerId: spec.id, source });
  highlightBehavior(spec.id);
  if (announce) {
    const state = source === 'detected' ? 'detected' : source === 'present' ? 'present' : 'simulated';
    setBehaviorMessage(spec, state, detail);
  }
}

function setBehaviorMessage(spec, state = 'info', detail) {
  if (!els.behaviorMessage) return;
  let text = detail || '';
  if (spec) {
    const prefix =
      state === 'detected' ? 'Detected' : state === 'present' ? 'Presented' : 'Simulated';
    text = `${prefix}: ${spec.label}`;
    if (detail) {
      text += ` — ${detail}`;
    } else if (spec.description && state !== 'present') {
      text += ` — ${spec.description}`;
    }
  }
  if (!text) {
    text = 'Waiting for the next behavior…';
  }
  els.behaviorMessage.textContent = text;
  els.behaviorMessage.dataset.state = state;
  window.clearTimeout(behaviorMessageTimer);
  if (state !== 'info') {
    behaviorMessageTimer = window.setTimeout(() => {
      if (!els.behaviorMessage) return;
      els.behaviorMessage.dataset.state = 'info';
      els.behaviorMessage.textContent = 'Waiting for the next behavior…';
    }, 4500);
  }
}

function highlightBehavior(behaviorId) {
  const button = behaviorButtons.get(behaviorId);
  if (button) {
    button.classList.add('is-active');
    window.clearTimeout(button._highlightTimer);
    button._highlightTimer = window.setTimeout(() => {
      button.classList.remove('is-active');
    }, 2000);
  }
  if (els.behaviorStage) {
    els.behaviorStage.classList.add('is-active');
    els.behaviorStage.dataset.lastBehavior = behaviorId;
    window.clearTimeout(behaviorStageTimer);
    behaviorStageTimer = window.setTimeout(() => {
      if (els.behaviorStage) {
        els.behaviorStage.classList.remove('is-active');
        if (els.behaviorStage.dataset) {
          delete els.behaviorStage.dataset.lastBehavior;
        }
      }
    }, 1600);
  }
}

function describeBehaviorDetail(behaviorId, meta = {}) {
  switch (behaviorId) {
    case 'scroll_60':
      if (typeof meta.percent === 'number') {
        return `~${Math.round(meta.percent)}% depth reached`;
      }
      return 'Scroll depth threshold reached';
    case 'idle_10s':
      return 'User paused for ~10 seconds';
    case 'exit_intent':
      return 'Cursor moved toward browser chrome';
    case 'rage_click':
      return 'Rapid clicks detected on the surface';
    default:
      return null;
  }
}

function attachBehaviorOverlayControls() {
  if (els.behaviorPresent && !els.behaviorPresent.dataset.bound) {
    els.behaviorPresent.dataset.bound = 'true';
    els.behaviorPresent.addEventListener('click', () => {
      presentActiveAgent(true);
      setBehaviorMessage(null, 'present', 'Presented the survey manually.');
    });
  }

  if (detachBehaviorWatcher) {
    detachBehaviorWatcher();
    detachBehaviorWatcher = null;
  }
  if (els.behaviorStage) {
    detachBehaviorWatcher = initBehaviorDetectors({
      stage: els.behaviorStage,
      onTrigger: (behaviorId, meta) => {
        const spec = findTrigger(behaviorId);
        if (!spec) return;
        const detail = describeBehaviorDetail(behaviorId, meta);
        fireTrigger(spec, { source: 'detected', announce: true, detail });
      }
    });
  }
  setBehaviorMessage(null, 'info');
}

function attachAccordion() {
  els.accordionToggles.forEach((button) => {
    button.addEventListener('click', () => {
      const expanded = button.getAttribute('aria-expanded') === 'true';
      if (expanded) return;
      const item = button.closest('.pi-v3__accordion-item');
      openAccordionItem(item);
    });
  });
}

function openAccordionItem(item) {
  if (!item) return;
  els.accordionItems.forEach((other) => {
    const body = other.querySelector('.pi-v3__accordion-body');
    const toggle = other.querySelector('[data-accordion-toggle]');
    const isTarget = other === item;
    toggle?.setAttribute('aria-expanded', String(isTarget));
    if (isTarget) {
      other.classList.add('pi-v3__accordion-item--open');
      body?.removeAttribute('hidden');
    } else {
      other.classList.remove('pi-v3__accordion-item--open');
      body?.setAttribute('hidden', '');
    }
  });
}

function attachToolbar() {
  els.previewUrlInput?.addEventListener('keydown', (event) => {
    if (event.key === 'Enter') {
      event.preventDefault();
      handleUrlCommit();
    }
  });
  els.previewUrlInput?.addEventListener('blur', handleUrlCommit);

  els.deviceButtons.forEach((button) => {
    button.addEventListener('click', () => {
      const device = button.dataset.device;
      if (device && device !== store.device) {
        setState({ device });
        log('ui', 'event', `Device switched to ${device}`);
      }
    });
  });

  els.safeAreaToggle?.addEventListener('change', () => {
    setState({ safeArea: !!els.safeAreaToggle.checked });
    log('ui', 'event', `Safe area ${els.safeAreaToggle.checked ? 'enabled' : 'disabled'}`);
  });

  els.reloadBtn?.addEventListener('click', () => {
    reloadFrame(true);
    log('ui', 'event', 'Preview reloaded');
  });
}

function attachPlacementControls() {
  els.toolbarPlacementButtons.forEach((button) => {
    button.addEventListener('click', () => {
      const placement = button.dataset.toolbarPlacement;
      if (placement) {
        setState({ placement });
        log('ui', 'event', `Placement set via toolbar ${placement}`);
      }
    });
  });
  els.agentPlacementButtons.forEach((button) => {
    button.addEventListener('click', () => {
      const placement = button.dataset.placement;
      if (placement) {
        setState({ placement });
        log('ui', 'event', `Placement set via agent section ${placement}`);
      }
    });
  });
}

function attachAgentControls() {
  els.agentInput?.addEventListener('change', handleAgentInput);
  els.agentInput?.addEventListener('keydown', (event) => {
    if (event.key === 'Enter') {
      event.preventDefault();
      handleAgentInput();
    }
  });

  els.launchAgent?.addEventListener('click', () => {
    presentActiveAgent(true);
  });

  els.embedLink?.addEventListener('click', (event) => {
    event.preventDefault();
    log('ui', 'event', 'Embed snippet requested');
  });
}

function attachThemeControls() {
  els.tabButtons.forEach((button) => {
    button.addEventListener('click', () => {
      const target = button.dataset.tab;
      switchTabs(target);
    });
  });

  els.generateThemeBtn?.addEventListener('click', async () => {
    const raw = (els.themeSourceUrl?.value || '').trim();
    if (!raw) {
      log('ui', 'warn', 'No URL provided for theme generation');
      return;
    }
    const url = normalizeUrl(raw);
    if (els.themeSourceUrl) {
      els.themeSourceUrl.value = url;
    }
    log('theme', 'event', `Generating themes from ${url}`);
    generatedThemes = await generateFromUrl(url);
    renderGeneratedSuggestions();
    if (generatedThemes.length) {
      applyGeneratedTheme(generatedThemes[0]);
      setState({ activeThemeId: generatedThemes[0].id });
    }
  });

  els.applyThemeBtn?.addEventListener('click', () => {
    const themeId = els.themePresetSelect?.value;
    if (!themeId) return;
    const descriptor = curatedThemes.find((theme) => theme.id === themeId);
    if (descriptor && descriptor.href) {
      applyThemeByHref(descriptor.id, descriptor.label, descriptor.href);
      setState({ activeThemeId: descriptor.id });
    }
  });

  const updateBrand = (value) => {
    if (!value) return;
    Theme.applyQuickKnobs({ brand: value });
    setState({ brandColor: value });
  };
  els.brandColor?.addEventListener('input', (event) => {
    updateBrand(event.target.value);
  });
  els.brandColor?.addEventListener('change', (event) => {
    updateBrand(event.target.value);
  });

  const updateRadius = (value) => {
    const radius = Number(value);
    if (Number.isNaN(radius)) return;
    Theme.applyQuickKnobs({ radius });
    setState({ radius });
  };
  els.cornerRadius?.addEventListener('input', (event) => {
    updateRadius(event.target.value);
  });

  const updateDensity = (value) => {
    const density = Number(value);
    if (Number.isNaN(density)) return;
    Theme.applyQuickKnobs({ density });
    setState({ density });
  };
  els.density?.addEventListener('change', (event) => {
    updateDensity(event.target.value);
  });
}

function attachTriggerControls() {
  els.triggerPresent?.addEventListener('click', () => {
    presentActiveAgent(true);
  });
}

function attachExampleControls() {
  els.exampleIndustry?.addEventListener('change', updateExampleChip);
  els.exampleUsecase?.addEventListener('change', updateExampleChip);
}

function attachToolsControls() {
  els.resetBtn?.addEventListener('click', handleReset);
}

function attachThemeModeControls() {
  if (!els.themeModeButtons?.length) return;
  els.themeModeButtons.forEach((button) => {
    button.addEventListener('click', () => {
      const mode = button.dataset.themeMode;
      if (!mode || store.themeMode === mode) return;
      Theme.setMode(mode);
      setState({ themeMode: mode });
      log('ui', 'event', 'Theme mode changed', { mode });
    });
  });
}

function attachLogControls() {
  els.showLogBtn?.addEventListener('click', () => {
    els.logPanel?.classList.add('is-open');
  });
  els.closeLogBtn?.addEventListener('click', () => {
    els.logPanel?.classList.remove('is-open');
  });
}

function handleAgentInput() {
  const value = (els.agentInput?.value || '').trim();
  const agent = resolveAgent(value);
  if (!agent) {
    log('ui', 'warn', 'Agent selection not found', { value });
    return;
  }
  setState({ selectedAgent: agent });
  if (els.agentInput && agent.label) {
    els.agentInput.value = agent.label;
  }
  if (agent.identifier) {
    applyIdentifier(agent.identifier);
  }
  if (agent.backgroundUrl) {
    setPreviewUrl(agent.backgroundUrl, { fromAgent: true });
  }
  adapterPresent(agent);
  log('ui', 'event', 'Agent selected', { id: agent.id });
}

function presentActiveAgent(force = false) {
  if (!store.selectedAgent) {
    handleAgentInput();
  }
  if (!store.selectedAgent) return;
  setState({ agentStatus: 'Presenting' });
  adapterPresent(store.selectedAgent, { force });
  window.clearTimeout(presentActiveAgent.timeout);
  presentActiveAgent.timeout = window.setTimeout(() => {
    setState({ agentStatus: 'Idle' });
  }, 2500);
}

function normalizeUrl(value) {
  if (!value) return '';
  if (/^https?:\/\//i.test(value)) return value;
  return `https://${value}`;
}

function shouldProxyPreview(url) {
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

function buildPreviewSrc(url) {
  if (!url) return url;
  const trimmed = url.trim();
  if (!shouldProxyPreview(trimmed)) return trimmed;
  const base = PROXY_ORIGIN.replace(/\/$/, '');
  const encoded = encodeURIComponent(trimmed);
  if (!base) return `/proxy?url=${encoded}`;
  return `${base}/proxy?url=${encoded}`;
}

function handleUrlCommit() {
  const raw = (els.previewUrlInput?.value || '').trim();
  if (!raw) {
    showUrlMessage('Please enter a URL.');
    return;
  }
  const normalized = normalizeUrl(raw);
  try {
    // Validate URL
    new URL(normalized);
  } catch (error) {
    showUrlMessage('That does not look like a valid URL.');
    return;
  }
  hideUrlMessage();
  setPreviewUrl(normalized);
}

function setPreviewUrl(url, { fromAgent = false } = {}) {
  if (store.url === url) {
    if (els.previewUrlInput && !fromAgent) {
      els.previewUrlInput.value = url;
    }
    return;
  }
  setState({ url });
  if (els.previewUrlInput) {
    els.previewUrlInput.value = url;
  }
  reloadFrame(true);
  log('ui', 'event', 'Preview URL updated', { url, fromAgent });
}

function reloadFrame(force = false) {
  if (!els.iframe) return;
  if (!force && els.iframe.dataset.previewUrl === store.url) return;
  try {
    const src = buildPreviewSrc(store.url);
    els.iframe.dataset.previewUrl = store.url;
    els.iframe.setAttribute('src', src || 'about:blank');
  } catch (error) {
    showUrlMessage('Unable to load URL.');
    log('ui', 'error', 'Iframe load failed', { error: String(error) });
    emit({
      type: 'error',
      ts: Date.now(),
      code: 'cors',
      message: 'Previewed site refused to load (CORS).',
      data: { error: String(error), url: store.url }
    });
  }
}

function render() {
  renderPlacement();
  renderOverlayState();
  renderDevice();
  renderFrame();
  renderSafeArea();
  renderGhost();
  renderBadges();
  renderLogs();
  renderAppliedStyles();
  renderGeneratedSuggestions();
  renderThemePresetSelection();
  renderQuickKnobs();
  renderThemeMode();
  renderBehaviorOverlay();
  renderExampleChip();
}

function renderPlacement() {
  const placement = store.placement;
  els.toolbarPlacementButtons.forEach((button) => {
    button.classList.toggle('is-active', button.dataset.toolbarPlacement === placement);
  });
  els.agentPlacementButtons.forEach((button) => {
    button.classList.toggle('is-active', button.dataset.placement === placement);
  });
  if (els.agentOverlay) {
    els.agentOverlay.dataset.placement = placement;
  }
  if (els.ghostAgent) {
    els.ghostAgent.dataset.placement = placement;
  }
}

function renderOverlayState() {
  if (!els.agentOverlay) return;
  const active = store.tagReady && !!store.lastPresentedId;
  els.agentOverlay.classList.toggle('is-active', active);
}

function renderDevice() {
  const device = store.device;
  els.deviceButtons.forEach((button) => {
    button.classList.toggle('is-active', button.dataset.device === device);
  });
  if (els.frameWrapper) {
    els.frameWrapper.dataset.device = device;
  }
  if (els.ghostAgent) {
    els.ghostAgent.dataset.device = device;
  }
}

function renderFrame() {
  if (!els.iframe) return;
  if (els.iframe.dataset.previewUrl !== store.url) {
    reloadFrame(false);
  }
}

function renderSafeArea() {
  if (els.safeAreaToggle) {
    els.safeAreaToggle.checked = store.safeArea;
  }
  if (!els.safeOutline) return;
  if (store.safeArea) {
    els.safeOutline.removeAttribute('hidden');
  } else {
    els.safeOutline.setAttribute('hidden', '');
  }
}

function renderGhost() {
  if (!els.ghostAgent) return;
  const visible = !(store.tagReady && store.agentStatus === 'Presenting');
  els.ghostAgent.style.display = visible ? 'flex' : 'none';
}

function renderBadges() {
  if (els.tagStatus) {
    els.tagStatus.textContent = `Tag: ${store.tagReady ? 'Ready' : 'Not found'}`;
  }
  if (els.agentStatus) {
    els.agentStatus.textContent = `Agent: ${store.agentStatus || 'Idle'}`;
  }
}

function renderLogs() {
  if (!els.logList) return;
  els.logList.innerHTML = '';
  store.logs.forEach((entry) => {
    const li = document.createElement('li');
    const time = document.createElement('time');
    time.dateTime = new Date(entry.ts).toISOString();
    time.textContent = new Date(entry.ts).toLocaleTimeString();
    const body = document.createElement('div');
    body.textContent = `[${entry.source}] ${entry.message}`;
    li.appendChild(time);
    li.appendChild(body);
    els.logList.appendChild(li);
  });
}

function renderAppliedStyles() {
  if (!els.appliedStyles) return;
  els.appliedStyles.innerHTML = '';
  const entries = Array.from((store.stylesheetRegistry || new Map()).values());
  if (!entries.length) {
    const hint = document.createElement('p');
    hint.className = 'pi-v3__hint';
    hint.textContent = 'No styles applied.';
    els.appliedStyles.appendChild(hint);
    return;
  }
  entries.forEach((descriptor) => {
    const chip = document.createElement('div');
    chip.className = 'pi-v3__chip';
    chip.textContent = descriptor.label || descriptor.id;
    if (store.activeThemeId === descriptor.id) {
      chip.classList.add('is-active');
    }
    const removeBtn = document.createElement('button');
    removeBtn.className = 'pi-v3__chip-remove';
    removeBtn.type = 'button';
    removeBtn.textContent = '×';
    removeBtn.setAttribute('aria-label', `Remove ${descriptor.label || descriptor.id}`);
    removeBtn.addEventListener('click', () => {
      removeTheme(descriptor.id);
    });
    chip.appendChild(removeBtn);
    els.appliedStyles.appendChild(chip);
  });
}

function renderGeneratedSuggestions() {
  if (!els.themeSuggestions) return;
  els.themeSuggestions.innerHTML = '';
  if (!generatedThemes.length) return;
  generatedThemes.forEach((theme) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.textContent = theme.label || theme.id;
    if (store.activeThemeId === theme.id) {
      button.classList.add('is-active');
    }
    button.addEventListener('click', () => {
      applyGeneratedTheme(theme);
      setState({ activeThemeId: theme.id });
    });
    els.themeSuggestions.appendChild(button);
  });
}

function renderThemePresetSelection() {
  if (!els.themePresetSelect) return;
  const active = store.activeThemeId;
  const hasActiveCurated = curatedThemes.some((theme) => theme.id === active);
  els.themePresetSelect.value = hasActiveCurated ? active : '';
}

function renderQuickKnobs() {
  if (els.brandColor && els.brandColor.value !== store.brandColor) {
    els.brandColor.value = store.brandColor;
  }
  if (els.cornerRadius && Number(els.cornerRadius.value) !== store.radius) {
    els.cornerRadius.value = String(store.radius);
  }
  if (els.density && els.density.value !== String(store.density)) {
    els.density.value = String(store.density);
  }
}

function renderThemeMode() {
  if (!els.themeModeButtons?.length) return;
  els.themeModeButtons.forEach((button) => {
    const isActive = button.dataset.themeMode === store.themeMode;
    button.classList.toggle('is-active', isActive);
    button.setAttribute('aria-pressed', String(isActive));
  });
}

function renderBehaviorOverlay() {
  if (els.behaviorSurvey) {
    const agent = store.selectedAgent;
    if (agent) {
      els.behaviorSurvey.textContent = agent.label || `Survey ${agent.id}`;
    } else {
      els.behaviorSurvey.textContent = 'Select an agent from the rail to begin.';
    }
  }
  if (els.behaviorPresent) {
    const disabled = store.agentStatus === 'Presenting';
    els.behaviorPresent.disabled = disabled;
  }
}

function renderExampleChip() {
  if (!els.exampleChip) return;
  const usecase = els.exampleUsecase?.value;
  const industry = els.exampleIndustry?.value;
  if (usecase && usecase !== '—') {
    els.exampleChip.hidden = false;
    els.exampleChip.textContent = `Applied example: ${usecase}${industry ? ` (${industry})` : ''}`;
  } else {
    els.exampleChip.hidden = true;
  }
}

function populateAgentOptions() {
  if (!els.agentOptions) return;
  els.agentOptions.innerHTML = '';
  agentLookup.clear();
  store.agents.forEach((agent) => {
    const option = document.createElement('option');
    option.value = agent.label;
    els.agentOptions.appendChild(option);
    agentLookup.set(agent.label.toLowerCase(), agent);
    agentLookup.set(String(agent.id), agent);
  });
}

function selectDefaultAgentIfNeeded() {
  if (store.selectedAgent) return;
  if (!Array.isArray(store.agents) || !store.agents.length) return;
  const agent = store.agents[0];
  if (!agent) return;
  setState({ selectedAgent: agent });
  if (els.agentInput && agent.label) {
    els.agentInput.value = agent.label;
  }
  if (agent.identifier) {
    applyIdentifier(agent.identifier);
  }
  if (agent.backgroundUrl) {
    setPreviewUrl(agent.backgroundUrl, { fromAgent: true });
  }
  presentActiveAgent(true);
  log('ui', 'event', 'Default agent auto-selected', { id: agent.id });
}

function populateThemePreset() {
  if (!els.themePresetSelect) return;
  els.themePresetSelect.innerHTML = '';
  const placeholder = document.createElement('option');
  placeholder.value = '';
  placeholder.textContent = 'Select a curated theme';
  els.themePresetSelect.appendChild(placeholder);
  curatedThemes.forEach((theme) => {
    const option = document.createElement('option');
    option.value = theme.id;
    option.textContent = theme.label;
    els.themePresetSelect.appendChild(option);
  });
  renderThemePresetSelection();
}

function resolveAgent(value) {
  if (!value) return undefined;
  const entry = agentLookup.get(value.toLowerCase()) || agentLookup.get(value);
  return entry;
}

function switchTabs(target) {
  els.tabButtons.forEach((button) => {
    const isActive = button.dataset.tab === target;
    button.setAttribute('aria-selected', String(isActive));
  });
  els.tabPanels.forEach((panel) => {
    panel.hidden = panel.dataset.panel !== target;
  });
}

function updateExampleChip() {
  renderExampleChip();
  const usecase = els.exampleUsecase?.value;
  const industry = els.exampleIndustry?.value;
  log('ui', 'event', 'Example selection updated', { usecase, industry });
}

function handleReset() {
  revokeGeneratedAssets();
  Array.from((store.stylesheetRegistry || new Map()).keys()).forEach((id) => removeTheme(id));
  if (presentActiveAgent.timeout) {
    window.clearTimeout(presentActiveAgent.timeout);
    presentActiveAgent.timeout = undefined;
  }
  generatedThemes = [];
  setState({
    url: 'https://example.com',
    device: 'Desktop',
    placement: 'BR',
    safeArea: true,
    agentStatus: 'Idle',
    lastPresentedId: undefined,
    pendingSurveyId: undefined,
    selectedAgent: undefined,
    activeThemeId: undefined,
    stylesheetRegistry: new Map(),
    themeMode: 'dark',
    brandColor: '#7c5cff',
    radius: 8,
    density: 0
  });
  Theme.setMode('dark');
  Theme.applyQuickKnobs({ brand: '#7c5cff', radius: 8, density: 0 });
  if (els.previewUrlInput) {
    els.previewUrlInput.value = store.url;
  }
  reloadFrame(true);
  resetAgent();
  renderAppliedStyles();
  renderGeneratedSuggestions();
  log('ui', 'event', 'Demo reset to defaults');
}

function showUrlMessage(text) {
  if (!els.urlField) return;
  if (!els.urlMessage) {
    const message = document.createElement('p');
    message.className = 'pi-v3__hint';
    message.style.color = 'var(--pi-danger)';
    message.setAttribute('role', 'alert');
    els.urlField.appendChild(message);
    els.urlMessage = message;
  }
  els.urlMessage.textContent = text;
}

function hideUrlMessage() {
  if (els.urlMessage) {
    els.urlMessage.remove();
    els.urlMessage = null;
  }
}
