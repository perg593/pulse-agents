const elements = {
  clientSelect: document.getElementById('client-select'),
  themeSelect: document.getElementById('theme-select'),
  widgetSelect: document.getElementById('widget-select'),
  surveySelect: document.getElementById('survey-select'),
  backgroundInput: document.getElementById('background-input'),
  backgroundApplyBtn: document.getElementById('background-apply'),
  backgroundSimpleBtn: document.getElementById('background-simple'),
  manualCssInput: document.getElementById('manual-css'),
  manualApplyBtn: document.getElementById('manual-apply'),
  manualClearBtn: document.getElementById('manual-clear'),
  applyThemeBtn: document.getElementById('apply-theme'),
  clearThemeBtn: document.getElementById('clear-theme'),
  manageThemesBtn: document.getElementById('manage-themes'),
  presentSurveyBtn: document.getElementById('present-survey'),
  resetSurveyBtn: document.getElementById('reset-survey'),
  refreshBtn: document.getElementById('refresh-widget'),
  openWidgetBtn: document.getElementById('open-widget'),
  openPlayerBtn: document.getElementById('open-player'),
  triggerContainer: document.getElementById('trigger-buttons'),
  statusList: document.getElementById('status-list'),
  backgroundFrame: document.getElementById('background-frame'),
  overlayContainer: document.getElementById('overlay-container'),
  inlineNote: document.getElementById('inline-note'),
  modeIndicator: document.getElementById('mode-indicator'),
  surveyIndicator: document.getElementById('survey-indicator'),
  accountIndicator: document.getElementById('account-indicator'),
  stage: document.getElementById('stage'),
  themeManager: document.getElementById('theme-manager'),
  themeManagerCloseBtn: document.getElementById('theme-manager-close'),
  themeManagerCloseFooterBtn: document.getElementById('theme-manager-close-footer'),
  themeManagerChooseBtn: document.getElementById('theme-manager-choose'),
  themeManagerReconnectBtn: document.getElementById('theme-manager-reconnect'),
  themeManagerSupport: document.getElementById('theme-manager-support'),
  themeManagerConnect: document.getElementById('theme-manager-connect'),
  themeManagerLoading: document.getElementById('theme-manager-loading'),
  themeManagerContent: document.getElementById('theme-manager-content'),
  themeManagerClients: document.getElementById('theme-manager-clients'),
  themeManagerStatus: document.getElementById('theme-manager-status'),
  themeManagerCount: document.getElementById('theme-manager-count'),
  themeManagerPath: document.getElementById('theme-manager-path')
};

export function option(value, label, { selected = false, disabled = false } = {}) {
  const opt = document.createElement('option');
  opt.value = value;
  opt.textContent = label;
  opt.disabled = disabled;
  opt.selected = selected;
  return opt;
}

export function setOptions(selectEl, items, { placeholder = '-- choose --', valueKey = 'value', labelKey = 'label' } = {}) {
  selectEl.innerHTML = '';
  if (placeholder) {
    selectEl.appendChild(option('', placeholder, { disabled: true, selected: true }));
  }
  items.forEach((item) => {
    selectEl.appendChild(option(item[valueKey], item[labelKey]));
  });
}

export default elements;
