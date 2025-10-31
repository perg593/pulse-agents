import { loadManifest, computeContrast } from './previewUtils.js';
import { mountWidget, unmountWidgets } from './embeds.js';

const state = {
  manifest: [],
  clients: [],
  currentClient: null,
  currentTheme: null,
  currentWidget: null,
  currentWidgetPath: null,
  isInline: false,
  appliedCssHref: null,
  manualCssHref: null,
  backgroundBaseUrl: 'https://www.pulseinsights.com'
};

const widgetsSelect = document.getElementById('widget-select');
const clientSelect = document.getElementById('client-select');
const themeSelect = document.getElementById('theme-select');
const backgroundFrame = document.getElementById('background-frame');
const backgroundInput = document.getElementById('background-input');
const backgroundApplyBtn = document.getElementById('background-apply');
const manualCssInput = document.getElementById('manual-css');
const manualApplyBtn = document.getElementById('manual-apply');
const themeToggle = document.getElementById('toggle-theme');
const contrastResults = document.getElementById('contrast-results');
const refreshBtn = document.getElementById('refresh-widget');
const openBtn = document.getElementById('open-widget');
const stage = document.querySelector('.preview-stage');
const inlineNote = document.getElementById('inline-note');
const overlayContainer = document.getElementById('overlay-container');

const MANIFEST_PATH = '/theme-generator/output/preview-manifest.json';
const THEME_PLACEHOLDER = '/* CLIENT_THEME_CSS */';
const PREVIEW_PAYLOAD_PARAM = 'previewWidget';

function option(value, label) {
  const opt = document.createElement('option');
  opt.value = value;
  opt.textContent = label;
  return opt;
}

function clearSelect(selectEl, placeholder = '-- Choose --') {
  selectEl.innerHTML = '';
  const placeholderOpt = option('', placeholder);
  placeholderOpt.disabled = true;
  placeholderOpt.selected = true;
  selectEl.appendChild(placeholderOpt);
}

function populateClients() {
  clearSelect(clientSelect, '-- Select client --');
  state.clients.forEach(client => {
    clientSelect.appendChild(option(client.clientId, client.clientLabel || client.clientId));
  });
}

function populateThemes(themes) {
  clearSelect(themeSelect, '-- Select theme --');
  themes.forEach(theme => {
    themeSelect.appendChild(option(theme.themeId, theme.themeName || theme.themeId));
  });
}

function populateWidgets(widgets) {
  clearSelect(widgetsSelect, '-- Select widget --');
  widgets.forEach(widget => {
    widgetsSelect.appendChild(option(widget.id, widget.label || widget.id));
  });
}

async function init() {
  try {
    state.manifest = await loadManifest(MANIFEST_PATH);
    state.clients = state.manifest;
    populateClients();

    const defaultBackground = 'https://www.pulseinsights.com';
    backgroundInput.value = defaultBackground;
    applyBackground(defaultBackground);

    const defaultClient = 'pulseinsights';
    const defaultTheme = 'brand-faithful';
    const defaultWidget = 'docked-desktop';
    const clientEntry = state.manifest.find(entry => entry.clientId === defaultClient);
    if (clientEntry) {
      state.currentClient = defaultClient;
      clientSelect.value = defaultClient;
      applyManifestSelection();

      const themeEntry = clientEntry.themes.find(theme => theme.themeId === defaultTheme);
      if (themeEntry) {
        state.currentTheme = defaultTheme;
        themeSelect.value = defaultTheme;
        state.currentWidget = defaultWidget;
        updateWidgetsAndCssOptions({ preselectWidget: defaultWidget });

        const chosenWidget = themeEntry.widgets.find(widget => widget.id === defaultWidget);
        if (chosenWidget) {
          widgetsSelect.value = defaultWidget;
          loadWidget(chosenWidget.path);
        }
      }
    }
  } catch (error) {
    console.error('Failed to initialize preview:', error);
    alert('Failed to load preview manifest. Check console for details.');
  }
}

function applyManifestSelection() {
  if (!state.currentClient) return;
  const clientEntry = state.manifest.find(entry => entry.clientId === state.currentClient);
  if (!clientEntry) return;

  populateThemes(clientEntry.themes);
  state.currentTheme = null;
  state.currentWidget = null;
  clearSelect(widgetsSelect);
}

function findThemeEntry(clientId, themeId) {
  const clientEntry = state.manifest.find(entry => entry.clientId === clientId);
  if (!clientEntry) return null;
  return clientEntry.themes.find(theme => theme.themeId === themeId) || null;
}

function normalizeCssHref(href) {
  if (!href) return null;
  return href.startsWith('/') ? href : `/${href}`;
}

function updateWidgetsAndCssOptions(options = {}) {
  if (!state.currentClient || !state.currentTheme) return;
  const themeEntry = findThemeEntry(state.currentClient, state.currentTheme);
  if (!themeEntry) return;

  populateWidgets(themeEntry.widgets);
  state.appliedCssHref = normalizeCssHref(themeEntry.css || null);
  state.manualCssHref = null;
  updateContrastSummary();

  const desiredWidgetId = options.preselectWidget || state.currentWidget;

  if (desiredWidgetId) {
    const desiredOption = Array.from(widgetsSelect.options).find(opt => opt.value === desiredWidgetId);
    if (desiredOption) {
      widgetsSelect.value = desiredWidgetId;
      state.currentWidget = desiredWidgetId;
      const widgetEntry = themeEntry.widgets.find(w => w.id === desiredWidgetId);
      if (widgetEntry) {
        loadWidget(widgetEntry.path);
      }
      return;
    }
  }

  if (!desiredWidgetId && widgetsSelect.options.length > 1) {
    widgetsSelect.selectedIndex = 1;
    state.currentWidget = widgetsSelect.value;
    const widgetEntry = themeEntry.widgets.find(w => w.id === state.currentWidget);
    if (widgetEntry) {
      loadWidget(widgetEntry.path);
    }
  }
}

function buildWidgetUrl(widgetPath) {
  if (!widgetPath) return '';
  const params = new URLSearchParams();
  if (themeToggle.checked) {
    params.set('disableTheme', '1');
  }
  if (state.manualCssHref) {
    params.set('manualCss', state.manualCssHref.replace(/^\//, ''));
  } else if (state.currentClient && state.currentTheme) {
    params.set('theme', `${state.currentClient}/${state.currentTheme}`);
  }
  return params.toString() ? `${widgetPath}?${params.toString()}` : widgetPath;
}

function stripPreviewParam(url) {
  if (!url) return '';
  const [base, query] = url.split('?');
  if (!query) return url;
  const params = new URLSearchParams(query);
  params.delete(PREVIEW_PAYLOAD_PARAM);
  const newQuery = params.toString();
  return newQuery ? `${base}?${newQuery}` : base;
}

function normalizeBackgroundUrl(url) {
  const trimmed = url.trim();
  if (!trimmed) return '';
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://') || trimmed.startsWith('file://')) {
    return trimmed;
  }
  if (trimmed.endsWith('.html')) {
    return trimmed;
  }
  return `https://${trimmed}`;
}

function updateBackgroundFrame(inlineWidgetUrl) {
  const base = state.backgroundBaseUrl || 'https://www.pulseinsights.com';
  if (state.isInline && inlineWidgetUrl) {
    const payload = encodeURIComponent(JSON.stringify({
      widgetUrl: inlineWidgetUrl,
      inline: true
    }));
    const separator = base.includes('?') ? '&' : '?';
    backgroundFrame.src = `${base}${separator}${PREVIEW_PAYLOAD_PARAM}=${payload}`;
  } else {
    backgroundFrame.src = base;
  }
}

function renderWidget() {
  const widgetPath = state.currentWidgetPath;
  const widgetUrl = widgetPath ? buildWidgetUrl(widgetPath) : null;

  if (!widgetPath) {
    unmountWidgets({ container: overlayContainer });
    stage.classList.remove('inline-active');
    inlineNote.classList.remove('visible');
    updateBackgroundFrame(null);
    return;
  }

  stage.classList.toggle('inline-active', state.isInline);
  inlineNote.classList.toggle('visible', state.isInline);

  if (state.isInline) {
    unmountWidgets({ container: overlayContainer });
    updateBackgroundFrame(widgetUrl);
  } else {
    updateBackgroundFrame(null);
    unmountWidgets({ container: overlayContainer });
    mountWidget({ container: overlayContainer, widgetUrl, inline: false });
  }
}

function loadWidget(widgetPath) {
  if (!widgetPath) return;
  state.currentWidgetPath = widgetPath;
  state.isInline = widgetPath.includes('/inline');
  renderWidget();
}

function applyBackground(url) {
  if (!url) return;
  const normalized = normalizeBackgroundUrl(url);
  state.backgroundBaseUrl = stripPreviewParam(normalized);
  renderWidget();
}

function refreshWidget() {
  renderWidget();
}

async function updateContrastSummary() {
  contrastResults.innerHTML = '';
  const href = state.manualCssHref || state.appliedCssHref;
  if (!href) return;
  try {
    const summary = await computeContrast(normalizeCssHref(href), state.currentClient, state.currentTheme);
    summary.forEach(item => {
      const li = document.createElement('li');
      li.className = item.status;
      li.textContent = `${item.name}: ${item.value}`;
      contrastResults.appendChild(li);
    });
  } catch (err) {
    const li = document.createElement('li');
    li.className = 'warn';
    li.textContent = 'Contrast check failed (see console).';
    contrastResults.appendChild(li);
    console.error('Contrast computation failed', err);
  }
}

clientSelect.addEventListener('change', () => {
  state.currentClient = clientSelect.value;
  state.currentTheme = null;
  state.currentWidget = null;
  state.manualCssHref = null;
  state.appliedCssHref = null;
  applyManifestSelection();
  updateContrastSummary();
});

themeSelect.addEventListener('change', () => {
  state.currentTheme = themeSelect.value;
  updateWidgetsAndCssOptions();
});

widgetsSelect.addEventListener('change', () => {
  state.currentWidget = widgetsSelect.value;
  const themeEntry = findThemeEntry(state.currentClient, state.currentTheme);
  if (!themeEntry) return;
  const widgetEntry = themeEntry.widgets.find(w => w.id === state.currentWidget);
  if (!widgetEntry) return;
  loadWidget(widgetEntry.path);
});

backgroundApplyBtn.addEventListener('click', () => {
  applyBackground(backgroundInput.value);
});

manualApplyBtn.addEventListener('click', () => {
  const href = manualCssInput.value.trim();
  if (!href) return;
  const normalized = href.startsWith('/') ? href : `/${href}`;
  state.manualCssHref = normalized;
  state.appliedCssHref = normalized;
  updateContrastSummary();
  refreshWidget();
});

themeToggle.addEventListener('change', () => {
  updateContrastSummary();
  refreshWidget();
});

refreshBtn.addEventListener('click', refreshWidget);
openBtn.addEventListener('click', () => {
  if (!state.currentWidgetPath) return;
  const url = buildWidgetUrl(state.currentWidgetPath);
  window.open(url, '_blank');
});

init();
