import elements, { setOptions } from './ui/elements.js';
import { clearStatus, addStatus, updateStatus } from './ui/status.js';
import { renderTriggers } from './ui/triggers.js';
import { initThemeManager } from './ui/themeManager.js';
import {
  loadManifest,
  listClients,
  findClient,
  listThemes,
  findTheme,
  listWidgets,
  findWidget
} from './services/manifest.js';
import { loadDemoSurveys } from './services/demoData.js';
import { loadBackground, loadSimpleBackground } from './services/background.js';
import { createSurveyBridge } from './survey/bridge.js';
import { resolveProxyUrl, getProxyOrigin } from './services/proxy.js';

const DEFAULT_BACKGROUND = 'https://www.pulseinsights.com/agents';
const DEFAULT_ACCOUNT = 'PI-81598442';
const DEFAULT_HOST = 'survey.pulseinsights.com';
const DEFAULT_TAG_SRC = 'https://js.pulseinsights.com/surveys.js';
const INLINE_PATTERN = /inline/i;

const state = {
  manifest: [],
  demoSurveys: [],
  client: null,
  theme: null,
  widget: null,
  survey: null,
  account: DEFAULT_ACCOUNT,
  host: DEFAULT_HOST,
  themeCss: null,
  manualCss: null,
  inlineSelector: null,
  mode: 'overlay',
  playerLoaded: false,
  awaitingManualPresent: false,
  surveyVisible: false
};

function applyManifest(manifest, { preserveSelections = true } = {}) {
  const previousClient = preserveSelections ? state.client : null;
  const previousTheme = preserveSelections ? state.theme : null;
  const previousWidget = preserveSelections ? state.widget : null;

  state.manifest = Array.isArray(manifest) ? manifest : [];

  const clientOptions = listClients(state.manifest);
  setOptions(elements.clientSelect, clientOptions);

  if (previousClient && clientOptions.some((option) => option.value === previousClient)) {
    elements.clientSelect.value = previousClient;
    state.client = previousClient;
  } else {
    state.client = null;
  }

  const clientEntry = findClient(state.manifest, state.client);
  const themeOptions = listThemes(clientEntry);
  setOptions(elements.themeSelect, themeOptions);

  if (state.client && previousTheme && themeOptions.some((option) => option.value === previousTheme)) {
    elements.themeSelect.value = previousTheme;
    state.theme = previousTheme;
  } else {
    state.theme = null;
  }

  const themeEntry = findTheme(clientEntry, state.theme);
  const widgetOptions = listWidgets(themeEntry);
  setOptions(elements.widgetSelect, widgetOptions);

  if (state.theme && previousWidget && widgetOptions.some((option) => option.value === previousWidget)) {
    elements.widgetSelect.value = previousWidget;
    state.widget = previousWidget;
  } else {
    state.widget = null;
  }
}

async function reloadManifest({ preserveSelections = true } = {}) {
  const manifest = await loadManifest();
  applyManifest(manifest, { preserveSelections });
}

const surveyBridge = createSurveyBridge({
  container: elements.overlayContainer,
  onReady: handlePlayerReady,
  onStatus: handlePlayerStatus,
  onStateChange: handleBridgeStateChange
});

let statusReadyRow = null;

init();

async function init() {
  clearStatus(elements.statusList);
  statusReadyRow = addStatus(elements.statusList, 'Loading manifest…');

  try {
    state.manifest = await loadManifest();
    updateStatus(statusReadyRow, 'Manifest ready', 'ready');
  } catch (error) {
    updateStatus(statusReadyRow, `Manifest failed: ${error.message}`, 'error');
  }

  applyManifest(state.manifest, { preserveSelections: false });

  try {
    state.demoSurveys = await loadDemoSurveys();
  } catch (error) {
    console.warn('Failed to load demo survey data', error);
  }

  populateSurveySelect();
  attachEventListeners();
  loadBackground(elements.backgroundFrame, DEFAULT_BACKGROUND);
  elements.backgroundInput.value = DEFAULT_BACKGROUND;
  elements.accountIndicator.textContent = state.account;
  renderTriggers(elements.triggerContainer, buildTriggerConfig(), { onTrigger: handleTrigger });
  initThemeManager({
    onThemesChanged: async ({ clientId, themeName, cssPath }) => {
      try {
        if (cssPath && state.themeCss === cssPath) {
          state.themeCss = null;
          surveyBridge.clearTheme();
          addStatus(
            elements.statusList,
            `Removed active theme ${themeName} from the player because its CSS was deleted.`,
            'ready'
          );
        }
        await reloadManifest({ preserveSelections: true });
      } catch (error) {
        addStatus(
          elements.statusList,
          `Theme manifest refresh failed after removing ${themeName} (${clientId}): ${error.message}`,
          'error'
        );
      }
    },
    notify: (message, tone = 'info') => {
      const stateName = tone === 'error' ? 'error' : 'ready';
      addStatus(elements.statusList, message, stateName);
    }
  });
}

function attachEventListeners() {
  elements.clientSelect.addEventListener('change', () => {
    state.client = elements.clientSelect.value;
    populateThemeSelect();
    updateModeBadge();
  });

  elements.themeSelect.addEventListener('change', () => {
    state.theme = elements.themeSelect.value;
    populateWidgetSelect();
  });

  elements.widgetSelect.addEventListener('change', () => {
    state.widget = elements.widgetSelect.value;
  });

  elements.surveySelect.addEventListener('change', () => {
    const surveyId = Number.parseInt(elements.surveySelect.value, 10);
    const record = state.demoSurveys.find((item) => item.surveyId === surveyId) || null;
    const previousSurveyId = state.survey ? state.survey.surveyId : null;
    state.survey = record;
    state.awaitingManualPresent = Boolean(record);
    if (!record) {
      state.inlineSelector = null;
      state.mode = 'overlay';
      updateModeBadge();
      setSurveyVisibility(false);
      return;
    }

    const nextAccount = record.identifier || DEFAULT_ACCOUNT;
    const nextHost = DEFAULT_HOST;
    const nextMode = INLINE_PATTERN.test(record.surveyTypeName || '') ? 'inline' : 'overlay';
    const normalizedInlineSelector =
      record.inlineTargetSelector && !/^null$/i.test(record.inlineTargetSelector)
        ? record.inlineTargetSelector
        : null;

    const requiresReload =
      !state.playerLoaded ||
      previousSurveyId === null ||
      nextAccount !== state.account ||
      nextHost !== state.host ||
      nextMode !== state.mode ||
      normalizedInlineSelector !== state.inlineSelector;

    state.account = nextAccount;
    state.host = nextHost;
    state.mode = nextMode;
    state.inlineSelector = normalizedInlineSelector;
    elements.accountIndicator.textContent = state.account;
    updateModeBadge();
    setSurveyVisibility(false);
    addStatus(
      elements.statusList,
      `Survey ${record.surveyId} (${record.surveyName}) selected — present manually when ready`,
      'info'
    );

    if (requiresReload) {
      addStatus(
        elements.statusList,
        `Preparing player for survey ${record.surveyId} (${record.surveyName})`,
        'info'
      );
      loadPlayer({ autoPresent: false });
    }
  });

  elements.applyThemeBtn.addEventListener('click', () => {
    const themeEntry = getActiveTheme();
    if (!themeEntry) return;
    state.themeCss = themeEntry.css;
    surveyBridge.applyTheme(state.themeCss);
    updateStatus(addStatus(elements.statusList, 'Theme applied', 'ready'), 'Theme applied', 'ready');
  });

  elements.clearThemeBtn.addEventListener('click', () => {
    state.themeCss = null;
    surveyBridge.clearTheme();
    updateStatus(addStatus(elements.statusList, 'Theme cleared', 'ready'), 'Theme cleared', 'ready');
  });

  elements.manualApplyBtn.addEventListener('click', () => {
    const value = elements.manualCssInput.value.trim();
    if (!value) return;
    state.manualCss = value;
    surveyBridge.applyManualCss(value);
    addStatus(elements.statusList, `Injected CSS ${value}`, 'ready');
  });

  elements.manualClearBtn.addEventListener('click', () => {
    state.manualCss = null;
    surveyBridge.clearManualCss();
    addStatus(elements.statusList, 'Removed manual CSS', 'ready');
  });

  elements.presentSurveyBtn.addEventListener('click', () => {
    if (!state.survey) return;
    if (!state.playerLoaded) {
      addStatus(
        elements.statusList,
        'Survey player not loaded – loading now before presenting',
        'info'
      );
      loadPlayer({ autoPresent: false });
    }
    state.awaitingManualPresent = false;
    setSurveyVisibility(true);
    surveyBridge.present(state.survey.surveyId);
    addStatus(
      elements.statusList,
      `Presented survey ${state.survey.surveyId} via manual trigger`,
      'ready'
    );
  });

  elements.resetSurveyBtn.addEventListener('click', () => {
    loadPlayer({ autoPresent: false });
    addStatus(elements.statusList, 'Survey player reset – survey hidden', 'info');
  });

  elements.backgroundApplyBtn.addEventListener('click', () => {
    loadBackground(elements.backgroundFrame, elements.backgroundInput.value);
  });

  elements.backgroundSimpleBtn.addEventListener('click', () => {
    loadSimpleBackground(elements.backgroundFrame);
  });

  elements.refreshBtn.addEventListener('click', () => {
    loadBackground(elements.backgroundFrame, elements.backgroundInput.value);
    loadPlayer({ autoPresent: false });
  });

  elements.openWidgetBtn.addEventListener('click', () => {
    const widgetEntry = getActiveWidget();
    if (widgetEntry && widgetEntry.path) {
      window.open(widgetEntry.path, '_blank', 'noopener');
    }
  });

  elements.openPlayerBtn.addEventListener('click', () => {
    surveyBridge.openInNewTab();
  });
}

function populateThemeSelect() {
  const clientEntry = findClient(state.manifest, state.client);
  const themes = listThemes(clientEntry);
  setOptions(elements.themeSelect, themes);
  state.theme = null;
  elements.widgetSelect.innerHTML = '';
}

function populateWidgetSelect() {
  const clientEntry = findClient(state.manifest, state.client);
  const themeEntry = findTheme(clientEntry, state.theme);
  const widgets = listWidgets(themeEntry);
  setOptions(elements.widgetSelect, widgets);
}

function populateSurveySelect() {
  const surveys = state.demoSurveys.map((item) => ({
    value: item.surveyId,
    label: `${item.surveyName} · ${item.identifier || 'Unknown'} (${item.surveyTypeName || 'Survey'})`
  }));
  setOptions(elements.surveySelect, surveys, { placeholder: '-- select survey --' });
}

function setSurveyVisibility(visible) {
  state.surveyVisible = Boolean(visible);
  elements.overlayContainer.classList.toggle('survey-visible', state.surveyVisible);
  updateSurveyIndicator();
}

function updateSurveyIndicator() {
  if (state.surveyVisible && state.survey) {
    elements.surveyIndicator.textContent = `Presenting survey ${state.survey.surveyName}`;
    return;
  }

  if (state.surveyVisible) {
    elements.surveyIndicator.textContent = 'Survey presented';
    return;
  }

  if (state.awaitingManualPresent && state.survey) {
    elements.surveyIndicator.textContent = `Ready to present survey ${state.survey.surveyName}`;
    return;
  }

  if (state.survey && state.playerLoaded) {
    elements.surveyIndicator.textContent = `Player ready for survey ${state.survey.surveyName}`;
    return;
  }

  if (state.survey) {
    elements.surveyIndicator.textContent = `Survey selected: ${state.survey.surveyName}`;
    return;
  }

  if (state.playerLoaded) {
    elements.surveyIndicator.textContent = 'Player ready';
    return;
  }

  elements.surveyIndicator.textContent = 'No survey presented';
}

function buildTriggerConfig() {
  return [
    { id: 'present-selected', label: 'Present Selected' },
    { id: 'exit-intent', label: 'Simulate Exit Intent' },
    { id: 'rage-click', label: 'Simulate Rage Click' },
    { id: 'scroll-depth', label: 'Simulate Scroll Depth' },
    { id: 'time-delay', label: 'Simulate Timer' },
    { id: 'pageview', label: 'Increment Pageview' }
  ];
}

function handleTrigger(trigger) {
  if (!trigger || !trigger.id) return;
  if (!state.playerLoaded) {
    addStatus(
      elements.statusList,
      `Survey player not loaded — loading before handling ${trigger.label}`,
      'info'
    );
    loadPlayer({ autoPresent: false });
  }
  if (trigger.id === 'present-selected' && state.survey) {
    state.awaitingManualPresent = false;
    setSurveyVisibility(true);
  }
  surveyBridge.sendTrigger(trigger.id);
  addStatus(elements.statusList, `Trigger sent: ${trigger.label}`, 'ready');
}

function loadPlayer({ autoPresent = false } = {}) {
  const shouldPresent = Boolean(autoPresent && state.survey);
  const config = {
    account: state.account,
    host: state.host,
    present: shouldPresent && state.survey ? [state.survey.surveyId] : [],
    inlineSelector: state.inlineSelector,
    themeCss: state.themeCss,
    manualCss: state.manualCss,
    mode: state.mode,
    tagSrc: resolveProxyUrl(DEFAULT_TAG_SRC),
    proxyOrigin: getProxyOrigin()
  };
  state.awaitingManualPresent = Boolean(state.survey) && !shouldPresent;
  surveyBridge.setInlineMode(state.mode === 'inline');
  elements.inlineNote.classList.toggle('visible', state.mode === 'inline');
  surveyBridge.load(config);
  state.playerLoaded = true;
  setSurveyVisibility(shouldPresent);
}

function handlePlayerReady() {
  addStatus(elements.statusList, 'Survey player ready', 'ready');
  if (state.themeCss) {
    surveyBridge.applyTheme(state.themeCss);
  }
  if (state.manualCss) {
    surveyBridge.applyManualCss(state.manualCss);
  }
  updateSurveyIndicator();
}

function handleBridgeStateChange(change) {
  if (!change) return;
  try {
    console.log('[bridge] state change', change);
  } catch (_error) {
    /* ignore */
  }
}

function handlePlayerStatus(message) {
  if (message.type === 'player-status' && message.triggerId) {
    addStatus(elements.statusList, `Trigger handled: ${message.triggerId}`, 'ready');
  }
}

function updateModeBadge() {
  elements.modeIndicator.textContent = state.mode === 'inline' ? 'Inline Mode' : 'Overlay Mode';
  elements.inlineNote.classList.toggle('visible', state.mode === 'inline');
  surveyBridge.setInlineMode(state.mode === 'inline');
}

function getActiveTheme() {
  const clientEntry = findClient(state.manifest, state.client);
  return findTheme(clientEntry, state.theme);
}

function getActiveWidget() {
  const clientEntry = findClient(state.manifest, state.client);
  const themeEntry = findTheme(clientEntry, state.theme);
  return findWidget(themeEntry, state.widget);
}
